import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';

/// Google-Calendar-style month grid. Navigation is handled by the page header.
class MonthView extends ConsumerWidget {
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarItem>? onItemTap;

  const MonthView({super.key, this.onDayTap, this.onItemTap});

  static const _accent = AppColors.blue;
  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventState = ref.watch(calendarEventProvider);
    final calendarItems = ref.watch(calendarItemsProvider);
    final focused = eventState.focusedDate;

    final firstOfMonth = DateTime(focused.year, focused.month, 1);
    final gridStart = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // Weekday header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
          ),
          child: Row(
            children: _weekdays.map((d) {
              final isWeekend = d == 'Sa' || d == 'So';
              return Expanded(
                child: Center(
                  child: Text(
                    d.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isWeekend
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 6-week grid
        Expanded(
          child: Column(
            children: List.generate(6, (week) {
              return Expanded(
                child: Row(
                  children: List.generate(7, (dayOfWeek) {
                    final date = gridStart.add(Duration(days: week * 7 + dayOfWeek));
                    final isCurrentMonth = date.month == focused.month;
                    final isToday = date.isAtSameMomentAs(today);
                    final dayItems = calendarItems.itemsForDay(date);

                    return Expanded(
                      child: _MonthCell(
                        date: date,
                        isCurrentMonth: isCurrentMonth,
                        isToday: isToday,
                        items: dayItems,
                        onTap: () => onDayTap?.call(date),
                        onItemTap: onItemTap,
                        accent: _accent,
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final List<CalendarItem> items;
  final VoidCallback onTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final Color accent;

  const _MonthCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.items,
    required this.onTap,
    required this.onItemTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = date.weekday >= 6;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentMonth
              ? Colors.transparent
              : Colors.black.withValues(alpha: 0.12),
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
            right: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Day number
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? Colors.white
                          : !isCurrentMonth
                              ? AppColors.textTertiary
                              : isWeekend
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),

            // Event chips
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // ~16px per chip incl. spacing; reserve room for "+N".
                    final maxChips = (constraints.maxHeight / 16).floor().clamp(0, 4);
                    final overflow = items.length - maxChips;
                    final visible = items.take(maxChips).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...visible.map((item) => _chip(item)),
                        if (overflow > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 1),
                            child: Text(
                              '+$overflow',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(CalendarItem item) {
    final color = item.color != 0 ? Color(item.color) : accent;
    return GestureDetector(
      onTap: () => onItemTap?.call(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: item.isAllDay ? color : color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            if (!item.isAllDay) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: item.isAllDay
                      ? _onColor(color)
                      : (isCurrentMonth ? AppColors.textPrimary : AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _onColor(Color bg) {
    return bg.computeLuminance() > 0.6 ? const Color(0xFF1A1A22) : Colors.white;
  }
}
