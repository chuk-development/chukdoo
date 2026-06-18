import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/models/rrule_helper.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../../todos/presentation/pages/todo_detail_page.dart';
import 'event_create_dialog.dart';

class EventDetailSheet extends ConsumerWidget {
  final CalendarItem item;

  const EventDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEE, d. MMM yyyy', 'de_DE');
    final timeFormat = DateFormat('HH:mm', 'de_DE');
    final calendarState = ref.watch(calendarContainerProvider);

    final isTodo = item is TodoItem;
    final isEvent = item is EventItem;
    final color = item.color != 0 ? Color(item.color) : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Date/time
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                item.isAllDay
                    ? dateFormat.format(item.startTime)
                    : '${dateFormat.format(item.startTime)} ${timeFormat.format(item.startTime)} – ${timeFormat.format(item.endTime)}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),

          // Event-specific details
          if (isEvent) _buildEventDetails(context, ref, calendarState),

          if (isTodo)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text('Aufgabe', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isTodo)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TodoDetailPage(todo: (item as TodoItem).todo),
                      ),
                    );
                  },
                  child: const Text('Details'),
                ),

              if (isEvent) ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    EventCreateDialog.show(context, editEvent: (item as EventItem).event);
                  },
                  child: const Text('Bearbeiten'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    final event = (item as EventItem).event;
                    ref.read(calendarEventProvider.notifier).deleteEvent(event.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Löschen', style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetails(BuildContext context, WidgetRef ref, CalendarContainerState calendarState) {
    final event = (item as EventItem).event;
    final widgets = <Widget>[];

    if (event.location != null && event.location!.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(Row(
        children: [
          Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(event.location!, style: TextStyle(color: AppColors.textSecondary))),
        ],
      ));
    }

    if (event.description != null && event.description!.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(event.description!, style: TextStyle(color: AppColors.textSecondary))),
        ],
      ));
    }

    if (event.isRecurring) {
      final config = RRuleHelper.parseRRule(event.recurrenceRule!);
      final label = config != null
          ? switch (config.frequency) {
              RecurrenceFrequency.daily => 'Täglich',
              RecurrenceFrequency.weekly => 'Wöchentlich',
              RecurrenceFrequency.monthly => 'Monatlich',
              RecurrenceFrequency.yearly => 'Jährlich',
            }
          : event.recurrenceRule!;

      widgets.add(const SizedBox(height: 8));
      widgets.add(Row(
        children: [
          Icon(Icons.repeat, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ));
    }

    if (event.calendarId != null) {
      final cal = calendarState.calendars.where((c) => c.id == event.calendarId).firstOrNull;
      if (cal != null) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: Color(cal.color), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(cal.name, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
