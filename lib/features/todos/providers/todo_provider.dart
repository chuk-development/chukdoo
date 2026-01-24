import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/supabase_service.dart';
import '../../sync/services/sync_service.dart';
import '../../widget/widget_service.dart';
import '../domain/models/todo.dart';

class TodoState {
  final List<Todo> todos;
  final bool isLoading;
  final String? error;
  final bool showCompleted;

  const TodoState({
    this.todos = const [],
    this.isLoading = false,
    this.error,
    this.showCompleted = false,
  });

  TodoState copyWith({
    List<Todo>? todos,
    bool? isLoading,
    String? error,
    bool? showCompleted,
    bool clearError = false,
  }) {
    return TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }

  // Filtered lists
  List<Todo> get inboxTodos =>
      todos.where((t) => !t.isCompleted && t.projectId == null).toList();

  List<Todo> get completedInboxTodos =>
      todos.where((t) => t.isCompleted && t.projectId == null).toList();

  List<Todo> get todayTodos {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return todos.where((t) {
      if (t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return dueDay.isAtSameMomentAs(today) || dueDay.isBefore(today);
    }).toList();
  }

  List<Todo> get completedTodayTodos {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return todos.where((t) {
      if (!t.isCompleted) return false;
      if (t.completedAt == null) return false;
      final completedDay = DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
      return completedDay.isAtSameMomentAs(today);
    }).toList();
  }

  List<Todo> todosForDate(DateTime date) {
    final targetDay = DateTime(date.year, date.month, date.day);
    return todos.where((t) {
      if (t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return dueDay.isAtSameMomentAs(targetDay);
    }).toList();
  }

  List<Todo> completedTodosForDate(DateTime date) {
    final targetDay = DateTime(date.year, date.month, date.day);
    return todos.where((t) {
      if (!t.isCompleted) return false;
      if (t.completedAt == null) return false;
      final completedDay = DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
      return completedDay.isAtSameMomentAs(targetDay);
    }).toList();
  }

  List<Todo> get allCompletedTodos =>
      todos.where((t) => t.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));
}

class TodoNotifier extends StateNotifier<TodoState> {
  TodoNotifier() : super(const TodoState()) {
    _loadTodos();
  }

  Box<Map>? _box;
  final _uuid = const Uuid();

  Box<Map> get _todosBox {
    _box ??= Hive.box<Map>(AppConstants.hiveTodosBox);
    return _box!;
  }

  Future<void> _loadTodos() async {
    state = state.copyWith(isLoading: true);

    try {
      final todoMaps = _todosBox.values.toList();
      final todos = todoMaps.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Todo.fromJson(map);
      }).toList();

      // Sort by sort_order, then by createdAt
      todos.sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

      state = state.copyWith(todos: todos, isLoading: false);

      // Update home screen widget with latest data
      WidgetService.updateWidget();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh todos from Hive (call after sync)
  Future<void> refresh() async {
    await _loadTodos();
  }

  Future<void> addTodo({
    required String title,
    String? description,
    String? projectId,
    TodoPriority priority = TodoPriority.p4,
    DateTime? dueDate,
    TimeOfDay? dueTime,
  }) async {
    final userId = SupabaseService.currentUser?.id ?? 'local';
    final now = DateTime.now();

    final todo = Todo(
      id: _uuid.v4(),
      userId: userId,
      projectId: projectId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      dueTime: dueTime,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    // Save to Hive
    await _todosBox.put(todo.id, todo.toJson());

    // Queue sync operation
    await SyncService.queueOperation(
      entityType: SyncEntityType.todo,
      operation: SyncOperation.create,
      entityId: todo.id,
      data: todo.toJson(),
    );

    // Update state
    state = state.copyWith(
      todos: [todo, ...state.todos],
    );

    // Update home screen widget
    WidgetService.updateWidget();
  }

  Future<void> updateTodo(Todo todo) async {
    final updated = todo.copyWith(updatedAt: DateTime.now());

    // Save to Hive
    await _todosBox.put(updated.id, updated.toJson());

    // Queue sync operation
    await SyncService.queueOperation(
      entityType: SyncEntityType.todo,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );

    // Update state
    final todos = state.todos.map((t) {
      return t.id == updated.id ? updated : t;
    }).toList();

    state = state.copyWith(todos: todos);

    // Update home screen widget
    WidgetService.updateWidget();
  }

  Future<void> toggleComplete(String todoId) async {
    final todo = state.todos.firstWhere((t) => t.id == todoId);
    final updated = todo.copyWith(
      isCompleted: !todo.isCompleted,
      completedAt: !todo.isCompleted ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );

    await _todosBox.put(updated.id, updated.toJson());

    // Queue sync operation
    await SyncService.queueOperation(
      entityType: SyncEntityType.todo,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );

    final todos = state.todos.map((t) {
      return t.id == updated.id ? updated : t;
    }).toList();

    state = state.copyWith(todos: todos);

    // Update home screen widget
    WidgetService.updateWidget();
  }

  Future<void> deleteTodo(String todoId) async {
    await _todosBox.delete(todoId);

    // Queue sync operation
    await SyncService.queueOperation(
      entityType: SyncEntityType.todo,
      operation: SyncOperation.delete,
      entityId: todoId,
    );

    final todos = state.todos.where((t) => t.id != todoId).toList();
    state = state.copyWith(todos: todos);

    // Update home screen widget
    WidgetService.updateWidget();
  }

  Future<void> reorderTodo(String todoId, int newIndex) async {
    final todos = List<Todo>.from(state.todos);
    final oldIndex = todos.indexWhere((t) => t.id == todoId);
    if (oldIndex == -1) return;

    final todo = todos.removeAt(oldIndex);
    todos.insert(newIndex, todo);

    // Update sort orders
    for (var i = 0; i < todos.length; i++) {
      final updated = todos[i].copyWith(sortOrder: i);
      todos[i] = updated;
      await _todosBox.put(updated.id, updated.toJson());
    }

    state = state.copyWith(todos: todos);
  }

  void toggleShowCompleted() {
    state = state.copyWith(showCompleted: !state.showCompleted);
  }
}

final todoProvider = StateNotifierProvider<TodoNotifier, TodoState>((ref) {
  return TodoNotifier();
});
