import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/models/event_layout.dart';
import 'calendar_style.dart';
import 'event_block.dart';

/// Shared hourly time grid used by DayView and WeekView. Google-Calendar style.
class TimeGrid extends StatefulWidget {
  final int columnCount;
  final List<String> columnHeaders;
  final List<DateTime> columnDates;
  final List<List<CalendarItem>> itemsByColumn;
  final List<List<CalendarItem>>? allDayItemsByColumn;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double timeColumnWidth;
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  const TimeGrid({
    super.key,
    required this.columnCount,
    required this.columnHeaders,
    required this.columnDates,
    required this.itemsByColumn,
    this.allDayItemsByColumn,
    this.startHour = 0,
    this.endHour = 23,
    this.hourHeight = 56.0,
    this.timeColumnWidth = 52.0,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
  });

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

/// Big radius only on the four corners of the whole grid.
Radius _corner(bool isGridCorner) => Radius.circular(
  isGridCorner ? AppShapes.groupOuter : AppShapes.groupInner,
);

class _TimeGridState extends State<TimeGrid> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    // Scroll to current time (or 7:00) once laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final anchorHour = now.hour.clamp(widget.startHour, widget.endHour);
    final target = ((anchorHour - widget.startHour) * widget.hourHeight - widget.hourHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.endHour - widget.startHour + 1;
    final totalHeight = hours * widget.hourHeight;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        if (widget.allDayItemsByColumn != null) _buildAllDaySection(),

        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            // The grid runs under the floating nav bar; this keeps the last
            // hour reachable instead of hiding it behind the pill.
            padding: EdgeInsets.only(bottom: AppShapes.contentBottom(context)),
            child: SizedBox(
              height: totalHeight,
              child: Stack(
                children: [
                  // The grid is built from rounded tiles — one per day and
                  // hour — with a small gap, the way Google Calendar draws it.
                  // Only the four corners of the whole grid are strongly
                  // rounded, everything inside stays slightly rounded.
                  ...List.generate(hours, (i) {
                    final hour = widget.startHour + i;
                    return Positioned(
                      top: i * widget.hourHeight,
                      left: 0,
                      right: 0,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: widget.timeColumnWidth,
                            child: Transform.translate(
                              offset: const Offset(0, -7),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6, right: 8),
                                child: Text(
                                  i == 0
                                      ? ''
                                      : '${hour.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          for (var col = 0; col < widget.columnCount; col++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: col == widget.columnCount - 1
                                      ? 0
                                      : AppShapes.groupGap,
                                ),
                                child: Container(
                                  height:
                                      widget.hourHeight - AppShapes.groupGap,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: _corner(
                                        i == 0 && col == 0,
                                      ),
                                      topRight: _corner(
                                        i == 0 &&
                                            col == widget.columnCount - 1,
                                      ),
                                      bottomLeft: _corner(
                                        i == hours - 1 && col == 0,
                                      ),
                                      bottomRight: _corner(
                                        i == hours - 1 &&
                                            col == widget.columnCount - 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Day columns with events
                  Positioned(
                    left: widget.timeColumnWidth,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dayWidth = constraints.maxWidth / widget.columnCount;
                        return Stack(
                          children: [
                            ...List.generate(widget.columnCount, (col) {
                              final date = widget.columnDates[col];
                              final isToday = date.year == today.year &&
                                  date.month == today.month &&
                                  date.day == today.day;

                              return Positioned(
                                left: col * dayWidth,
                                top: 0,
                                bottom: 0,
                                width: dayWidth,
                                child: _buildDayColumn(
                                  col: col,
                                  date: date,
                                  isToday: isToday,
                                  dayWidth: dayWidth,
                                  totalHeight: totalHeight,
                                ),
                              );
                            }),

                            ..._buildCurrentTimeIndicator(now, today, dayWidth),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn({
    required int col,
    required DateTime date,
    required bool isToday,
    required double dayWidth,
    required double totalHeight,
  }) {
    final items = col < widget.itemsByColumn.length ? widget.itemsByColumn[col] : <CalendarItem>[];
    final layoutInfos = EventLayoutCalculator.calculateLayout(
      items.where((i) => !i.isAllDay).toList(),
    );

    return DragTarget<CalendarItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final renderBox = context.findRenderObject() as RenderBox;
        final localPos = renderBox.globalToLocal(details.offset);
        final gridY = localPos.dy + _scrollController.offset;
        final hour = widget.startHour + (gridY / widget.hourHeight).floor();
        final minute = ((gridY % widget.hourHeight) / widget.hourHeight * 60).round();
        final snappedMinute = (minute ~/ 15) * 15;

        final newStart = DateTime(
          date.year, date.month, date.day,
          hour.clamp(widget.startHour, widget.endHour),
          snappedMinute.clamp(0, 45),
        );

        HapticFeedback.mediumImpact();
        widget.onItemDrop?.call(details.data, newStart);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTapUp: (details) {
            final tapY = details.localPosition.dy;
            final hour = widget.startHour + (tapY / widget.hourHeight).floor();
            final minute = ((tapY % widget.hourHeight) / widget.hourHeight * 60).round();
            final snappedMinute = (minute ~/ 15) * 15;
            widget.onSlotTap?.call((
              date: date,
              time: TimeOfDay(
                hour: hour.clamp(widget.startHour, widget.endHour),
                minute: snappedMinute.clamp(0, 45),
              ),
            ));
          },
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                if (candidateData.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      color: CalendarStyle.accent.withValues(alpha: 0.10),
                    ),
                  ),

                ...layoutInfos.map((info) {
                  final item = info.item;
                  final startY = (item.startTime.hour - widget.startHour) * widget.hourHeight +
                      (item.startTime.minute / 60.0) * widget.hourHeight;
                  final endY = (item.endTime.hour - widget.startHour) * widget.hourHeight +
                      (item.endTime.minute / 60.0) * widget.hourHeight;
                  final blockHeight = (endY - startY).clamp(20.0, totalHeight);

                  final blockWidth = dayWidth * info.widthFraction - 3;
                  final blockLeft = dayWidth * info.leftFraction + 1.5;

                  return Positioned(
                    left: blockLeft,
                    top: startY.clamp(0.0, totalHeight - 20),
                    width: blockWidth.clamp(10.0, dayWidth - 2),
                    child: EventBlock(
                      item: item,
                      height: blockHeight,
                      onTap: () => widget.onItemTap?.call(item),
                      onDragStarted: widget.onItemDrop != null ? (_) {} : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildCurrentTimeIndicator(DateTime now, DateTime today, double dayWidth) {
    for (var i = 0; i < widget.columnDates.length; i++) {
      final date = widget.columnDates[i];
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        final y = (now.hour - widget.startHour) * widget.hourHeight +
            (now.minute / 60.0) * widget.hourHeight;
        if (y < 0) return [];
        return [
          Positioned(
            top: y - 5,
            left: i * dayWidth - 5,
            width: dayWidth + 5,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(height: 2, color: AppColors.error),
                ),
              ],
            ),
          ),
        ];
      }
    }
    return [];
  }

  Widget _buildAllDaySection() {
    final allDayItems = widget.allDayItemsByColumn;
    if (allDayItems == null) return const SizedBox.shrink();

    final hasAny = allDayItems.any((list) => list.isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 4, 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: widget.timeColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  'All day',
                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            ...List.generate(widget.columnCount, (i) {
              final items = i < allDayItems.length ? allDayItems[i] : <CalendarItem>[];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    children: items.take(3).map((item) {
                      final color = CalendarStyle.colorOf(item.color);
                      return GestureDetector(
                        onTap: () => widget.onItemTap?.call(item),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(
                              AppShapes.dockChip,
                            ),
                          ),
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CalendarStyle.onEventColor(color),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
