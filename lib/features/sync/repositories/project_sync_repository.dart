import 'package:flutter/foundation.dart';

import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../projects/domain/models/project.dart';

/// Repository for syncing projects with Supabase
class ProjectSyncRepository {
  const ProjectSyncRepository._();

  /// Upload a project to Supabase (encrypted)
  static Future<void> uploadProject(Project project) async {
    if (!SupabaseService.isAvailable) return;

    try {
      final jsonData = project.toJson();
      final encryptedPayload = await EncryptionService.encryptJson(jsonData);

      await SupabaseService.client.from('projects').upsert({
        'id': project.id,
        'user_id': project.userId,
        'encrypted_payload': encryptedPayload,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('ProjectSyncRepository: Uploaded project ${project.id}');
    } catch (e) {
      debugPrint('ProjectSyncRepository: Failed to upload project: $e');
      rethrow;
    }
  }

  /// Download all projects from Supabase
  static Future<List<Project>> downloadProjects() async {
    if (!SupabaseService.isAvailable) return [];

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseService.client
          .from('projects')
          .select('id, encrypted_payload')
          .eq('user_id', userId);

      final projects = <Project>[];
      for (final row in response as List) {
        final encryptedPayload = row['encrypted_payload'] as String;
        final jsonData = await EncryptionService.decryptJson(encryptedPayload);
        projects.add(Project.fromJson(jsonData));
      }

      debugPrint('ProjectSyncRepository: Downloaded ${projects.length} projects');
      return projects;
    } catch (e) {
      debugPrint('ProjectSyncRepository: Failed to download projects: $e');
      rethrow;
    }
  }

  /// Delete a project from Supabase
  static Future<void> deleteProject(String projectId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      await SupabaseService.client.from('projects').delete().eq('id', projectId);
      debugPrint('ProjectSyncRepository: Deleted project $projectId');
    } catch (e) {
      debugPrint('ProjectSyncRepository: Failed to delete project: $e');
      rethrow;
    }
  }
}
