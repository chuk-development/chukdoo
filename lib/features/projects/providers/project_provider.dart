import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/supabase_service.dart';
import '../../sync/services/sync_service.dart';
import '../domain/models/project.dart';

class ProjectState {
  final List<Project> projects;
  final bool isLoading;
  final String? error;

  const ProjectState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectState copyWith({
    List<Project>? projects,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ProjectState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<Project> get sortedProjects {
    final list = List<Project>.from(projects);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Project? getById(String id) {
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  ProjectNotifier() : super(const ProjectState()) {
    _loadProjects();
  }

  Box<Map>? _box;
  final _uuid = const Uuid();

  Box<Map> get _projectsBox {
    _box ??= Hive.box<Map>(AppConstants.hiveProjectsBox);
    return _box!;
  }

  Future<void> _loadProjects() async {
    state = state.copyWith(isLoading: true);

    try {
      final projectMaps = _projectsBox.values.toList();
      final projects = projectMaps.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Project.fromJson(map);
      }).toList();

      // Sort by sort_order
      projects.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      state = state.copyWith(projects: projects, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Project> addProject({
    required String name,
    int? color,
  }) async {
    final userId = SupabaseService.currentUser?.id ?? 'local';
    final now = DateTime.now();

    final project = Project(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      color: color ?? 0xFF808080,
      sortOrder: state.projects.length,
      createdAt: now,
      updatedAt: now,
    );

    // Save to Hive
    await _projectsBox.put(project.id, project.toJson());

    // Queue sync operation
    await SyncService.queueOperation(
      entityType: SyncEntityType.project,
      operation: SyncOperation.create,
      entityId: project.id,
      data: project.toJson(),
    );

    // Update state
    state = state.copyWith(
      projects: [...state.projects, project],
    );

    return project;
  }

  Future<void> updateProject(Project project) async {
    final updated = project.copyWith(updatedAt: DateTime.now());

    // Save to Hive
    await _projectsBox.put(updated.id, updated.toJson());

    // Queue sync operation
    await SyncService.queueOperation(
      entityType: SyncEntityType.project,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );

    // Update state
    final projects = state.projects.map((p) {
      return p.id == updated.id ? updated : p;
    }).toList();

    state = state.copyWith(projects: projects);
  }

  Future<void> deleteProject(String projectId) async {
    await _projectsBox.delete(projectId);

    // Queue sync operation
    await SyncService.queueOperation(
      entityType: SyncEntityType.project,
      operation: SyncOperation.delete,
      entityId: projectId,
    );

    final projects = state.projects.where((p) => p.id != projectId).toList();
    state = state.copyWith(projects: projects);
  }

  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    final projects = List<Project>.from(state.projects);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final project = projects.removeAt(oldIndex);
    projects.insert(newIndex, project);

    // Update sort orders
    for (var i = 0; i < projects.length; i++) {
      final updated = projects[i].copyWith(sortOrder: i);
      projects[i] = updated;
      await _projectsBox.put(updated.id, updated.toJson());
    }

    state = state.copyWith(projects: projects);
  }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier();
});
