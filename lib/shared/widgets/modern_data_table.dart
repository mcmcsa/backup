import 'package:flutter/material.dart';

class ModernDataTable extends StatefulWidget {
  final List<ModernDataColumn> columns;
  final List<List<Widget>> rows;
  final bool sortable;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final String? emptyMessage;
  final int? sortColumnIndex;
  final bool sortAscending;

  const ModernDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortable = true,
    this.onRefresh,
    this.isLoading = false,
    this.emptyMessage = 'No data available',
    this.sortColumnIndex,
    this.sortAscending = true,
  });

  @override
  State<ModernDataTable> createState() => _ModernDataTableState();
}

class ModernDataColumn {
  final String label;
  final double? width;
  final Alignment alignment;
  final bool sortable;

  ModernDataColumn({
    required this.label,
    this.width,
    this.alignment = Alignment.centerLeft,
    this.sortable = true,
  });
}

class _ModernDataTableState extends State<ModernDataTable> {
  late int _sortColumnIndex;
  late bool _sortAscending;

  @override
  void initState() {
    super.initState();
    _sortColumnIndex = widget.sortColumnIndex ?? 0;
    _sortAscending = widget.sortAscending;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading data...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.inbox_rounded,
                  size: 36,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.emptyMessage ?? 'No data available',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: widget.columns.fold<double>(
            0,
            (sum, col) => sum + (col.width ?? 180),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: List.generate(
                    widget.columns.length,
                    (index) {
                      final column = widget.columns[index];
                      return Container(
                        width: column.width ?? 180,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: widget.sortable && column.sortable
                            ? MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_sortColumnIndex == index) {
                                        _sortAscending = !_sortAscending;
                                      } else {
                                        _sortColumnIndex = index;
                                        _sortAscending = true;
                                      }
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        column.label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF475569),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      if (_sortColumnIndex == index)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Icon(
                                            _sortAscending
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            size: 14,
                                            color: const Color(0xFF3B82F6),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : Text(
                                column.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.3,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
              // Table Rows
              ...List.generate(
                widget.rows.length,
                (rowIndex) {
                  final row = widget.rows[rowIndex];
                  final isEvenRow = rowIndex % 2 == 0;

                  return MouseRegion(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isEvenRow ? Colors.white : const Color(0xFFFAFAFC),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.05),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: List.generate(
                          widget.columns.length,
                          (cellIndex) {
                            final column = widget.columns[cellIndex];
                            return Container(
                              width: column.width ?? 180,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              alignment: column.alignment,
                              child: row[cellIndex],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TableActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final String tooltip;

  const TableActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFF3B82F6),
    required this.tooltip,
  });

  @override
  State<TableActionButton> createState() => _TableActionButtonState();
}

class _TableActionButtonState extends State<TableActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
