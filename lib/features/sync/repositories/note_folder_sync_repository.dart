import 'package:flutter/foundation.dart';

import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../notes/domain/models/note_folder.dart';

/// Repository for syncing note folders with Supabase.
class NoteFolderSyncRepository {
  const NoteFolderSyncRepository._();

  /// Upload a folder to Supabase (name encrypted).
  static Future<void> uploadFolder(NoteFolder folder) async {
    if (!SupabaseService.isAvailable) return;

    try {
      final encryptedPayload = await EncryptionService.encryptJson(
        folder.toEncryptedPayload(),
      );
      await SupabaseService.client
          .from('note_folders')
          .upsert(folder.toSupabaseRow(encryptedPayload));

      debugPrint('NoteFolderSyncRepository: Uploaded folder ${folder.id}');
    } catch (e) {
      debugPrint('NoteFolderSyncRepository: Failed to upload folder: $e');
      rethrow;
    }
  }

  /// Download all folders of the signed-in user.
  static Future<List<NoteFolder>> downloadFolders() async {
    if (!SupabaseService.isAvailable) return [];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseService.client
          .from('note_folders')
          .select()
          .eq('user_id', userId);

      final folders = <NoteFolder>[];
      for (final row in response as List) {
        final decrypted = await EncryptionService.decryptJson(
          row['encrypted_payload'] as String,
        );
        folders.add(
          NoteFolder.fromSupabaseRow(Map<String, dynamic>.from(row), decrypted),
        );
      }

      debugPrint(
        'NoteFolderSyncRepository: Downloaded ${folders.length} folders',
      );
      return folders;
    } catch (e) {
      debugPrint('NoteFolderSyncRepository: Failed to download folders: $e');
      rethrow;
    }
  }

  /// Delete a folder from Supabase.
  static Future<void> deleteFolder(String folderId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      await SupabaseService.client
          .from('note_folders')
          .delete()
          .eq('id', folderId);
      debugPrint('NoteFolderSyncRepository: Deleted folder $folderId');
    } catch (e) {
      debugPrint('NoteFolderSyncRepository: Failed to delete folder: $e');
      rethrow;
    }
  }
}
