import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/utils/native_io.dart' as native_io;
import '../../../../shared/services/supabase_service.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/models/ics_service.dart';
import '../../providers/calendar_event_provider.dart';
import '../widgets/day_view.dart';
import '../widgets/week_view.dart';
import '../widgets/month_view.dart';
import '../widgets/agenda_view.dart';
import '../widgets/view_mode_selector.dart';
import '../widgets/event_create_dialog.dart';
import '../widgets/event_detail_sheet.dart';

class CalendarPage extends ConsumerWidget {
  final bool embedded;

  const CalendarPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventState = ref.watch(calendarEventProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CalendarHeader(
              embedded: embedded,
              state: eventState,
              onImport: () => _importIcs(context, ref),
              onExport: () => _exportIcs(context),
            ),
            Expanded(
              child: GestureDetector(
                // Swipe left/right to move to the next/previous period —
                // replaces reaching for the small arrows up in the header.
                // Agenda has no period to shift, so skip it there.
                onHorizontalDragEnd: eventState.viewMode == CalendarViewMode.agenda
                    ? null
                    : (details) {
                        final vx = details.primaryVelocity ?? 0;
                        if (vx.abs() < 250) return;
                        final dir = vx < 0 ? 1 : -1; // swipe left → next
                        ref
                            .read(calendarEventProvider.notifier)
                            .setFocusedDate(_shiftFocused(eventState, dir));
                      },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final fade = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    );
                    final scale = Tween<double>(begin: 0.96, end: 1.0)
                        .animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(eventState.viewMode),
                    child: _buildView(context, ref, eventState.viewMode),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createEvent(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Period shift for swipe navigation — mirrors the header arrow logic.
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

  Widget _buildView(BuildContext context, WidgetRef ref, CalendarViewMode mode) {
    switch (mode) {
      case CalendarViewMode.day:
        return DayView(
          onSlotTap: (slot) => _createEvent(context, date: slot.date, time: slot.time),
          onItemTap: (item) => _showItemDetail(context, item),
          onItemDrop: (item, newStart) => _handleDrop(ref, item, newStart),
        );
      case CalendarViewMode.week:
        return WeekView(
          onSlotTap: (slot) => _createEvent(context, date: slot.date, time: slot.time),
          onItemTap: (item) => _showItemDetail(context, item),
          onItemDrop: (item, newStart) => _handleDrop(ref, item, newStart),
        );
      case CalendarViewMode.month:
        return MonthView(
          onDayTap: (date) {
            ref.read(calendarEventProvider.notifier).setFocusedDate(date);
            ref.read(calendarEventProvider.notifier).setViewMode(CalendarViewMode.day);
          },
          onItemTap: (item) => _showItemDetail(context, item),
        );
      case CalendarViewMode.agenda:
        return AgendaView(
          onItemTap: (item) => _showItemDetail(context, item),
        );
    }
  }

  void _createEvent(BuildContext context, {DateTime? date, TimeOfDay? time}) {
    EventCreateDialog.show(context, initialDate: date, initialTime: time);
  }

  void _showItemDetail(BuildContext context, CalendarItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.sheetTop)),
      ),
      builder: (_) => EventDetailSheet(item: item),
    );
  }

  void _handleDrop(WidgetRef ref, CalendarItem item, DateTime newStart) {
    if (item is EventItem) {
      ref.read(calendarEventProvider.notifier).moveEvent(item.event.id, newStart);
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
      content = String.fromCharCodes(file.bytes!);
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
        SnackBar(content: Text('${importResult.added} events imported, ${importResult.updated} updated')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${result.error}')),
      );
    }
  }
}

/// Google-Calendar-style top bar: period title + navigation on top,
/// Today button + view switcher below.
class _CalendarHeader extends ConsumerWidget {
  final bool embedded;
  final CalendarEventState state;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const _CalendarHeader({
    required this.embedded,
    required this.state,
    required this.onImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(calendarEventProvider.notifier);
    final showNav = state.viewMode != CalendarViewMode.agenda;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              if (!embedded)
                IconButton(
                  icon: Icon(MdiIcons.chevronLeft),
                  color: AppColors.textPrimary,
                  onPressed: () => Navigator.pop(context),
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _periodTitle(),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showNav) ...[
                _NavButton(
                  icon: Icons.chevron_left,
                  onTap: () => notifier.setFocusedDate(_shift(-1)),
                ),
                _NavButton(
                  icon: Icons.chevron_right,
                  onTap: () => notifier.setFocusedDate(_shift(1)),
                ),
              ],
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                color: AppColors.surface,
                onSelected: (value) {
                  switch (value) {
                    case 'import':
                      onImport();
                    case 'export':
                      onExport();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'import', child: Text('ICS importieren')),
                  PopupMenuItem(value: 'export', child: Text('ICS exportieren')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Controls row
          Row(
            children: [
              _TodayButton(onTap: notifier.goToToday),
              const Spacer(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: ViewModeSelector(
                  currentMode: state.viewMode,
                  onChanged: notifier.setViewMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DateTime _shift(int dir) {
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

  String _periodTitle() {
    final f = state.focusedDate;
    switch (state.viewMode) {
      case CalendarViewMode.day:
        return DateFormat('EEEE, d. MMM', 'en_US').format(f);
      case CalendarViewMode.week:
        final start = DateTime(f.year, f.month, f.day)
            .subtract(Duration(days: f.weekday - 1));
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return DateFormat('MMMM yyyy', 'en_US').format(start);
        }
        return '${DateFormat('MMM', 'en_US').format(start)} – '
            '${DateFormat('MMM yyyy', 'en_US').format(end)}';
      case CalendarViewMode.month:
        return DateFormat('MMMM yyyy', 'en_US').format(f);
      case CalendarViewMode.agenda:
        return 'Agenda';
    }
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 26, color: AppColors.textPrimary),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TodayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        visualDensity: VisualDensity.compact,
      ),
      child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
