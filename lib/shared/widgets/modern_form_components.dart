import 'package:flutter/material.dart';

class ModernTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? errorText;
  final int minLines;
  final int maxLines;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final ValueChanged<String>? onChanged;
  final bool obscureText;

  const ModernTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.errorText,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.onChanged,
    this.obscureText = false,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF3B82F6)
                  : widget.errorText != null
                      ? const Color(0xFFEF4444)
                      : Colors.grey.withValues(alpha: 0.2),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused
                          ? const Color(0xFF3B82F6)
                          : Colors.grey[400],
                      size: 20,
                    )
                  : null,
              suffixIcon: widget.suffixIcon != null
                  ? GestureDetector(
                      onTap: widget.onSuffixIconPressed,
                      child: Icon(
                        widget.suffixIcon,
                        color: _isFocused
                            ? const Color(0xFF3B82F6)
                            : Colors.grey[400],
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 6),
              Text(
                widget.errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ModernButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Size size;

  const ModernButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = ButtonSize.medium,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

enum ButtonType { primary, secondary, danger, outline }

class ButtonSize {
  static const Size small = Size(80, 36);
  static const Size medium = Size(120, 44);
  static const Size large = Size(double.infinity, 44);
}

class _ModernButtonState extends State<ModernButton> {
  bool _isHovered = false;

  Color _getBackgroundColor() {
    if (widget.isLoading) {
      switch (widget.type) {
        case ButtonType.primary:
          return const Color(0xFF3B82F6).withValues(alpha: 0.7);
        case ButtonType.secondary:
          return Colors.grey[300]!.withValues(alpha: 0.7);
        case ButtonType.danger:
          return const Color(0xFFEF4444).withValues(alpha: 0.7);
        case ButtonType.outline:
          return Colors.transparent;
      }
    }

    if (widget.type == ButtonType.outline) {
      return Colors.transparent;
    }

    late Color color;
    switch (widget.type) {
      case ButtonType.primary:
        color = const Color(0xFF3B82F6);
        break;
      case ButtonType.secondary:
        color = Colors.grey[200]!;
        break;
      case ButtonType.danger:
        color = const Color(0xFFEF4444);
        break;
      case ButtonType.outline:
        color = Colors.white;
        break;
    }

    return _isHovered && !widget.isLoading
        ? color.withValues(alpha: 0.85)
        : color;
  }

  Color _getTextColor() {
    switch (widget.type) {
      case ButtonType.primary:
        return Colors.white;
      case ButtonType.secondary:
        return const Color(0xFF0F172A);
      case ButtonType.danger:
        return Colors.white;
      case ButtonType.outline:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.isFullWidth ? double.infinity : widget.size.width,
          height: widget.size.height,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(10),
            border: widget.type == ButtonType.outline
                ? Border.all(
                    color: const Color(0xFF3B82F6),
                    width: 1,
                  )
                : null,
            boxShadow: _isHovered && !widget.isLoading
                ? [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(10),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null && !widget.isLoading) ...[
                      Icon(
                        widget.icon,
                        color: _getTextColor(),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.isLoading) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getTextColor(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getTextColor(),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModernDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  const ModernDropdown({
    super.key,
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  });

  @override
  State<ModernDropdown<T>> createState() => _ModernDropdownState<T>();
}

class DropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  DropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

class _ModernDropdownState<T> extends State<ModernDropdown<T>> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF3B82F6)
                  : Colors.grey.withValues(alpha: 0.2),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: DropdownButton<T>(
            value: widget.value,
            items: widget.items
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item.value,
                    child: Row(
                      children: [
                        if (item.icon != null) ...[
                          Icon(
                            item.icon,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(item.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.onChanged,
            hint: Text(
              widget.hint,
              style: TextStyle(color: Colors.grey[400]),
            ),
            isExpanded: true,
            underline: SizedBox.shrink(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
