import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';

class TodoItem extends StatefulWidget {
  final String title;
  final String? description;
  final int priority;
  final DateTime? dueDate;
  final String? projectName;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final bool isCompleted;
  /// Use larger checkbox for easier tapping
  final bool largeCheckbox;

  const TodoItem({
    super.key,
    required this.title,
    this.description,
    this.priority = 4,
    this.dueDate,
    this.projectName,
    this.onTap,
    this.onComplete,
    this.isCompleted = false,
    this.largeCheckbox = false,
  });

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> with SingleTickerProviderStateMixin {
  bool _isCompleting = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleComplete() async {
    setState(() {
      _isCompleting = true;
    });
    await _controller.forward();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = AppColors.getPriorityColor(widget.priority);
    final showAsCompleted = _isCompleting || widget.isCompleted;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox - with larger tap target
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isCompleting ? null : _handleComplete,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: widget.largeCheckbox ? 8 : 4,
                    top: 2,
                    bottom: 2,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: widget.largeCheckbox ? 32 : 22,
                    height: widget.largeCheckbox ? 32 : 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: showAsCompleted ? AppColors.green : priorityColor,
                        width: widget.largeCheckbox ? 2.5 : 2,
                      ),
                      color: showAsCompleted ? AppColors.green : Colors.transparent,
                    ),
                    child: showAsCompleted
                        ? Icon(
                            SolarIconsBold.checkSquare,
                            size: widget.largeCheckbox ? 20 : 14,
                            color: Colors.white,
                          )
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
                    // Title
                    Text(
                      widget.title,
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

                    // Description (if any)
                    if (widget.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Metadata row (due date, project)
                    if (widget.dueDate != null || widget.projectName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (widget.dueDate != null) ...[
                            Icon(
                              SolarIconsOutline.calendar,
                              size: 12,
                              color: _getDueDateColor(),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDueDate(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getDueDateColor(),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (widget.projectName != null) ...[
                            Icon(
                              SolarIconsOutline.folder,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.projectName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
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

  Color _getDueDateColor() {
    if (widget.dueDate == null) return AppColors.textSecondary;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      widget.dueDate!.year,
      widget.dueDate!.month,
      widget.dueDate!.day,
    );

    if (dueDate.isBefore(today)) {
      return AppColors.error; // Overdue
    } else if (dueDate == today) {
      return AppColors.green; // Today
    } else if (dueDate == today.add(const Duration(days: 1))) {
      return AppColors.orange; // Tomorrow
    }
    return AppColors.textSecondary;
  }

  String _formatDueDate() {
    if (widget.dueDate == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      widget.dueDate!.year,
      widget.dueDate!.month,
      widget.dueDate!.day,
    );

    if (dueDate == today) {
      return 'Heute';
    } else if (dueDate == today.add(const Duration(days: 1))) {
      return 'Morgen';
    } else if (dueDate.isBefore(today)) {
      final diff = today.difference(dueDate).inDays;
      return 'Vor $diff Tagen';
    } else {
      return '${dueDate.day}.${dueDate.month}';
    }
  }
}
