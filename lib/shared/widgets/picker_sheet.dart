import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';

/// One row in a [showPickerSheet].
class PickerOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;

  /// Drawn instead of [icon] — used for project color dots.
  final Widget? leading;
  final bool selected;

  const PickerOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.leading,
    this.selected = false,
  });
}

/// The single modal surface the whole app uses to pick something: a
/// top-rounded sheet with a handle, a title and one rounded group of rows.
///
/// Every picker — priority, project, reminder, view options — goes through
/// here, so they all open the same way and look the same.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<PickerOption<T>> options,
  String? footnote,
  List<Widget> extraRows = const [],
}) {
  return showAppPicker<T>(
    context: context,
    builder: (ctx) => PickerSheetScaffold(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PickerGroup(
            rows: [
              for (final option in options)
                _PickerRow(
                  option: option,
                  onTap: () => Navigator.pop(ctx, option.value),
                ),
              ...extraRows,
            ],
          ),
          if (footnote != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                footnote,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// The one modal surface of the app: a rounded card that flies in over the
/// content — scale plus fade, never sliding up from the bottom edge.
///
/// Every picker in the app goes through here, so they all appear the same way
/// no matter which screen opened them.
Future<T?> showAppPicker<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'picker',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) {
      final media = MediaQuery.of(ctx);
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            media.padding.top + 24,
            16,
            media.viewInsets.bottom + 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: media.size.height * 0.82,
            ),
            child: Material(
              color: AppColors.background,
              elevation: 0,
              borderRadius: BorderRadius.circular(AppShapes.sheetTop),
              clipBehavior: Clip.antiAlias,
              child: builder(ctx),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The shared chrome of every picker sheet: rounded top, drag handle, title.
class PickerSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const PickerSheetScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The gesture bar eats into the bottom, so the same number of pixels top
    // and bottom is not the same amount of air. The inset is added to both
    // ends instead, which is what reads as even.
    final view = View.of(context);
    final inset = view.viewPadding.bottom / view.devicePixelRatio;
    final pad = 16 + inset;

    return Container(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: pad),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
          SizedBox(height: pad),
        ],
      ),
    );
  }
}

/// Rows drawn as one rounded group, like every list in the app.
class _PickerGroup extends StatelessWidget {
  final List<Widget> rows;

  const _PickerGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
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
    );
  }
}

class _PickerRow<T> extends StatelessWidget {
  final PickerOption<T> option;
  final VoidCallback onTap;

  const _PickerRow({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            if (option.leading != null)
              option.leading!
            else if (option.icon != null)
              Icon(
                option.icon,
                size: 22,
                color: option.color ?? AppColors.textSecondary,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ),
            if (option.selected)
              Icon(MdiIcons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Date (and optional time) picked in the same sheet everything else uses.
///
/// Returns the picked value, or `const DateTimeChoice.cleared()` when the
/// user cleared it. `null` means the sheet was dismissed unchanged.
class DateTimeChoice {
  final DateTime? date;
  final TimeOfDay? time;

  const DateTimeChoice(this.date, this.time);

  const DateTimeChoice.cleared() : date = null, time = null;
}

Future<DateTimeChoice?> showDateTimeSheet({
  required BuildContext context,
  required String title,
  DateTime? date,
  TimeOfDay? time,
  bool allowTime = true,
}) {
  return showAppPicker<DateTimeChoice>(
    context: context,
    builder: (ctx) => _DateTimeSheet(
      title: title,
      date: date,
      time: time,
      allowTime: allowTime,
    ),
  );
}

class _DateTimeSheet extends StatefulWidget {
  final String title;
  final DateTime? date;
  final TimeOfDay? time;
  final bool allowTime;

  const _DateTimeSheet({
    required this.title,
    required this.date,
    required this.time,
    required this.allowTime,
  });

  @override
  State<_DateTimeSheet> createState() => _DateTimeSheetState();
}

class _DateTimeSheetState extends State<_DateTimeSheet> {
  late DateTime _date = widget.date ?? DateTime.now();
  late TimeOfDay? _time = widget.time;

  String _two(int v) => v.toString().padLeft(2, '0');

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return PickerSheetScaffold(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppShapes.groupOuter),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.surface,
                  ),
                ),
                child: SizedBox(
                  height: 320,
                  child: CalendarDatePicker(
                    initialDate: _date,
                    firstDate: now.subtract(const Duration(days: 365 * 2)),
                    lastDate: now.add(const Duration(days: 365 * 5)),
                    onDateChanged: (d) => setState(() => _date = d),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (widget.allowTime)
                  TextButton.icon(
                    onPressed: _pickTime,
                    icon: Icon(MdiIcons.clockOutline, size: 18),
                    label: Text(
                      _time == null
                          ? 'Add time'
                          : '${_two(_time!.hour)}:${_two(_time!.minute)}',
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const DateTimeChoice.cleared()),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, DateTimeChoice(_date, _time)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
