import 'package:flutter/foundation.dart';

import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../todos/domain/models/todo.dart';

/// Repository for syncing todos with Supabase
class TodoSyncRepository {
  const TodoSyncRepository._();

  /// Upload a todo to Supabase (encrypted)
  static Future<void> uploadTodo(Todo todo) async {
    if (!SupabaseService.isAvailable) return;

    try {
      final jsonData = todo.toJson();
      final encryptedPayload = await EncryptionService.encryptJson(jsonData);

      await SupabaseService.client.from('todos').upsert({
        'id': todo.id,
        'user_id': todo.userId,
        'encrypted_payload': encryptedPayload,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('TodoSyncRepository: Uploaded todo ${todo.id}');
    } catch (e) {
      debugPrint('TodoSyncRepository: Failed to upload todo: $e');
      rethrow;
    }
  }

  /// Download all todos from Supabase
  static Future<List<Todo>> downloadTodos() async {
    if (!SupabaseService.isAvailable) return [];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseService.client
          .from('todos')
          .select('id, encrypted_payload')
          .eq('user_id', userId);

      final todos = <Todo>[];
      for (final row in response as List) {
        final encryptedPayload = row['encrypted_payload'] as String;
        final jsonData = await EncryptionService.decryptJson(encryptedPayload);
        todos.add(Todo.fromJson(jsonData));
      }

      debugPrint('TodoSyncRepository: Downloaded ${todos.length} todos');
      return todos;
    } catch (e) {
      debugPrint('TodoSyncRepository: Failed to download todos: $e');
      rethrow;
    }
  }

  /// Delete a todo from Supabase
  static Future<void> deleteTodo(String todoId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      await SupabaseService.client.from('todos').delete().eq('id', todoId);
      debugPrint('TodoSyncRepository: Deleted todo $todoId');
    } catch (e) {
      debugPrint('TodoSyncRepository: Failed to delete todo: $e');
      rethrow;
    }
  }
}
