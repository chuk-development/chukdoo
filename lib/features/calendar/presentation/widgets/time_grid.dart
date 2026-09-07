import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../settings/providers/settings_provider.dart';
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

  /// First hour drawn. The grid spans [startHour] to [endHour], so the end is
  /// exclusive: 7 to 22 draws fifteen rows and stops at 22:00. That matches
  /// the settings' `calendarDayHourCount`, which is `end - start`.
  final int startHour;
  final int endHour;

  /// Height of one hour row. The user's, from the settings — a pinch on the
  /// grid writes it back through [onHourHeightChanged].
  final double hourHeight;
  final double timeColumnWidth;
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  /// The hour height the fingers settled on, reported once when the pinch
  /// ends. Writing on every frame would hammer the settings box.
  final ValueChanged<double>? onHourHeightChanged;

  /// True while two fingers are on the grid. The page above freezes its pager
  /// then, so a pinch cannot drift into a period change.
  final ValueChanged<bool>? onZoomingChanged;

  /// Last hour that still has a row. [endHour] is the end of the span, so the
  /// last row starts one hour before it.
  int get _lastHour => endHour - 1;

  const TimeGrid({
    super.key,
    required this.columnCount,
    required this.columnHeaders,
    required this.columnDates,
    required this.itemsByColumn,
    this.allDayItemsByColumn,
    this.startHour = 0,
    this.endHour = 24,
    this.hourHeight = AppSettings.calendarHourHeightDefault,
    this.timeColumnWidth = 44.0,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
    this.onHourHeightChanged,
    this.onZoomingChanged,
  });

  /// Headroom above the first hour row, inside the scroll view. The pinch
  /// anchor has to subtract it to reach grid coordinates.
  static const double topPadding = 8;

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

/// Big radius only on the four corners of the whole grid.
Radius _corner(bool isGridCorner) =>
    Radius.circular(isGridCorner ? AppShapes.groupOuter : AppShapes.groupInner);

class _TimeGridState extends State<TimeGrid> {
  late ScrollController _scrollController;
  Timer? _timer;

  /// Every finger currently on the grid, by pointer id, in the coordinates of
  /// the scroll viewport.
  ///
  /// Raw pointers instead of a `ScaleGestureRecognizer`: a scale recognizer
  /// enters the gesture arena with a *single* pointer as well and would beat
  /// the pager and the vertical scroll to it. A [Listener] never enters the
  /// arena, so one finger still pans and scrolls exactly as before and only
  /// the second finger starts a zoom.
  final Map<int, Offset> _pointers = {};

  /// True between the second finger going down and the last one lifting.
  bool _pinching = false;

  /// Hour height while the fingers are on the grid, and until the persisted
  /// value comes back. Null means "whatever the settings say".
  double? _pinchHeight;

  double _pinchStartSpan = 0;
  double _pinchStartHeight = 0;

  /// Where the fingers met and where the grid stood when the pinch began —
  /// together they keep the hour under the fingers under the fingers.
  double _pinchStartFocalY = 0;
  double _pinchStartOffset = 0;

  /// The height the grid draws with right now.
  double get _hourHeight => _pinchHeight ?? widget.hourHeight;

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

  @override
  void didUpdateWidget(TimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pinched height has arrived back through the settings, so the local
    // copy can go. Dropping it at the end of the gesture instead would show
    // the old height for the frame before the setting lands.
    if (!_pinching &&
        _pinchHeight != null &&
        widget.hourHeight != oldWidget.hourHeight) {
      _pinchHeight = null;
    }
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final anchorHour = now.hour.clamp(widget.startHour, widget._lastHour);
    final target = ((anchorHour - widget.startHour) * _hourHeight - _hourHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Pinch to zoom ────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) _beginPinch();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pinching) _updatePinch();
  }

  void _onPointerEnd(PointerEvent event) {
    if (_pointers.remove(event.pointer) == null) return;
    // One finger left is a pan again, so the zoom settles where it is.
    if (_pointers.length < 2) _endPinch();
  }

  /// The two fingers the zoom is measured between. A third finger is ignored
  /// rather than allowed to jump the span.
  List<Offset> get _pinchPoints => _pointers.values.take(2).toList();

  void _beginPinch() {
    final points = _pinchPoints;
    final span = (points[0] - points[1]).distance;
    // Two fingers down in the same spot have no span to scale from.
    if (span < 1) return;

    _pinchStartSpan = span;
    _pinchStartHeight = _hourHeight;
    _pinchStartFocalY = (points[0].dy + points[1].dy) / 2;
    _pinchStartOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0;

    setState(() {
      _pinching = true;
      _pinchHeight = _pinchStartHeight;
    });
    widget.onZoomingChanged?.call(true);
  }

  void _updatePinch() {
    final points = _pinchPoints;
    if (points.length < 2 || _pinchStartSpan <= 0) return;

    final span = (points[0] - points[1]).distance;
    final next = (_pinchStartHeight * span / _pinchStartSpan).clamp(
      AppSettings.calendarHourHeightMin,
      AppSettings.calendarHourHeightMax,
    );
    if (next == _pinchHeight) return;

    setState(() => _pinchHeight = next);

    // The scroll extent only grows once the taller grid is laid out, so the
    // anchor is corrected after that frame, not during this one.
    final factor = next / _pinchStartHeight;
    final anchoredY =
        _pinchStartOffset + _pinchStartFocalY - TimeGrid.topPadding;
    final target =
        anchoredY * factor - (_pinchStartFocalY - TimeGrid.topPadding);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  void _endPinch() {
    if (!_pinching) return;
    _pinching = false;
    widget.onZoomingChanged?.call(false);

    final settled = _pinchHeight;
    if (settled != null) widget.onHourHeightChanged?.call(settled);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.endHour - widget.startHour;
    final totalHeight = hours * _hourHeight;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        if (widget.allDayItemsByColumn != null) _buildAllDaySection(),

        Expanded(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: SingleChildScrollView(
              controller: _scrollController,
              // A pinch owns the grid: without this the vertical drag that the
              // first finger already started keeps scrolling and fights the
              // zoom anchor.
              physics: _pinching ? const NeverScrollableScrollPhysics() : null,
              // The grid runs under the floating nav bar; this keeps the last
              // hour reachable instead of hiding it behind the pill.
              // Half a line of headroom for the hour labels, and enough at the
              // bottom to scroll the last hour clear of the nav bar.
              padding: EdgeInsets.only(
                top: TimeGrid.topPadding,
                bottom: AppShapes.contentBottom(context) + 8,
              ),
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
                        top: i * _hourHeight,
                        left: 0,
                        right: 0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: widget.timeColumnWidth,
                              child: Transform.translate(
                                offset: const Offset(0, -6),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    right: 8,
                                  ),
                                  child: Text(
                                    i == 0
                                        ? ''
                                        : '${hour.toString().padLeft(2, '0')}:00',
                                    // Right against the grid, the way every
                                    // calendar app sets its hour scale.
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textTertiary,
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
                                    height: _hourHeight - AppShapes.groupGap,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.only(
                                        topLeft: _corner(i == 0 && col == 0),
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
                          final dayWidth =
                              constraints.maxWidth / widget.columnCount;
                          return Stack(
                            children: [
                              ...List.generate(widget.columnCount, (col) {
                                final date = widget.columnDates[col];
                                final isToday =
                                    date.year == today.year &&
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

                              ..._buildCurrentTimeIndicator(
                                now,
                                today,
                                dayWidth,
                                totalHeight,
                              ),
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
    final items = col < widget.itemsByColumn.length
        ? widget.itemsByColumn[col]
        : <CalendarItem>[];
    final layoutInfos = EventLayoutCalculator.calculateLayout(
      items.where((i) => !i.isAllDay).toList(),
    );

    return DragTarget<CalendarItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final renderBox = context.findRenderObject() as RenderBox;
        final localPos = renderBox.globalToLocal(details.offset);
        final gridY = localPos.dy + _scrollController.offset;
        final hour = widget.startHour + (gridY / _hourHeight).floor();
        final minute = ((gridY % _hourHeight) / _hourHeight * 60).round();
        final snappedMinute = (minute ~/ 15) * 15;

        final newStart = DateTime(
          date.year,
          date.month,
          date.day,
          hour.clamp(widget.startHour, widget._lastHour),
          snappedMinute.clamp(0, 45),
        );

        HapticFeedback.mediumImpact();
        widget.onItemDrop?.call(details.data, newStart);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTapUp: (details) {
            final tapY = details.localPosition.dy;
            final hour = widget.startHour + (tapY / _hourHeight).floor();
            final minute = ((tapY % _hourHeight) / _hourHeight * 60).round();
            final snappedMinute = (minute ~/ 15) * 15;
            widget.onSlotTap?.call((
              date: date,
              time: TimeOfDay(
                hour: hour.clamp(widget.startHour, widget._lastHour),
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
                  final startY =
                      (item.startTime.hour - widget.startHour) * _hourHeight +
                      (item.startTime.minute / 60.0) * _hourHeight;
                  final endY =
                      (item.endTime.hour - widget.startHour) * _hourHeight +
                      (item.endTime.minute / 60.0) * _hourHeight;
                  // The grid can start after and end before the event (the
                  // day window is a setting). Cut the block to the window
                  // instead of letting it run past the last hour — hiding it
                  // outright would lose an event the user does have.
                  final visibleTop = startY.clamp(0.0, totalHeight - 20);
                  final visibleBottom = endY.clamp(visibleTop, totalHeight);
                  final blockHeight = (visibleBottom - visibleTop).clamp(
                    20.0,
                    totalHeight,
                  );

                  final blockWidth = dayWidth * info.widthFraction - 3;
                  final blockLeft = dayWidth * info.leftFraction + 1.5;

                  return Positioned(
                    left: blockLeft,
                    top: visibleTop,
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

  List<Widget> _buildCurrentTimeIndicator(
    DateTime now,
    DateTime today,
    double dayWidth,
    double totalHeight,
  ) {
    for (var i = 0; i < widget.columnDates.length; i++) {
      final date = widget.columnDates[i];
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        final y =
            (now.hour - widget.startHour) * _hourHeight +
            (now.minute / 60.0) * _hourHeight;
        // The day window can end before now: no line outside the grid.
        if (y < 0 || y > totalHeight) return [];
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
                Expanded(child: Container(height: 2, color: AppColors.error)),
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
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            ...List.generate(widget.columnCount, (i) {
              final items = i < allDayItems.length
                  ? allDayItems[i]
                  : <CalendarItem>[];
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
                            vertical: 6,
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
