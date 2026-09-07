import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../../todos/presentation/widgets/quick_add_fab.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_check.dart';

class HabitsPage extends ConsumerWidget {
  final bool embedded;

  /// Opens the app drawer. Set by the shell so every tab can reach it.
  final VoidCallback? onMenu;

  const HabitsPage({super.key, this.embedded = false, this.onMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitState = ref.watch(habitProvider);
    final filter = ref.watch(habitFilterProvider);
    final habits = switch (filter) {
      HabitFilter.all => habitState.habits,
      HabitFilter.daily =>
        habitState.habits.where((h) => h.frequency == 'daily').toList(),
      HabitFilter.weekly =>
        habitState.habits.where((h) => h.frequency == 'weekly').toList(),
    };

    return AppScaffold(
      title: switch (filter) {
        HabitFilter.all => 'Habits',
        HabitFilter.daily => 'Daily habits',
        HabitFilter.weekly => 'Weekly habits',
      },
      onMenu: embedded ? onMenu : null,
      onBack: embedded ? null : () => Navigator.pop(context),
      body: habitState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : habits.isEmpty
          ? _buildEmptyState(context, ref)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: AppShapes.contentBottom(context),
                    top: 8,
                  ),
                  itemCount: habits.length,
                  itemBuilder: (context, index) {
                    return _HabitCard(
                      habit: habits[index],
                      isFirst: index == 0,
                      isLast: index == habits.length - 1,
                    );
                  },
                ),
              ),
            ),
      floatingActionButton: QuickAddFab(
        onPressed: () => _showHabitSheet(context, ref),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.target, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No habits',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first habit',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showHabitSheet(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add habit'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _showHabitSheet(BuildContext context, WidgetRef ref, {Habit? habit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HabitEditSheet(
        habit: habit,
        onSave: (name, description, color, frequency) {
          if (habit != null) {
            ref
                .read(habitProvider.notifier)
                .updateHabit(
                  habit.copyWith(
                    name: name,
                    description: description,
                    color: color,
                    frequency: frequency,
                    clearDescription:
                        description == null || description.isEmpty,
                  ),
                );
          } else {
            ref
                .read(habitProvider.notifier)
                .addHabit(
                  name: name,
                  color: color,
                  frequency: frequency,
                  description: description,
                );
          }
        },
        onDelete: habit != null
            ? () {
                ref.read(habitProvider.notifier).deleteHabit(habit.id);
              }
            : null,
      ),
    );
  }
}

// ==================== HABIT CARD ====================

class _HabitCard extends ConsumerStatefulWidget {
  final Habit habit;
  final bool isFirst;
  final bool isLast;

  const _HabitCard({
    required this.habit,
    this.isFirst = true,
    this.isLast = true,
  });

  @override
  ConsumerState<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<_HabitCard> {
  /// 0 = current week, -1 = last week, ... Swiping left/right moves the week
  /// so days that were missed earlier can still be ticked off.
  int _weekOffset = 0;

  /// Direction of the last week change, used for the slide animation.
  int _slideDir = -1;

  static const _weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  void _openEdit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HabitEditSheet(
        habit: widget.habit,
        onSave: (name, description, color, frequency) {
          ref
              .read(habitProvider.notifier)
              .updateHabit(
                widget.habit.copyWith(
                  name: name,
                  description: description,
                  color: color,
                  frequency: frequency,
                  clearDescription: description == null || description.isEmpty,
                ),
              );
        },
        onDelete: () =>
            ref.read(habitProvider.notifier).deleteHabit(widget.habit.id),
      ),
    );
  }

  void _shiftWeek(int delta) {
    final next = _weekOffset + delta;
    if (next > 0) return; // no future weeks
    setState(() {
      _slideDir = delta;
      _weekOffset = next;
    });
  }

  void _backToThisWeek() {
    if (_weekOffset == 0) return;
    setState(() {
      _slideDir = 1;
      _weekOffset = 0;
    });
  }

  String _weekLabel(DateTime monday, DateTime sunday) {
    if (_weekOffset == 0) return 'This week';
    if (_weekOffset == -1) return 'Last week';
    return '${monday.day}.${monday.month}. – ${sunday.day}.${sunday.month}.';
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final habitColor = Color(habit.color);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final streak = habit.calculateStreak();

    // Monday of the week currently in view.
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final monday = currentMonday.add(Duration(days: 7 * _weekOffset));
    final sunday = monday.add(const Duration(days: 6));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        0,
        AppShapes.listInset,
        AppShapes.groupGap,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppShapes.row(
          isFirst: widget.isFirst,
          isLast: widget.isLast,
        ),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          // Swipe left/right = one week forward/back.
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 120) {
              _shiftWeek(-1);
            } else if (v < -120) {
              _shiftWeek(1);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — tapping the name opens edit (delete lives there).
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openEdit,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: habitColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (habit.description != null &&
                                habit.description!.isNotEmpty)
                              Text(
                                habit.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Week label — tap it to jump back to the current week.
                      GestureDetector(
                        onTap: _backToThisWeek,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            _weekLabel(monday, sunday),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _weekOffset == 0
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color: _weekOffset == 0
                                  ? AppColors.textTertiary
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      if (streak > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              MdiIcons.fire,
                              size: 15,
                              color: AppColors.orange,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$streak',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Week row — seven finger-friendly day toggles. Swiping the
                // card slides the whole week in from the side.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(_weekOffset);
                    final dx = _slideDir.toDouble();
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(incoming ? -dx : dx, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.center,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: Row(
                    key: ValueKey(_weekOffset),
                    children: List.generate(7, (i) {
                      final date = monday.add(Duration(days: i));
                      final isFuture = date.isAfter(today);
                      return Expanded(
                        child: _DayToggle(
                          label: _weekdayLabels[i],
                          dayNum: date.day,
                          color: habitColor,
                          completed: habit.isCompletedOn(date),
                          isToday: date.isAtSameMomentAs(today),
                          isFuture: isFuture,
                          onTap: isFuture
                              ? null
                              : () => ref
                                    .read(habitProvider.notifier)
                                    .toggleCompletion(habit.id, date),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),

                // History stays visible next to the week — compact heatmap.
                _HabitHeatmap(
                  habit: habit,
                  onDayTap: (date) => ref
                      .read(habitProvider.notifier)
                      .toggleCompletion(habit.id, date),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One big, tappable day cell in the week row (~44px target).
class _DayToggle extends StatelessWidget {
  final String label;
  final int dayNum;
  final Color color;
  final bool completed;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  const _DayToggle({
    required this.label,
    required this.dayNum,
    required this.color,
    required this.completed,
    required this.isToday,
    required this.isFuture,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isToday ? color : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            // The same tick a task row uses, at the same size — a habit day
            // is ticked off, not pressed like a big button.
            SizedBox(
              height: 34,
              child: Center(
                child: AppCheck(
                  checked: completed,
                  color: isToday || completed ? color : AppColors.surfaceLight,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? color
                    : (isFuture
                          ? AppColors.textTertiary
                          : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HEATMAP ====================

class _HabitHeatmap extends StatelessWidget {
  final Habit habit;

  final ValueChanged<DateTime>? onDayTap;

  /// Preferred cell size; the real one is derived from the width so the grid
  /// always fills the card exactly — no half column on either side.
  static const _preferredCell = 15.0;

  const _HabitHeatmap({required this.habit, this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final habitColor = Color(habit.color);
    final completionSet = habit.completions.toSet();

    // The grid ends with the current week, so the last column is this week and
    // every row is one weekday (Monday on top).
    final endOfWeek = todayDate.add(Duration(days: 7 - todayDate.weekday));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final weeks = (width / _preferredCell).floor().clamp(4, 40);
        final cellSize = width / weeks;
        final dotSize = (cellSize * 0.74).clamp(4.0, 14.0);
        final gridStart = endOfWeek.subtract(Duration(days: weeks * 7 - 1));

        return SizedBox(
          height: 7 * cellSize,
          child: Row(
            children: List.generate(weeks, (weekIdx) {
              return SizedBox(
                width: cellSize,
                child: Column(
                  children: List.generate(7, (dayIdx) {
                    final date = gridStart.add(
                      Duration(days: weekIdx * 7 + dayIdx),
                    );
                    final dateStr =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                    final isAfterToday = date.isAfter(todayDate);
                    final isCompleted = completionSet.contains(dateStr);
                    final isToday = date.isAtSameMomentAs(todayDate);

                    final Color dotColor;
                    if (isCompleted) {
                      dotColor = habitColor;
                    } else if (isAfterToday) {
                      dotColor = AppColors.surfaceLight.withValues(alpha: 0.4);
                    } else {
                      dotColor = AppColors.surfaceLight;
                    }

                    return SizedBox(
                      height: cellSize,
                      child: GestureDetector(
                        onTap: (!isAfterToday && onDayTap != null)
                            ? () => onDayTap!(date)
                            : null,
                        child: Center(
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: dotColor,
                              borderRadius: BorderRadius.circular(
                                dotSize * 0.3,
                              ),
                              border: isToday && !isCompleted
                                  ? Border.all(color: habitColor, width: 1)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ==================== EDIT SHEET (Create + Edit) ====================

class _HabitEditSheet extends StatefulWidget {
  final Habit? habit;
  final void Function(
    String name,
    String? description,
    int color,
    String frequency,
  )
  onSave;
  final VoidCallback? onDelete;

  const _HabitEditSheet({this.habit, required this.onSave, this.onDelete});

  @override
  State<_HabitEditSheet> createState() => _HabitEditSheetState();
}

class _HabitEditSheetState extends State<_HabitEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late int _selectedColor;
  late String _frequency;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.habit?.description ?? '',
    );
    _selectedColor =
        widget.habit?.color ?? AppColors.projectColors.first.toARGB32();
    _frequency = widget.habit?.frequency ?? 'daily';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// One filled field block of the sheet's input group.
  Widget _fieldBlock({
    required Widget child,
    required bool isFirst,
    required bool isLast,
    String? label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
      child: AppField(
        label: label,
        isFirst: isFirst,
        isLast: isLast,
        child: child,
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Same chrome as the event sheet: handle, title, filled field blocks with
    // no outlines, and the action pinned at the bottom.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShapes.sheetTop),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppShapes.listInset,
        right: AppShapes.listInset,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                _isEditing ? 'Edit habit' : 'New habit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            // Name
            _fieldBlock(
              isFirst: true,
              isLast: false,
              child: TextField(
                controller: _nameController,
                autofocus: !_isEditing,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                decoration: AppField.decoration('Name'),
              ),
            ),

            // Description
            _fieldBlock(
              isFirst: false,
              isLast: true,
              child: TextField(
                controller: _descriptionController,
                decoration: AppField.decoration('Description (optional)'),
                maxLines: 2,
                minLines: 1,
              ),
            ),
            const SizedBox(height: 16),

            // Color
            _label('Color'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppColors.projectColors.map((c) {
                final isSelected = c.toARGB32() == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c.toARGB32()),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Frequency
            _label('Frequency'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ],
              selected: {_frequency},
              onSelectionChanged: (v) => setState(() => _frequency = v.first),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  final desc = _descriptionController.text.trim();
                  widget.onSave(
                    name,
                    desc.isEmpty ? null : desc,
                    _selectedColor,
                    _frequency,
                  );
                  Navigator.pop(context);
                },
                child: Text(
                  _isEditing ? 'Save changes' : 'Create habit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Delete button (edit mode)
            if (_isEditing && widget.onDelete != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete habit?'),
                        content: const Text(
                          'All data for this habit will be deleted.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              widget.onDelete!();
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(MdiIcons.trashCanOutline, size: 18),
                  label: const Text('Delete habit'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
