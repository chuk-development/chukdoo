import 'package:flutter/foundation.dart';

import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../calendar/domain/models/calendar.dart';

/// Repository for syncing calendars with Supabase
class CalendarSyncRepository {
  const CalendarSyncRepository._();

  /// Upload a calendar to Supabase (encrypted)
  static Future<void> uploadCalendar(Calendar calendar) async {
    if (!SupabaseService.isAvailable) return;

    try {
      final sensitiveData = calendar.toEncryptedPayload();
      final encryptedPayload = await EncryptionService.encryptJson(sensitiveData);
      final row = calendar.toSupabaseRow(encryptedPayload);

      await SupabaseService.client.from('calendars').upsert(row);

      debugPrint('CalendarSyncRepository: Uploaded calendar ${calendar.id}');
    } catch (e) {
      debugPrint('CalendarSyncRepository: Failed to upload calendar: $e');
      rethrow;
    }
  }

  /// Download all calendars from Supabase
  static Future<List<Calendar>> downloadCalendars() async {
    if (!SupabaseService.isAvailable) return [];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseService.client
          .from('calendars')
          .select()
          .eq('user_id', userId);

      final calendars = <Calendar>[];
      for (final row in response as List) {
        final encryptedPayload = row['encrypted_payload'] as String;
        final decryptedPayload = await EncryptionService.decryptJson(encryptedPayload);
        calendars.add(Calendar.fromSupabaseRow(row as Map<String, dynamic>, decryptedPayload));
      }

      debugPrint('CalendarSyncRepository: Downloaded ${calendars.length} calendars');
      return calendars;
    } catch (e) {
      debugPrint('CalendarSyncRepository: Failed to download calendars: $e');
      rethrow;
    }
  }

  /// Delete a calendar from Supabase
  static Future<void> deleteCalendar(String calendarId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      await SupabaseService.client.from('calendars').delete().eq('id', calendarId);
      debugPrint('CalendarSyncRepository: Deleted calendar $calendarId');
    } catch (e) {
      debugPrint('CalendarSyncRepository: Failed to delete calendar: $e');
      rethrow;
    }
  }
}
