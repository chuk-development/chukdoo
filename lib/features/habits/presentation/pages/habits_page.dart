import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';

class HabitsPage extends ConsumerWidget {
  final bool embedded;

  const HabitsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitState = ref.watch(habitProvider);
    final habits = habitState.habits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        automaticallyImplyLeading: false,
        leading: embedded
            ? null
            : IconButton(
                icon: Icon(MdiIcons.chevronLeft),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: habitState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : habits.isEmpty
              ? _buildEmptyState(context, ref)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100, top: 8),
                      itemCount: habits.length,
                      itemBuilder: (context, index) {
                        return _HabitCard(habit: habits[index]);
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHabitSheet(context, ref),
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add, color: AppColors.onPrimary),
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
          Text('No habits', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Create your first habit', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
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
            ref.read(habitProvider.notifier).updateHabit(habit.copyWith(
                  name: name,
                  description: description,
                  color: color,
                  frequency: frequency,
                  clearDescription: description == null || description.isEmpty,
                ));
          } else {
            ref.read(habitProvider.notifier).addHabit(
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
  const _HabitCard({required this.habit});

  @override
  ConsumerState<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<_HabitCard> {
  // Week-based by default; the long heatmap is opt-in history.
  bool _showHistory = false;

  static const _weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  void _openEdit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HabitEditSheet(
        habit: widget.habit,
        onSave: (name, description, color, frequency) {
          ref.read(habitProvider.notifier).updateHabit(widget.habit.copyWith(
                name: name,
                description: description,
                color: color,
                frequency: frequency,
                clearDescription: description == null || description.isEmpty,
              ));
        },
        onDelete: () => ref.read(habitProvider.notifier).deleteHabit(widget.habit.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final habitColor = Color(habit.color);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCompletedToday = habit.isCompletedOn(today);
    final streak = habit.calculateStreak();
    // Monday of the current week.
    final monday = today.subtract(Duration(days: today.weekday - 1));

    return Slidable(
      key: ValueKey(habit.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => ref.read(habitProvider.notifier).deleteHabit(habit.id),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: MdiIcons.trashCan,
            label: 'Delete',
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompletedToday ? habitColor.withValues(alpha: 0.4) : AppColors.divider,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — tapping the name/area opens edit.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openEdit,
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: habitColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          if (habit.description != null && habit.description!.isNotEmpty)
                            Text(
                              habit.description!,
                              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(MdiIcons.fire, size: 14, color: AppColors.orange),
                            const SizedBox(width: 3),
                            Text('$streak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.orange)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Week row — seven big, finger-friendly day toggles.
              Row(
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
                          : () => ref.read(habitProvider.notifier).toggleCompletion(habit.id, date),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 8),

              // History toggle — heatmap is demoted behind a tap.
              InkWell(
                onTap: () => setState(() => _showHistory = !_showHistory),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showHistory ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                        size: 16, color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showHistory ? 'Hide history' : 'History',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showHistory) ...[
                const SizedBox(height: 6),
                _HabitHeatmap(
                  habit: habit,
                  days: 182,
                  onDayTap: (date) => ref.read(habitProvider.notifier).toggleCompletion(habit.id, date),
                ),
                const SizedBox(height: 6),
              ],
            ],
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
    final Color borderColor = completed
        ? color
        : (isToday ? color : AppColors.surfaceLight);

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
            Container(
              height: 44,
              constraints: const BoxConstraints(minWidth: 36),
              alignment: Alignment.center,
              child: Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? color : Colors.transparent,
                  border: Border.all(
                    color: borderColor,
                    width: isToday && !completed ? 2 : 1.5,
                  ),
                ),
                child: completed
                    ? const Icon(Icons.check, size: 20, color: Colors.white)
                    : Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isFuture ? AppColors.textTertiary : AppColors.textSecondary,
                        ),
                      ),
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
  final int days;
  final ValueChanged<DateTime>? onDayTap;

  const _HabitHeatmap({required this.habit, this.days = 182, this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final habitColor = Color(habit.color);
    final completionSet = habit.completions.toSet();

    final endDate = todayDate;
    final startDate = endDate.subtract(Duration(days: days - 1));
    final alignedStart = startDate.subtract(Duration(days: (startDate.weekday - 1) % 7));
    final totalDays = endDate.difference(alignedStart).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          // Cap the cell size so the grid stays compact on wide (desktop)
          // layouts instead of stretching dots across the whole card.
          final cellSize = (availableWidth / weeks).clamp(10.0, 18.0);
          final dotSize = (cellSize * 0.74).clamp(4.0, 13.0);

          return SizedBox(
            height: 7 * cellSize,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(weeks, (weekIdx) {
                return SizedBox(
                  width: cellSize,
                  child: Column(
                    children: List.generate(7, (dayIdx) {
                      final dayOffset = weekIdx * 7 + dayIdx;
                      final date = alignedStart.add(Duration(days: dayOffset));
                      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                      final isAfterToday = date.isAfter(todayDate);
                      final isBeforeStart = date.isBefore(startDate);
                      final isCompleted = completionSet.contains(dateStr);
                      final isToday = date.isAtSameMomentAs(todayDate);

                      Color dotColor;
                      if (isAfterToday || isBeforeStart) {
                        dotColor = Colors.transparent;
                      } else if (isCompleted) {
                        dotColor = habitColor;
                      } else {
                        dotColor = AppColors.surfaceLight;
                      }

                      return SizedBox(
                        height: cellSize,
                        child: GestureDetector(
                          onTap: (!isAfterToday && !isBeforeStart && onDayTap != null) ? () => onDayTap!(date) : null,
                          child: Center(
                            child: Container(
                              width: dotSize, height: dotSize,
                              decoration: BoxDecoration(
                                color: dotColor,
                                borderRadius: BorderRadius.circular(dotSize * 0.3),
                                border: isToday && !isCompleted ? Border.all(color: habitColor, width: 1) : null,
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
      ),
    );
  }
}

// ==================== EDIT SHEET (Create + Edit) ====================

class _HabitEditSheet extends StatefulWidget {
  final Habit? habit;
  final void Function(String name, String? description, int color, String frequency) onSave;
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
    _descriptionController = TextEditingController(text: widget.habit?.description ?? '');
    _selectedColor = widget.habit?.color ?? AppColors.projectColors.first.toARGB32();
    _frequency = widget.habit?.frequency ?? 'daily';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppShapes.sheetTop)),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _isEditing ? 'Edit habit' : 'New habit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              decoration: InputDecoration(
                hintText: 'Name',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 16),

            // Color
            Text('Color', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppColors.projectColors.map((c) {
                final isSelected = c.toARGB32() == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c.toARGB32()),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Frequency
            Text('Frequency', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ],
              selected: {_frequency},
              onSelectionChanged: (v) => setState(() => _frequency = v.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return AppColors.primary.withValues(alpha: 0.2);
                  return AppColors.surfaceLight;
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  final desc = _descriptionController.text.trim();
                  widget.onSave(name, desc.isEmpty ? null : desc, _selectedColor, _frequency);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_isEditing ? 'Save' : 'Create'),
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
                        content: const Text('All data for this habit will be deleted.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () {
                              widget.onDelete!();
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
