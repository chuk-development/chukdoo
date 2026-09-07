import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/models/rrule_helper.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/ics_feed_service.dart';
import '../../../todos/presentation/pages/todo_detail_page.dart';
import 'calendar_style.dart';
import 'event_create_dialog.dart';

/// What one entry of the calendar holds, shown in the same flying card every
/// other picker of the app uses.
class EventDetailSheet extends ConsumerWidget {
  final CalendarItem item;

  const EventDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEE, d MMM yyyy', 'en_US');
    final timeFormat = DateFormat('HH:mm', 'en_US');
    final calendarState = ref.watch(calendarContainerProvider);

    final color = CalendarStyle.colorOf(item.color);
    final rows = <Widget>[
      _DetailRow(
        icon: MdiIcons.clockOutline,
        text: item.isAllDay
            ? '${dateFormat.format(item.startTime)} · All day'
            : '${dateFormat.format(item.startTime)} · '
                  '${timeFormat.format(item.startTime)} to '
                  '${timeFormat.format(item.endTime)}',
      ),
      ..._eventRows(calendarState),
      if (item is TodoItem)
        _DetailRow(icon: MdiIcons.checkCircleOutline, text: 'Task'),
    ];

    return PickerSheetScaffold(
      title: item.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A colour bar carries the event's colour, like every block in the
          // grid does.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppShapes.listInset,
              0,
              AppShapes.listInset,
              10,
            ),
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppShapes.groupInner),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: AppShapes.row(
                        isFirst: i == 0,
                        isLast: i == rows.length - 1,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: rows[i],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildActions(context, ref),
        ],
      ),
    );
  }

  /// Everything a calendar event carries beyond its time.
  List<Widget> _eventRows(CalendarContainerState calendarState) {
    if (item is! EventItem) return const [];
    final event = (item as EventItem).event;
    final rows = <Widget>[];

    if (event.location != null && event.location!.isNotEmpty) {
      rows.add(
        _DetailRow(icon: MdiIcons.mapMarkerOutline, text: event.location!),
      );
    }

    if (event.description != null && event.description!.isNotEmpty) {
      rows.add(
        _DetailRow(icon: MdiIcons.textLong, text: event.description!),
      );
    }

    if (event.isRecurring) {
      final config = RRuleHelper.parseRRule(event.recurrenceRule!);
      final label = config != null
          ? switch (config.frequency) {
              RecurrenceFrequency.daily => 'Every day',
              RecurrenceFrequency.weekly => 'Every week',
              RecurrenceFrequency.monthly => 'Every month',
              RecurrenceFrequency.yearly => 'Every year',
            }
          : event.recurrenceRule!;
      rows.add(_DetailRow(icon: MdiIcons.repeat, text: label));
    }

    if (event.reminderMinutes.isNotEmpty) {
      final m = event.reminderMinutes.first;
      final label = m == 0
          ? 'At the time of the event'
          : m < 60
          ? '$m minutes before'
          : m == 1440
          ? '1 day before'
          : '${m ~/ 60} hours before';
      rows.add(_DetailRow(icon: MdiIcons.bellOutline, text: label));
    }

    if (IcsFeedService.isFeedEvent(event)) {
      final feed = IcsFeedService.feeds
          .where((f) => f.id == event.calendarId)
          .firstOrNull;
      rows.add(
        _DetailRow(
          icon: MdiIcons.calendarSync,
          text: '${feed?.name ?? 'Subscribed calendar'} · read-only',
        ),
      );
    } else {
      // The calendar an event belongs to is always shown, even when it has
      // none — otherwise "which calendar is this in" has no answer in the UI.
      final cal = calendarState.calendars
          .where((c) => c.id == event.calendarId)
          .firstOrNull;
      rows.add(
        _DetailRow(
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: cal != null
                  ? Color(cal.color)
                  : AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          text: cal?.name ?? 'No calendar',
        ),
      );
    }

    return rows;
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    if (item is TodoItem) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TodoDetailPage(todo: (item as TodoItem).todo),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: const StadiumBorder(),
              ),
              child: const Text('Open task'),
            ),
          ],
        ),
      );
    }

    final event = (item as EventItem).event;
    // An event from a subscribed feed is replaced on every refresh, so it
    // cannot be edited or deleted here.
    if (IcsFeedService.isFeedEvent(event)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'This event comes from a subscribed calendar and cannot be changed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () {
              ref.read(calendarEventProvider.notifier).deleteEvent(event.id);
              Navigator.pop(context);
            },
            icon: Icon(MdiIcons.trashCanOutline, size: 18),
            label: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              EventCreateDialog.show(context, editEvent: event);
            },
            icon: Icon(MdiIcons.pencilOutline, size: 18),
            label: const Text('Edit'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String text;

  const _DetailRow({this.icon, this.leading, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Center(
              child:
                  leading ??
                  Icon(icon, size: 20, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
