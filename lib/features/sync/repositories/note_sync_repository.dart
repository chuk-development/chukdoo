import 'package:flutter/foundation.dart';

import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../notes/domain/models/note.dart';

/// Repository for syncing notes with Supabase.
class NoteSyncRepository {
  const NoteSyncRepository._();

  /// Upload a note to Supabase (title and content encrypted).
  static Future<void> uploadNote(Note note) async {
    if (!SupabaseService.isAvailable) return;

    try {
      final encryptedPayload = await EncryptionService.encryptJson(
        note.toEncryptedPayload(),
      );
      await SupabaseService.client
          .from('notes')
          .upsert(note.toSupabaseRow(encryptedPayload));

      debugPrint('NoteSyncRepository: Uploaded note ${note.id}');
    } catch (e) {
      debugPrint('NoteSyncRepository: Failed to upload note: $e');
      rethrow;
    }
  }

  /// Download all notes of the signed-in user.
  static Future<List<Note>> downloadNotes() async {
    if (!SupabaseService.isAvailable) return [];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseService.client
          .from('notes')
          .select()
          .eq('user_id', userId);

      final notes = <Note>[];
      for (final row in response as List) {
        final decrypted = await EncryptionService.decryptJson(
          row['encrypted_payload'] as String,
        );
        notes.add(
          Note.fromSupabaseRow(Map<String, dynamic>.from(row), decrypted),
        );
      }

      debugPrint('NoteSyncRepository: Downloaded ${notes.length} notes');
      return notes;
    } catch (e) {
      debugPrint('NoteSyncRepository: Failed to download notes: $e');
      rethrow;
    }
  }

  /// Delete a note from Supabase.
  static Future<void> deleteNote(String noteId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      await SupabaseService.client.from('notes').delete().eq('id', noteId);
      debugPrint('NoteSyncRepository: Deleted note $noteId');
    } catch (e) {
      debugPrint('NoteSyncRepository: Failed to delete note: $e');
      rethrow;
    }
  }
}
