import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/supabase_service.dart';
import '../../sync/services/sync_service.dart';
import '../../widget/widget_service.dart';
import '../../integrations/sunrise_export_service.dart';
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

  /// Pinned first, then by sortOrder, then newest first.
  void _sort(List<Todo> list) {
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  /// Apply an updated todo to Hive, sync queue and state (re-sorted).
  Future<void> _persist(Todo updated) async {
    await _todosBox.put(updated.id, updated.toJson());
    await SyncService.queueOperation(
      entityType: SyncEntityType.todo,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );
    final todos = state.todos.map((t) => t.id == updated.id ? updated : t).toList();
    _sort(todos);
    state = state.copyWith(todos: todos);
    WidgetService.updateWidget();
    SunriseExportService.update();
  }

  Future<void> _loadTodos() async {
    state = state.copyWith(isLoading: true);

    try {
      final todoMaps = _todosBox.values.toList();
      final todos = todoMaps.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Todo.fromJson(map);
      }).toList();

      _sort(todos);

      state = state.copyWith(todos: todos, isLoading: false);

      // Update home screen widget with latest data
      WidgetService.updateWidget();
      SunriseExportService.update();
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
    final todos = [todo, ...state.todos];
    _sort(todos);
    state = state.copyWith(todos: todos);

    // Update home screen widget
    WidgetService.updateWidget();
    SunriseExportService.update();
  }

  /// Pin / unpin a todo (sticks to top of every list).
  Future<void> togglePin(String todoId) async {
    final todo = state.todos.firstWhere((t) => t.id == todoId);
    await _persist(todo.copyWith(isPinned: !todo.isPinned, updatedAt: DateTime.now()));
  }

  /// Quick-set the due date (and optionally time) from a swipe action.
  Future<void> setDueDate(String todoId, DateTime? date, {TimeOfDay? time}) async {
    final todo = state.todos.firstWhere((t) => t.id == todoId);
    await _persist(todo.copyWith(
      dueDate: date,
      dueTime: time,
      updatedAt: DateTime.now(),
      clearDueDate: date == null,
      clearDueTime: time == null,
    ));
  }

  /// Move a todo into another project (null = inbox / main list).
  Future<void> moveToProject(String todoId, String? projectId) async {
    final todo = state.todos.firstWhere((t) => t.id == todoId);
    await _persist(todo.copyWith(
      projectId: projectId,
      updatedAt: DateTime.now(),
      clearProjectId: projectId == null,
    ));
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
    _sort(todos);

    state = state.copyWith(todos: todos);

    // Update home screen widget
    WidgetService.updateWidget();
    SunriseExportService.update();
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
    _sort(todos);

    state = state.copyWith(todos: todos);

    // Update home screen widget
    WidgetService.updateWidget();
    SunriseExportService.update();
  }

  /// Re-insert a previously deleted todo (used for swipe-to-delete undo).
  Future<void> restoreTodo(Todo todo) async {
    await _todosBox.put(todo.id, todo.toJson());
    await SyncService.queueOperation(
      entityType: SyncEntityType.todo,
      operation: SyncOperation.create,
      entityId: todo.id,
      data: todo.toJson(),
    );
    final todos = [todo, ...state.todos.where((t) => t.id != todo.id)];
    _sort(todos);
    state = state.copyWith(todos: todos);
    WidgetService.updateWidget();
    SunriseExportService.update();
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
    SunriseExportService.update();
  }

  Future<void> reorderTodo(String todoId, int newIndex) async {
    final todos = List<Todo>.from(state.todos);
    final oldIndex = todos.indexWhere((t) => t.id == todoId);
    if (oldIndex == -1) return;

    final todo = todos.removeAt(oldIndex);
    todos.insert(newIndex, todo);

    // Update sort orders and queue sync for each reordered todo
    for (var i = 0; i < todos.length; i++) {
      final updated = todos[i].copyWith(sortOrder: i, updatedAt: DateTime.now());
      todos[i] = updated;
      await _todosBox.put(updated.id, updated.toJson());

      await SyncService.queueOperation(
        entityType: SyncEntityType.todo,
        operation: SyncOperation.update,
        entityId: updated.id,
        data: updated.toJson(),
      );
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

/// Todo currently shown in the desktop detail panel (null = none / mobile).
final selectedTodoProvider = StateProvider<Todo?>((ref) => null);
