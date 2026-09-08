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
import '../widgets/time_mode_view.dart';
import '../widgets/month_view.dart';
import '../widgets/month_strip.dart';
import '../widgets/period_pager.dart';
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
                  ? MonthStrip(
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
        body: switch (eventState.viewMode) {
          // Agenda is a running list with no period to page through, so it
          // keeps its plain scroll view.
          CalendarViewMode.agenda => AgendaView(
            onItemTap: (item) => _showItemDetail(context, item),
            onSubscribe: () => IcsFeedsSheet.show(context),
          ),
          // A month is one block with no frame that could stay behind, so the
          // whole page is dragged in under the finger.
          CalendarViewMode.month => PeriodPager(
            mode: eventState.viewMode,
            weekStart: settings.calendarWeekStart,
            focusedDate: eventState.focusedDate,
            onFocusedDateChanged: notifier.setFocusedDate,
            pageBuilder: (context, periodStart) => MonthView(
              date: periodStart,
              onDayTap: (date) {
                notifier.setFocusedDate(date);
                notifier.setViewMode(CalendarViewMode.day);
              },
              onItemTap: (item) => _showItemDetail(context, item),
            ),
          ),
          // Day, three days and week keep their frame: the title, the view
          // switcher and the hour gutter stay where they are and only the day
          // columns and their dates page. The grid owns that pager itself.
          _ => TimeModeView(
            mode: eventState.viewMode,
            onSlotTap: (slot) =>
                _createEvent(context, date: slot.date, time: slot.time),
            onItemTap: (item) => _showItemDetail(context, item),
            onItemDrop: (item, newStart) => _handleDrop(ref, item, newStart),
          ),
        },
        floatingActionButton: QuickAddFab(
          onPressed: () => _createEvent(context),
        ),
      ),
    );
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
      case CalendarViewMode.threeDay:
        // The focused day is the left column, so the title names the span it
        // opens: "8 to 10 Sep", and both months when it crosses one.
        final last = daysFrom(f, threeDayColumns).last;
        final from = f.month == last.month
            ? DateFormat('d', 'en_US').format(f)
            : DateFormat('d MMM', 'en_US').format(f);
        return '$from to ${DateFormat('d MMM', 'en_US').format(last)}';
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
