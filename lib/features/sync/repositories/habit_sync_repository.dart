import 'package:flutter/foundation.dart';

import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../habits/domain/models/habit.dart';

/// Repository for syncing habits with Supabase
class HabitSyncRepository {
  const HabitSyncRepository._();

  /// Upload a habit to Supabase (encrypted)
  static Future<void> uploadHabit(Habit habit) async {
    if (!SupabaseService.isAvailable) return;

    try {
      final sensitiveData = habit.toEncryptedPayload();
      final encryptedPayload = await EncryptionService.encryptJson(sensitiveData);
      final row = habit.toSupabaseRow(encryptedPayload);

      await SupabaseService.client.from('habits').upsert(row);

      debugPrint('HabitSyncRepository: Uploaded habit ${habit.id}');
    } catch (e) {
      debugPrint('HabitSyncRepository: Failed to upload habit: $e');
      rethrow;
    }
  }

  /// Download all habits from Supabase
  static Future<List<Habit>> downloadHabits() async {
    if (!SupabaseService.isAvailable) return [];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseService.client
          .from('habits')
          .select()
          .eq('user_id', userId);

      final habits = <Habit>[];
      for (final row in response as List) {
        final encryptedPayload = row['encrypted_payload'] as String;
        final decryptedPayload = await EncryptionService.decryptJson(encryptedPayload);
        habits.add(Habit.fromSupabaseRow(
          Map<String, dynamic>.from(row),
          decryptedPayload,
        ));
      }

      debugPrint('HabitSyncRepository: Downloaded ${habits.length} habits');
      return habits;
    } catch (e) {
      debugPrint('HabitSyncRepository: Failed to download habits: $e');
      rethrow;
    }
  }

  /// Delete a habit from Supabase
  static Future<void> deleteHabit(String habitId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      await SupabaseService.client.from('habits').delete().eq('id', habitId);
      debugPrint('HabitSyncRepository: Deleted habit $habitId');
    } catch (e) {
      debugPrint('HabitSyncRepository: Failed to delete habit: $e');
      rethrow;
    }
  }
}
