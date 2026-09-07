import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_drawer_panel.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/calendar.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/ics_feeds_provider.dart';
import '../../services/ics_feed_service.dart';
import 'calendar_edit_sheet.dart';
import 'ics_feeds_sheet.dart';

/// Side panel of the calendar: what the views show.
///
/// Two groups, because the two kinds of calendar can do different things —
/// the user's own can be renamed, recoloured and deleted, a subscribed feed
/// is read-only and can only be refreshed or dropped. Both can be switched
/// off, and switching one off removes it from every view at once.
class CalendarDrawer extends ConsumerWidget {
  const CalendarDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendars = ref.watch(calendarContainerProvider).calendars;
    final feeds = ref.watch(icsFeedsProvider);

    return AppDrawerPanel(
      title: 'Calendars',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDrawerActionTile(
            icon: MdiIcons.calendarPlus,
            label: 'New calendar',
            onTap: () => CalendarEditSheet.show(context),
          ),
          AppDrawerActionTile(
            icon: MdiIcons.calendarSync,
            label: 'Subscribed calendars',
            onTap: () {
              Navigator.pop(context);
              IcsFeedsSheet.show(context);
            },
          ),
        ],
      ),
      children: [
        const AppDrawerSection(label: 'Calendars'),
        if (calendars.isEmpty)
          const _EmptyHint(text: 'No calendar yet. Create one below.')
        else
          for (var i = 0; i < calendars.length; i++)
            _CalendarRow(
              calendar: calendars[i],
              isFirst: i == 0,
              isLast: i == calendars.length - 1,
              onToggle: () => ref
                  .read(calendarContainerProvider.notifier)
                  .toggleVisibility(calendars[i].id),
              onEdit: () =>
                  CalendarEditSheet.show(context, calendar: calendars[i]),
            ),

        if (feeds.isNotEmpty) ...[
          const AppDrawerSection(label: 'Subscribed'),
          for (var i = 0; i < feeds.length; i++)
            _FeedRow(
              feed: feeds[i],
              isFirst: i == 0,
              isLast: i == feeds.length - 1,
              onToggle: () => ref
                  .read(icsFeedsProvider.notifier)
                  .toggleVisibility(feeds[i]),
              onEdit: () => _openFeedActions(context, ref, feeds[i]),
            ),
        ],
      ],
    );
  }

  Future<void> _openFeedActions(
    BuildContext context,
    WidgetRef ref,
    IcsFeed feed,
  ) async {
    final choice = await showPickerSheet<String>(
      context: context,
      title: feed.name,
      options: [
        PickerOption(
          value: 'refresh',
          label: 'Refresh now',
          icon: MdiIcons.refresh,
        ),
        PickerOption(
          value: 'edit',
          label: 'Rename and colour',
          icon: MdiIcons.pencilOutline,
        ),
      ],
      footnote:
          'A subscribed calendar is read-only; its events come from the '
          'publisher.',
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'refresh':
        ref.read(icsFeedsProvider.notifier).refresh(feed);
      case 'edit':
        IcsFeedEditSheet.show(context, feed);
    }
  }
}

/// One of the user's own calendars: the checkbox switches it in the views, a
/// long press (or the trailing button) opens the editor.
class _CalendarRow extends StatelessWidget {
  final Calendar calendar;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _CalendarRow({
    required this.calendar,
    required this.isFirst,
    required this.isLast,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AppDrawerTile(
      icon: calendar.isVisible
          ? MdiIcons.checkboxMarked
          : MdiIcons.checkboxBlankOutline,
      iconColor: calendar.isVisible
          ? Color(calendar.color)
          : AppColors.textTertiary,
      label: calendar.name,
      isFirst: isFirst,
      isLast: isLast,
      onTap: onToggle,
      onLongPress: onEdit,
      trailing: _RowAction(
        icon: calendar.kind == CalendarKind.birthdays
            ? MdiIcons.cakeVariantOutline
            : MdiIcons.pencilOutline,
        onTap: onEdit,
      ),
    );
  }
}

/// A subscribed feed: same switch, but the trailing button opens the
/// read-only actions instead of an editor.
class _FeedRow extends StatelessWidget {
  final IcsFeed feed;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _FeedRow({
    required this.feed,
    required this.isFirst,
    required this.isLast,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AppDrawerTile(
      icon: feed.isVisible
          ? MdiIcons.checkboxMarked
          : MdiIcons.checkboxBlankOutline,
      iconColor: feed.isVisible ? Color(feed.color) : AppColors.textTertiary,
      label: feed.name,
      isFirst: isFirst,
      isLast: isLast,
      onTap: onToggle,
      onLongPress: onEdit,
      trailing: _RowAction(
        icon: feed.lastError != null ? MdiIcons.alert : MdiIcons.dotsVertical,
        color: feed.lastError != null ? AppColors.error : null,
        onTap: onEdit,
      ),
    );
  }
}

/// The trailing button of a drawer row — same footprint everywhere, so the
/// labels of two neighbouring rows still line up.
class _RowAction extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _RowAction({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 19, color: color ?? AppColors.textTertiary),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
      ),
    );
  }
}
