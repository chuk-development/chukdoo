import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import 'calendar_style.dart';

/// The month strip under the calendar title.
///
/// Same language as the Day/Week/Month/Agenda switcher: the months form one
/// connected bar, and the selected month is the one that gets the strong
/// corners on both sides while its neighbours stay nearly square. A year is
/// only a marker between two months — greyed out and not selectable, because
/// there is nothing to select there.
class MonthStrip extends StatefulWidget {
  final DateTime focused;
  final ValueChanged<DateTime> onPick;

  const MonthStrip({super.key, required this.focused, required this.onPick});

  /// Years before and after the year the strip was opened in.
  static const int yearRange = 1;

  /// Pill footprints, gap included. Fixed, because the strip must scroll to a
  /// month it has not built yet — a lazily built list cannot be measured.
  static const double monthExtent = 74;
  static const double yearExtent = 58;

  @override
  State<MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends State<MonthStrip> {
  late final int _baseYear = widget.focused.year - MonthStrip.yearRange;

  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsetFor(widget.focused),
  );

  int _indexOf(DateTime month) =>
      (month.year - _baseYear) * 12 + (month.month - 1);

  /// Where the strip stands when it opens: the current month at the left, so
  /// the first thing the eye meets is where the calendar already is.
  double _offsetFor(DateTime month) {
    final index = _indexOf(month);
    // Every January carries a year marker in front of it.
    final markers = (index / 12).floor() + (month.month == 1 ? 0 : 1);
    final start =
        index * MonthStrip.monthExtent + markers * MonthStrip.yearExtent;
    return start < 0 ? 0 : start;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusedIndex = _indexOf(widget.focused);
    final count = (MonthStrip.yearRange * 2 + 1) * 12;

    return SizedBox(
      height: 52,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppShapes.listInset,
          vertical: 6,
        ),
        itemCount: count,
        itemBuilder: (context, i) {
          final month = DateTime(_baseYear, i + 1, 1);
          final selected = i == focusedIndex;

          return Row(
            children: [
              if (month.month == 1) _YearMarker(year: month.year),
              _MonthPill(
                label: DateFormat('MMM', 'en_US').format(month),
                selected: selected,
                // A selected pill is round on both sides; the first and the
                // last of the strip keep the group's own outer corners.
                isFirst: i == 0,
                isLast: i == count - 1,
                onTap: () => widget.onPick(month),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One month of the strip.
class _MonthPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _MonthPill({
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: Radius.circular(
        selected || isFirst ? AppShapes.groupOuter : AppShapes.groupInner,
      ),
      right: Radius.circular(
        selected || isLast ? AppShapes.groupOuter : AppShapes.groupInner,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: AppShapes.groupGap),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: CalendarStyle.motion,
          curve: Curves.easeOutCubic,
          width: MonthStrip.monthExtent - AppShapes.groupGap,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: radius,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.onPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The year between two months: a quiet label, no block, nothing to tap.
class _YearMarker extends StatelessWidget {
  final int year;

  const _YearMarker({required this.year});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MonthStrip.yearExtent,
      child: Center(
        child: Text(
          '$year',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
