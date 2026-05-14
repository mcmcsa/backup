import 'package:flutter/material.dart';

import 'department_select_shared.dart';

class DepartmentInputFieldShared extends StatelessWidget {
  final TextEditingController controller;
  final List<String> options;
  final bool isLoading;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;

  const DepartmentInputFieldShared({
    super.key,
    required this.controller,
    required this.options,
    required this.isLoading,
    required this.decoration,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return TextFormField(
        controller: controller,
        enabled: false,
        decoration: decoration.copyWith(
          hintText: 'Loading departments...',
          suffixIcon: const SizedBox(
            width: 20,
            height: 20,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where((option) => option.toLowerCase().contains(query));
      },
      onSelected: (selection) {
        controller.text = selection;
        onChanged(selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        if (textEditingController.text != controller.text) {
          textEditingController.text = controller.text;
          textEditingController.selection = TextSelection.collapsed(offset: textEditingController.text.length);
        }
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: decoration.copyWith(
            hintText: options.isEmpty ? 'No departments available' : 'Select Department',
          ),
          onChanged: (value) {
            controller.text = value;
            onChanged(value);
          },
          validator: (value) => DepartmentSelectShared.validateExistingDepartment(
            options: options,
            departmentText: value,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, optionsList) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 240),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: optionsList.length,
                itemBuilder: (context, index) {
                  final option = optionsList.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}