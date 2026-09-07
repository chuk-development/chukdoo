import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';

/// The app's side panel — one implementation for every section.
///
/// Each tab brings its own navigation (lists and projects for to-dos,
/// calendars for the calendar, folders for the notes), but they must all read
/// as the same object: a floating rounded panel that comes in from the left,
/// free of every screen edge, exactly like the quick-add dock.
///
/// Use [AppDrawerPanel] as the root of a `Drawer`, then fill it with
/// [AppDrawerSection], [AppDrawerTile] and [AppDrawerActionTile]. Never build
/// a drawer row by hand — a one-off row is how the sections drifted apart in
/// the first place.
class AppDrawerPanel extends StatelessWidget {
  /// Panel title, top left.
  final String title;

  /// Optional icon buttons next to the title.
  final List<Widget> titleActions;

  /// Rows above the scrolling area — the fixed lists of a section.
  final List<Widget> header;

  /// The scrolling part: projects, calendars, folders.
  final List<Widget> children;

  /// Pinned to the bottom of the panel: "New project", "New calendar".
  final Widget? footer;

  const AppDrawerPanel({
    super.key,
    required this.title,
    this.titleActions = const [],
    this.header = const [],
    this.children = const [],
    this.footer,
  });

  /// Share of the screen width a panel takes.
  static const double widthFactor = 0.84;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      width: MediaQuery.of(context).size.width * widthFactor,
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          // Free on every side, like the quick-add dock: the gap is what makes
          // it read as a panel lying over the page.
          margin: const EdgeInsets.all(AppShapes.dockMargin),
          decoration: BoxDecoration(
            // A tone above the page background, so the panel has a visible edge.
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppShapes.sheetTop),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Column(
              // Wrap the content instead of filling the screen: the panel ends
              // right under its last row.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Tight under the title: the rows start right below it.
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      ...titleActions,
                    ],
                  ),
                ),
                ...header,
                // Flexible, not Expanded: a short list keeps the panel short,
                // a long one still scrolls inside the screen.
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    children: children,
                  ),
                ),
                ?footer,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet label over a group of drawer rows ("PROJECTS", "CALENDARS").
class AppDrawerSection extends StatelessWidget {
  final String label;

  /// Optional action at the right end of the label row (a small "+").
  final Widget? action;

  const AppDrawerSection({super.key, required this.label, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, action == null ? 20 : 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// One row of a drawer group: filled block, corner grading by position.
class AppDrawerTile extends StatelessWidget {
  final IconData icon;

  /// Replaces the icon when a row leads with a control instead — the tick of
  /// a calendar's visibility, for example.
  final Widget? leading;
  final Color? iconColor;
  final String label;

  /// Small number at the right end (open tasks, events).
  final int? count;

  /// Replaces [count] when a row needs a control instead of a number — a
  /// visibility switch for a calendar, for example.
  final Widget? trailing;

  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Position inside its rounded group.
  final bool isFirst;
  final bool isLast;

  const AppDrawerTile({
    super.key,
    required this.icon,
    this.leading,
    required this.label,
    this.iconColor,
    this.count,
    this.trailing,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.isFirst = true,
    this.isLast = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = AppShapes.row(isFirst: isFirst, isLast: isLast);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        0,
        AppShapes.listInset,
        AppShapes.groupGap,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.16)
            // Rows sit on the panel, so they need the next tone up.
            : AppColors.surfaceLight,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: radius),
        leading:
            leading ??
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.primary
                  : (iconColor ?? AppColors.textSecondary),
            ),
        title: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing:
            trailing ??
            (count != null && count! > 0
                ? Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  )
                : null),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

/// The "New …" row at the bottom of a panel: same block, accent text.
class AppDrawerActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AppDrawerActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        0,
        AppShapes.listInset,
        AppShapes.groupGap,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppShapes.groupOuter),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: AppColors.primary),
        title: Text(
          label,
          style: TextStyle(fontSize: 15, color: AppColors.primary),
        ),
        onTap: onTap,
      ),
    );
  }
}
