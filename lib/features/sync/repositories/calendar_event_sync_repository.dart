import 'package:flutter/foundation.dart';

import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../calendar/domain/models/calendar_event.dart';

/// Repository for syncing calendar events with Supabase
class CalendarEventSyncRepository {
  const CalendarEventSyncRepository._();

  /// Upload a calendar event to Supabase (encrypted)
  static Future<void> uploadEvent(CalendarEvent event) async {
    if (!SupabaseService.isAvailable) return;
    // Events from a subscribed ICS feed live only on this device — they are
    // re-fetched from their URL and must never be pushed to the account.
    if (event.userId.startsWith('feed:')) return;

    try {
      final sensitiveData = event.toEncryptedPayload();
      final encryptedPayload = await EncryptionService.encryptJson(sensitiveData);
      final row = event.toSupabaseRow(encryptedPayload);

      await SupabaseService.client.from('calendar_events').upsert(row);

      debugPrint('CalendarEventSyncRepository: Uploaded event ${event.id}');
    } catch (e) {
      debugPrint('CalendarEventSyncRepository: Failed to upload event: $e');
      rethrow;
    }
  }

  /// Download all calendar events from Supabase
  static Future<List<CalendarEvent>> downloadEvents() async {
    if (!SupabaseService.isAvailable) return [];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseService.client
          .from('calendar_events')
          .select()
          .eq('user_id', userId);

      final events = <CalendarEvent>[];
      for (final row in response as List) {
        final encryptedPayload = row['encrypted_payload'] as String;
        final decryptedPayload = await EncryptionService.decryptJson(encryptedPayload);
        events.add(CalendarEvent.fromSupabaseRow(row as Map<String, dynamic>, decryptedPayload));
      }

      debugPrint('CalendarEventSyncRepository: Downloaded ${events.length} events');
      return events;
    } catch (e) {
      debugPrint('CalendarEventSyncRepository: Failed to download events: $e');
      rethrow;
    }
  }

  /// Delete a calendar event from Supabase
  static Future<void> deleteEvent(String eventId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      await SupabaseService.client.from('calendar_events').delete().eq('id', eventId);
      debugPrint('CalendarEventSyncRepository: Deleted event $eventId');
    } catch (e) {
      debugPrint('CalendarEventSyncRepository: Failed to delete event: $e');
      rethrow;
    }
  }
}
