import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../projects/domain/models/project.dart';
import '../../todos/domain/models/todo.dart';

/// Export format version for migration support
const String exportVersion = '1.0';

/// Data export result
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int todoCount;
  final int projectCount;

  const ExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.todoCount = 0,
    this.projectCount = 0,
  });
}

/// Data import preview
class ImportPreview {
  final bool isValid;
  final String? error;
  final String? version;
  final DateTime? exportedAt;
  final List<Todo> todos;
  final List<Project> projects;

  const ImportPreview({
    required this.isValid,
    this.error,
    this.version,
    this.exportedAt,
    this.todos = const [],
    this.projects = const [],
  });

  int get todoCount => todos.length;
  int get projectCount => projects.length;
}

/// Service for exporting and importing data
class ExportService {
  const ExportService._();

  /// Export all data to JSON file
  static Future<ExportResult> exportData() async {
    try {
      // Get all todos
      final todosBox = Hive.box<Map>(AppConstants.hiveTodosBox);
      final todos = todosBox.values.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Todo.fromJson(map);
      }).toList();

      // Get all projects
      final projectsBox = Hive.box<Map>(AppConstants.hiveProjectsBox);
      final projects = projectsBox.values.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Project.fromJson(map);
      }).toList();

      // Create export data
      final exportData = {
        'version': exportVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'appName': AppConstants.appName,
        'todos': todos.map((t) => t.toJson()).toList(),
        'projects': projects.map((p) => p.toJson()).toList(),
      };

      // Convert to JSON string with pretty formatting
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'chukdoo_export_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      // Write file
      final file = File(filePath);
      await file.writeAsString(jsonString);

      debugPrint('ExportService: Exported ${todos.length} todos and ${projects.length} projects to $filePath');

      return ExportResult(
        success: true,
        filePath: filePath,
        todoCount: todos.length,
        projectCount: projects.length,
      );
    } catch (e) {
      debugPrint('ExportService: Export failed: $e');
      return ExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Share exported file
  static Future<void> shareExport(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Chukdoo Daten Export',
      );
    } catch (e) {
      debugPrint('ExportService: Share failed: $e');
    }
  }

  /// Preview import data from JSON string
  static ImportPreview previewImport(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate structure
      if (!data.containsKey('version') ||
          !data.containsKey('todos') ||
          !data.containsKey('projects')) {
        return const ImportPreview(
          isValid: false,
          error: 'Ungültiges Dateiformat',
        );
      }

      final version = data['version'] as String?;
      final exportedAt = data['exportedAt'] != null
          ? DateTime.tryParse(data['exportedAt'] as String)
          : null;

      // Parse todos
      final todosJson = data['todos'] as List<dynamic>? ?? [];
      final todos = <Todo>[];
      for (final t in todosJson) {
        try {
          todos.add(Todo.fromJson(Map<String, dynamic>.from(t as Map)));
        } catch (e) {
          debugPrint('ExportService: Failed to parse todo: $e');
        }
      }

      // Parse projects
      final projectsJson = data['projects'] as List<dynamic>? ?? [];
      final projects = <Project>[];
      for (final p in projectsJson) {
        try {
          projects.add(Project.fromJson(Map<String, dynamic>.from(p as Map)));
        } catch (e) {
          debugPrint('ExportService: Failed to parse project: $e');
        }
      }

      return ImportPreview(
        isValid: true,
        version: version,
        exportedAt: exportedAt,
        todos: todos,
        projects: projects,
      );
    } catch (e) {
      debugPrint('ExportService: Preview failed: $e');
      return ImportPreview(
        isValid: false,
        error: 'Fehler beim Lesen der Datei: ${e.toString()}',
      );
    }
  }

  /// Import data from preview (replaces or merges existing data)
  static Future<bool> importData(ImportPreview preview, {bool replace = false}) async {
    if (!preview.isValid) return false;

    try {
      final todosBox = Hive.box<Map>(AppConstants.hiveTodosBox);
      final projectsBox = Hive.box<Map>(AppConstants.hiveProjectsBox);

      if (replace) {
        // Clear existing data
        await todosBox.clear();
        await projectsBox.clear();
      }

      // Import projects first (todos reference them)
      for (final project in preview.projects) {
        final key = project.id;
        if (!projectsBox.containsKey(key) || replace) {
          await projectsBox.put(key, project.toJson());
        }
      }

      // Import todos
      for (final todo in preview.todos) {
        final key = todo.id;
        if (!todosBox.containsKey(key) || replace) {
          await todosBox.put(key, todo.toJson());
        }
      }

      debugPrint('ExportService: Imported ${preview.todoCount} todos and ${preview.projectCount} projects');
      return true;
    } catch (e) {
      debugPrint('ExportService: Import failed: $e');
      return false;
    }
  }
}
