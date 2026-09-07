import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/utils/native_io.dart' as native_io;
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/week_dates.dart';
import '../../domain/models/ics_service.dart';
import '../../providers/calendar_event_provider.dart';
import '../widgets/calendar_style.dart';
import '../widgets/day_view.dart';
import '../widgets/week_view.dart';
import '../widgets/month_view.dart';
import '../widgets/agenda_view.dart';
import '../widgets/view_mode_selector.dart';
import '../widgets/event_create_dialog.dart';
import '../widgets/event_detail_sheet.dart';
import '../widgets/ics_feeds_sheet.dart';
import '../../../todos/presentation/widgets/quick_add_fab.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class CalendarPage extends ConsumerStatefulWidget {
  final bool embedded;

  /// Opens the app drawer. Set by the shell so every tab can reach it.
  final VoidCallback? onMenu;

  const CalendarPage({super.key, this.embedded = false, this.onMenu});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// Whether the month picker under the title is open.
  bool _monthStripOpen = false;

  @override
  void initState() {
    super.initState();
    // The calendar opens in the view the user chose in the settings. The
    // notifier only lets this through once per app run, so a later switch is
    // never overruled.
    ref
        .read(calendarEventProvider.notifier)
        .applyDefaultView(
          CalendarViewMode.values.byName(
            ref.read(settingsProvider).calendarDefaultView.name,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final eventState = ref.watch(calendarEventProvider);
    final notifier = ref.read(calendarEventProvider.notifier);
    final settings = ref.watch(settingsProvider);

    return PopScope(
      // Back from a day returns to the month or week it was opened from,
      // before the shell's own history takes over.
      canPop: !ref.read(calendarEventProvider.notifier).canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(calendarEventProvider.notifier).goBack();
      },
      // Same frame as every other section: one title row, the section's own
      // chrome under it, content passing beneath the nav bar.
      child: AppScaffold(
        onMenu: widget.embedded ? widget.onMenu : null,
        onBack: widget.embedded ? null : () => Navigator.pop(context),
        titleWidget: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _monthStripOpen = !_monthStripOpen),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _periodTitle(eventState, settings.calendarWeekStart),
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedRotation(
                turns: _monthStripOpen ? 0.5 : 0,
                duration: CalendarStyle.motion,
                curve: Curves.easeOutCubic,
                child: Icon(MdiIcons.menuDown, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          AppHeaderAction(
            icon: MdiIcons.calendarTodayOutline,
            onPressed: notifier.goToToday,
            tooltip: 'Today',
          ),
          AppHeaderAction(
            icon: MdiIcons.dotsVertical,
            onPressed: _openOverflow,
            tooltip: 'More',
          ),
        ],
        headerBottom: Column(
          children: [
            // The month picker opens under the title.
            AnimatedSize(
              duration: CalendarStyle.motion,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _monthStripOpen
                  ? _MonthPicker(
                      focused: eventState.focusedDate,
                      onPick: (month) {
                        notifier.setFocusedDate(month);
                        setState(() => _monthStripOpen = false);
                      },
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppShapes.listInset,
                2,
                AppShapes.listInset,
                8,
              ),
              child: ViewModeSelector(
                currentMode: eventState.viewMode,
                onChanged: notifier.setViewMode,
              ),
            ),
          ],
        ),
        body: GestureDetector(
          // Swipe left/right to move to the next/previous period. This is the
          // only period navigation — the header carries no arrows.
          // Agenda has no period to shift, so skip it there.
          onHorizontalDragEnd: eventState.viewMode == CalendarViewMode.agenda
              ? null
              : (details) {
                  final vx = details.primaryVelocity ?? 0;
                  if (vx.abs() < 250) return;
                  final dir = vx < 0 ? 1 : -1; // swipe left -> next
                  notifier.setFocusedDate(_shiftFocused(eventState, dir));
                },
          child: KeyedSubtree(
            // Switching between month, week and agenda swaps the view
            // outright. Cross-fading two full-screen grids showed both at
            // once and read as a glitch.
            key: ValueKey(eventState.viewMode),
            child: _buildView(context, ref, eventState.viewMode),
          ),
        ),
        floatingActionButton: QuickAddFab(
          onPressed: () => _createEvent(context),
        ),
      ),
    );
  }

  /// Period shift for swipe navigation.
  DateTime _shiftFocused(CalendarEventState state, int dir) {
    final f = state.focusedDate;
    switch (state.viewMode) {
      case CalendarViewMode.day:
        return f.add(Duration(days: dir));
      case CalendarViewMode.week:
        return f.add(Duration(days: 7 * dir));
      case CalendarViewMode.month:
        return DateTime(f.year, f.month + dir, 1);
      case CalendarViewMode.agenda:
        return f.add(Duration(days: 30 * dir));
    }
  }

  Widget _buildView(
    BuildContext context,
    WidgetRef ref,
    CalendarViewMode mode,
  ) {
    switch (mode) {
      case CalendarViewMode.day:
        return DayView(
          onSlotTap: (slot) =>
              _createEvent(context, date: slot.date, time: slot.time),
          onItemTap: (item) => _showItemDetail(context, item),
          onItemDrop: (item, newStart) => _handleDrop(ref, item, newStart),
        );
      case CalendarViewMode.week:
        return WeekView(
          onSlotTap: (slot) =>
              _createEvent(context, date: slot.date, time: slot.time),
          onItemTap: (item) => _showItemDetail(context, item),
          onItemDrop: (item, newStart) => _handleDrop(ref, item, newStart),
        );
      case CalendarViewMode.month:
        return MonthView(
          onDayTap: (date) {
            ref.read(calendarEventProvider.notifier).setFocusedDate(date);
            ref
                .read(calendarEventProvider.notifier)
                .setViewMode(CalendarViewMode.day);
          },
          onItemTap: (item) => _showItemDetail(context, item),
        );
      case CalendarViewMode.agenda:
        return AgendaView(
          onItemTap: (item) => _showItemDetail(context, item),
          onSubscribe: () => IcsFeedsSheet.show(context),
        );
    }
  }

  void _createEvent(BuildContext context, {DateTime? date, TimeOfDay? time}) {
    EventCreateDialog.show(context, initialDate: date, initialTime: time);
  }

  /// The detail card flies in like every other surface in the app.
  void _showItemDetail(BuildContext context, CalendarItem item) {
    showAppPicker<void>(
      context: context,
      builder: (_) => EventDetailSheet(item: item),
    );
  }

  void _handleDrop(WidgetRef ref, CalendarItem item, DateTime newStart) {
    if (item is EventItem) {
      ref
          .read(calendarEventProvider.notifier)
          .moveEvent(item.event.id, newStart);
    }
  }

  Future<void> _importIcs(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String? content;

    if (file.bytes != null) {
      // ICS is UTF-8 by RFC 5545 — decode as such so umlauts survive.
      content = IcsService.decodeBytes(file.bytes!);
    } else if (file.path != null) {
      content = await native_io.readFileAsString(file.path!);
    }

    if (content == null || !context.mounted) return;

    final userId = SupabaseService.currentUser?.id ?? 'local';
    final importResult = await IcsService.importIcs(content, userId);

    if (!context.mounted) return;

    if (importResult.success) {
      ref.read(calendarEventProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${importResult.added} events imported, ${importResult.updated} updated',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${importResult.error}')),
      );
    }
  }

  Future<void> _exportIcs(BuildContext context) async {
    final result = await IcsService.exportIcs();

    if (!context.mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.eventCount} events exported')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: ${result.error}')));
    }
  }

  Future<void> _openOverflow() async {
    final choice = await showPickerSheet<String>(
      context: context,
      title: 'Calendar',
      options: [
        PickerOption(
          value: 'subscribe',
          label: 'Subscribed calendars',
          icon: MdiIcons.calendarSync,
        ),
        PickerOption(
          value: 'import',
          label: 'Import a .ics file',
          icon: MdiIcons.calendarImport,
        ),
        PickerOption(
          value: 'export',
          label: 'Export as .ics',
          icon: MdiIcons.calendarExport,
        ),
      ],
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'subscribe':
        IcsFeedsSheet.show(context);
      case 'import':
        _importIcs(context, ref);
      case 'export':
        _exportIcs(context);
    }
  }

  String _periodTitle(CalendarEventState state, WeekStart weekStart) {
    final f = state.focusedDate;
    switch (state.viewMode) {
      case CalendarViewMode.day:
        return DateFormat('EEEE, d MMM', 'en_US').format(f);
      case CalendarViewMode.week:
        // Same week the grid draws, so the title cannot name another month
        // than the columns under it.
        final start = startOfWeek(f, weekStart);
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return DateFormat('MMMM yyyy', 'en_US').format(start);
        }
        return '${DateFormat('MMM', 'en_US').format(start)} to '
            '${DateFormat('MMM yyyy', 'en_US').format(end)}';
      case CalendarViewMode.month:
        return DateFormat('MMMM yyyy', 'en_US').format(f);
      case CalendarViewMode.agenda:
        return 'Agenda';
    }
  }
}

/// The month picker under the title: a strip of month pills, three years
/// wide, scrolled to the focused month.
///
/// Each pill carries the month over its year, so a month is never mistaken
/// for another year's. The strip is anchored on a fixed base year, so the
/// scroll position keeps its meaning while the user browses.
class _MonthPicker extends StatefulWidget {
  final DateTime focused;
  final ValueChanged<DateTime> onPick;

  const _MonthPicker({required this.focused, required this.onPick});

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  /// Years before and after the year the picker was opened in.
  static const _yearRange = 1;
  static const _pillWidth = 72.0;
  static const _pillGap = AppShapes.groupGap;
  static const _extent = _pillWidth + _pillGap * 2;

  /// Fixed base so a scroll offset means the same month the whole time.
  late final int _baseYear = widget.focused.year - _yearRange;

  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsetFor(widget.focused),
  );

  int _indexOf(DateTime month) =>
      (month.year - _baseYear) * 12 + (month.month - 1);

  /// Scroll offset that puts [month] roughly in the middle of the strip.
  double _offsetFor(DateTime month) {
    final centred = _indexOf(month) * _extent - _extent * 1.5;
    return centred < 0 ? 0 : centred;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusedIndex = _indexOf(widget.focused);
    final count = (_yearRange * 2 + 1) * 12;

    return SizedBox(
      height: 64,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemExtent: _extent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppShapes.listInset - _pillGap,
          vertical: 4,
        ),
        itemCount: count,
        itemBuilder: (context, i) {
          final month = DateTime(_baseYear, i + 1, 1);
          final selected = i == focusedIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pillGap),
            child: GestureDetector(
              onTap: () => widget.onPick(month),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: CalendarStyle.motion,
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppShapes.groupOuter),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMM', 'en_US').format(month),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      DateFormat('yyyy', 'en_US').format(month),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: selected
                            ? AppColors.onPrimary.withValues(alpha: 0.7)
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
