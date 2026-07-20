import 'package:flutter/material.dart';

/// An IndexedStack that only builds its children when they become visible for the first time.
/// This prevents all tabs from firing their API calls simultaneously on startup.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final StackFit sizing;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.sizing = StackFit.loose,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<bool> _activatedList;

  @override
  void initState() {
    super.initState();
    _activatedList = List.generate(
      widget.children.length,
      (i) => i == widget.index,
    );
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _activatedList = List.generate(
        widget.children.length,
        (i) => i == widget.index ? true : (i < _activatedList.length ? _activatedList[i] : false),
      );
    } else if (!_activatedList[widget.index]) {
      _activatedList[widget.index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      alignment: widget.alignment,
      sizing: widget.sizing,
      children: List.generate(widget.children.length, (i) {
        if (_activatedList[i]) {
          return widget.children[i];
        }
        return const SizedBox.shrink();
      }),
    );
  }
}
