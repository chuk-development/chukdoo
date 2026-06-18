import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/supabase_service.dart';
import '../../sync/services/sync_service.dart';
import '../domain/models/habit.dart';

const String _hiveHabitsBox = 'habits';

class HabitState {
  final List<Habit> habits;
  final bool isLoading;

  const HabitState({
    this.habits = const [],
    this.isLoading = false,
  });

  HabitState copyWith({
    List<Habit>? habits,
    bool? isLoading,
  }) {
    return HabitState(
      habits: habits ?? this.habits,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HabitNotifier extends StateNotifier<HabitState> {
  HabitNotifier() : super(const HabitState()) {
    _loadHabits();
  }

  Box<Map>? _box;
  final _uuid = const Uuid();

  Future<Box<Map>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Map>(_hiveHabitsBox);
    return _box!;
  }

  Future<void> _loadHabits() async {
    state = state.copyWith(isLoading: true);
    try {
      final box = await _getBox();
      final habits = box.values.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Habit.fromJson(map);
      }).toList();

      // Sort by creation date
      habits.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      state = state.copyWith(habits: habits, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addHabit({
    required String name,
    required int color,
    String frequency = 'daily',
    String? description,
  }) async {
    final userId = SupabaseService.currentUser?.id ?? 'local';
    final now = DateTime.now();

    final habit = Habit(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      color: color,
      frequency: frequency,
      description: (description == null || description.isEmpty)
          ? null
          : description,
      createdAt: now,
      updatedAt: now,
    );

    final box = await _getBox();
    await box.put(habit.id, habit.toJson());

    state = state.copyWith(habits: [...state.habits, habit]);

    await SyncService.queueOperation(
      entityType: SyncEntityType.habit,
      operation: SyncOperation.create,
      entityId: habit.id,
      data: habit.toJson(),
    );
  }

  Future<void> toggleCompletion(String habitId, DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    Habit? updatedHabit;

    final habits = state.habits.map((h) {
      if (h.id != habitId) return h;

      List<String> newCompletions;
      if (h.completions.contains(dateStr)) {
        newCompletions =
            h.completions.where((c) => c != dateStr).toList();
      } else {
        newCompletions = [...h.completions, dateStr];
      }

      final updated = h.copyWith(completions: newCompletions);
      updatedHabit = updated.copyWith(
        streak: updated.calculateStreak(),
        updatedAt: DateTime.now(),
        version: updated.version + 1,
      );
      return updatedHabit!;
    }).toList();

    state = state.copyWith(habits: habits);

    // Persist only the changed habit.
    if (updatedHabit != null) {
      final box = await _getBox();
      await box.put(updatedHabit!.id, updatedHabit!.toJson());

      await SyncService.queueOperation(
        entityType: SyncEntityType.habit,
        operation: SyncOperation.update,
        entityId: updatedHabit!.id,
        data: updatedHabit!.toJson(),
      );
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final box = await _getBox();
    await box.delete(habitId);

    state = state.copyWith(
      habits: state.habits.where((h) => h.id != habitId).toList(),
    );

    await SyncService.queueOperation(
      entityType: SyncEntityType.habit,
      operation: SyncOperation.delete,
      entityId: habitId,
    );
  }

  Future<void> updateHabit(Habit habit) async {
    final updated = habit.incrementVersion();

    final box = await _getBox();
    await box.put(updated.id, updated.toJson());

    state = state.copyWith(
      habits: state.habits.map((h) => h.id == updated.id ? updated : h).toList(),
    );

    await SyncService.queueOperation(
      entityType: SyncEntityType.habit,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );
  }
}

final habitProvider =
    StateNotifierProvider<HabitNotifier, HabitState>((ref) {
  return HabitNotifier();
});
