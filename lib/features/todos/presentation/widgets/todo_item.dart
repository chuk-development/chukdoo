import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../nlp/parser/natural_language_parser.dart';
import '../../../nlp/parser/date_parser.dart';

class TodoItem extends StatefulWidget {
  final String title;
  final String? description;
  final int priority;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final String? projectName;
  final bool isPinned;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final bool isCompleted;
  final bool largeCheckbox;

  const TodoItem({
    super.key,
    required this.title,
    this.description,
    this.priority = 4,
    this.dueDate,
    this.dueTime,
    this.projectName,
    this.isPinned = false,
    this.onTap,
    this.onComplete,
    this.isCompleted = false,
    this.largeCheckbox = false,
  });

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> {
  bool _isCompleting = false;

  // Minimal completion feedback: briefly show the checked state, then let the
  // provider move/remove the row. No full-row shrink animation.
  void _handleComplete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await Future.delayed(const Duration(milliseconds: 160));
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = AppColors.getPriorityColor(widget.priority);
    final showAsCompleted = _isCompleting || widget.isCompleted;
    final size = widget.largeCheckbox ? 28.0 : 22.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: showAsCompleted ? 0.55 : 1.0,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circle checkbox
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isCompleting ? null : _handleComplete,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4, top: 2, bottom: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: showAsCompleted ? AppColors.green : Colors.transparent,
                      border: Border.all(
                        color: showAsCompleted ? AppColors.green : priorityColor,
                        width: 2,
                      ),
                    ),
                    child: showAsCompleted
                        ? Icon(Icons.check, size: widget.largeCheckbox ? 16 : 14, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.isPinned && !showAsCompleted) ...[
                          Icon(SolarIconsBold.bookmark, size: 13, color: AppColors.orange),
                          const SizedBox(width: 4),
                        ],
                        // Single-line title with ellipsis
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              color: showAsCompleted
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration: showAsCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (widget.priority < 4 && !showAsCompleted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'P${widget.priority}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Meta row: due date + time + project (single line)
                    if (_hasMeta && !showAsCompleted) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (widget.dueDate != null) ...[
                            Icon(SolarIconsOutline.calendar, size: 12, color: _getDueDateColor()),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _formatDueLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: _getDueDateColor()),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (widget.projectName != null) ...[
                            Icon(SolarIconsOutline.folder, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.projectName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasMeta => widget.dueDate != null || widget.projectName != null;

  String _two(int v) => v.toString().padLeft(2, '0');

  Color _getDueDateColor() {
    if (widget.dueDate == null) return AppColors.textSecondary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(widget.dueDate!.year, widget.dueDate!.month, widget.dueDate!.day);
    if (dueDate.isBefore(today)) return AppColors.error;
    if (dueDate == today) return AppColors.green;
    if (dueDate == today.add(const Duration(days: 1))) return AppColors.orange;
    return AppColors.textSecondary;
  }

  String _formatDueLabel() {
    if (widget.dueDate == null) return '';
    final label = DateParser.formatDate(widget.dueDate!, Language.german);
    if (widget.dueTime != null) {
      return '$label ${_two(widget.dueTime!.hour)}:${_two(widget.dueTime!.minute)}';
    }
    return label;
  }
}
