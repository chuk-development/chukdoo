import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_items_provider.dart';
import 'calendar_style.dart';

/// The running list of what is coming: a date column on the left, the events
/// of that day as one filled group on the right.
///
/// Same building blocks as the month and week views — filled blocks on the
/// darker ground, no rules, strong corners only at the ends of a group.
class AgendaView extends ConsumerWidget {
  final ValueChanged<CalendarItem>? onItemTap;

  /// Opens the subscribed-calendars sheet from the empty state.
  final VoidCallback? onSubscribe;

  const AgendaView({super.key, this.onItemTap, this.onSubscribe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarItems = ref.watch(calendarItemsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final grouped = <DateTime, List<CalendarItem>>{};
    for (final item in calendarItems.items) {
      final day = DateTime(
        item.startTime.year,
        item.startTime.month,
        item.startTime.day,
      );
      grouped.putIfAbsent(day, () => []).add(item);
    }
    final sortedDays = grouped.keys.toList()..sort();

    if (sortedDays.isEmpty) return _EmptyAgenda(onSubscribe: onSubscribe);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        8,
        AppShapes.listInset,
        8,
      ),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final items = grouped[day]!
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        final isToday = day.isAtSameMomentAs(today);
        // A new month gets its own quiet label instead of a rule.
        final startsMonth =
            index == 0 || sortedDays[index - 1].month != day.month;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (startsMonth)
              Padding(
                padding: EdgeInsets.fromLTRB(4, index == 0 ? 0 : 10, 4, 10),
                child: Text(
                  DateFormat('MMMM yyyy', 'en_US').format(day).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateColumn(day: day, isToday: isToday),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          _AgendaRow(
                            item: items[i],
                            isFirst: i == 0,
                            isLast: i == items.length - 1,
                            onTap: () => onItemTap?.call(items[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Weekday over the day number, today filled — the same mark the month and
/// week views use.
class _DateColumn extends StatelessWidget {
  final DateTime day;
  final bool isToday;

  const _DateColumn({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(
            CalendarStyle.weekdayLabel(day).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? CalendarStyle.accent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isToday ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final CalendarItem item;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _AgendaRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm', 'en_US');
    final color = CalendarStyle.colorOf(item.color);
    final isTodo = item is TodoItem;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
      child: Material(
        color: AppColors.surface,
        // One day = one group: strong outer corners, soft corners between
        // two events of the same day.
        borderRadius: AppShapes.row(isFirst: isFirst, isLast: isLast),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppShapes.groupInner),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.isAllDay
                            ? (isTodo ? 'Task · All day' : 'All day')
                            : '${timeFormat.format(item.startTime)} to '
                                  '${timeFormat.format(item.endTime)}'
                                  '${isTodo ? ' · Task' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  final VoidCallback? onSubscribe;

  const _EmptyAgenda({required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.calendarBlankOutline,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              'Nothing scheduled',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Events and dated tasks of the next three months show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            if (onSubscribe != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onSubscribe,
                icon: Icon(MdiIcons.calendarSync, size: 20),
                label: const Text('Subscribe to a calendar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
