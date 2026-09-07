import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/todo.dart';
import 'todo_swipe_tile.dart';

/// Shared list rendering used by the main list and project pages:
/// collapsible "Angeheftet / Weitere / Erledigt" sections. Completed tasks
/// are always shown at the bottom so they can be un-checked again.
class TodoSectionedList extends StatelessWidget {
  final List<Todo> active;
  final List<Todo> completed;
  final bool large;
  final EdgeInsets padding;

  const TodoSectionedList({
    super.key,
    required this.active,
    required this.completed,
    required this.large,
    this.padding = const EdgeInsets.only(bottom: 100),
  });

  @override
  Widget build(BuildContext context) {
    final pinned = active.where((t) => t.isPinned).toList();
    final unpinned = active.where((t) => !t.isPinned).toList();

    // One list is one visual group: large radius on the outer corners, small
    // radius between two rows.
    List<Widget> group(List<Todo> items, {bool isCompleted = false}) => [
      for (var i = 0; i < items.length; i++)
        TodoSwipeTile(
          key: ValueKey(items[i].id),
          todo: items[i],
          largeCheckbox: large,
          isCompleted: isCompleted,
          isFirst: i == 0,
          isLast: i == items.length - 1,
        ),
    ];

    final sections = <Widget>[];
    if (pinned.isNotEmpty) {
      sections.add(
        _CollapsibleSection(
          title: 'Pinned',
          count: pinned.length,
          children: group(pinned),
        ),
      );
      sections.add(
        _CollapsibleSection(
          title: 'More',
          count: unpinned.length,
          children: group(unpinned),
        ),
      );
    } else {
      sections.addAll(group(unpinned));
    }
    if (completed.isNotEmpty) {
      sections.add(
        _CollapsibleSection(
          title: 'Completed',
          count: completed.length,
          children: group(completed, isCompleted: true),
        ),
      );
    }

    return SlidableAutoCloseBehavior(
      child: ListView(padding: padding, children: sections),
    );
  }
}

/// Collapsible list section with a title, count and chevron.
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 6),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    MdiIcons.chevronDown,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.count}',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}
