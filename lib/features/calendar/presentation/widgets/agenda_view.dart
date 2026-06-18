import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_items_provider.dart';

/// Google-Calendar "Schedule" style agenda: date column + stacked events.
class AgendaView extends ConsumerWidget {
  final ValueChanged<CalendarItem>? onItemTap;

  const AgendaView({super.key, this.onItemTap});

  static const _accent = AppColors.blue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarItems = ref.watch(calendarItemsProvider);
    final timeFormat = DateFormat('HH:mm', 'de_DE');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final grouped = <DateTime, List<CalendarItem>>{};
    for (final item in calendarItems.items) {
      final day = DateTime(item.startTime.year, item.startTime.month, item.startTime.day);
      grouped.putIfAbsent(day, () => []).add(item);
    }
    final sortedDays = grouped.keys.toList()..sort();

    if (sortedDays.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Keine Termine',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final items = grouped[day]!..sort((a, b) => a.startTime.compareTo(b.startTime));
        final isToday = day.isAtSameMomentAs(today);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date column
              SizedBox(
                width: 56,
                child: Column(
                  children: [
                    Text(
                      DateFormat('E', 'de_DE').format(day).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                        color: isToday ? _accent : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? _accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isToday ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Events
              Expanded(
                child: Column(
                  children: items.map((item) {
                    final color = item.color != 0 ? Color(item.color) : _accent;
                    final isTodo = item is TodoItem;
                    return GestureDetector(
                      onTap: () => onItemTap?.call(item),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.isAllDay
                                        ? (isTodo ? 'Aufgabe · Ganztägig' : 'Ganztägig')
                                        : '${timeFormat.format(item.startTime)} – ${timeFormat.format(item.endTime)}'
                                            '${isTodo ? ' · Aufgabe' : ''}',
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
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
