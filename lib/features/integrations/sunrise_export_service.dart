import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_utils.dart';
import '../sync/services/sync_service.dart';
import '../todos/domain/models/todo.dart';

/// Exports today's pending todos to a SharedPreferences key that is read by
/// [SunriseExportProvider] (a ContentProvider) and exposed to other apps —
/// currently the companion Sunrise morning-briefing app.
///
/// Gated by the user-facing `sunrise_enabled` preference. When OFF, the
/// content provider returns enabled=0 and no data.
class SunriseExportService {
  static const _keyEnabled = 'sunrise_enabled';
  static const _keyTodos = 'sunrise_todos';
  static const _keyUpdatedAt = 'sunrise_updated_at';
  static const _keyPendingComplete = 'sunrise_pending_complete';
  static const _keyPendingUncomplete = 'sunrise_pending_uncomplete';
  static const _channel = MethodChannel('doo.chuk.dev/sunrise');
  static const _events = EventChannel('doo.chuk.dev/sunrise_events');

  /// Stream that fires whenever ANY app mutates the shared content URI —
  /// including Sunrise marking a todo complete or a future companion app.
  /// Listeners (e.g. AutoSyncManager) should call [processPending] then
  /// refresh the todo provider so Chukdoo's UI updates in real time.
  static Stream<void> changes() =>
      _events.receiveBroadcastStream().map((_) {});

  /// Tell observers (other apps registered on the content URI) that the
  /// exported snapshot changed. No-op when platform channel isn't available.
  static Future<void> _notify() async {
    if (!PlatformUtils.isAndroid) return;
    try {
      await _channel.invokeMethod('notifyChange');
    } catch (_) {}
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyEnabled, v);
    if (v) {
      await update();
    } else {
      await p.remove(_keyTodos);
      await p.remove(_keyUpdatedAt);
    }
  }

  /// Refresh exported snapshot. Safe to call frequently; no-op when disabled.
  static Future<void> update() async {
    if (!PlatformUtils.isAndroid) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool(_keyEnabled) ?? false)) return;

      final todosBox = Hive.box<Map>(AppConstants.hiveTodosBox);
      final all = todosBox.values.map((m) {
        return Todo.fromJson(Map<String, dynamic>.from(m));
      }).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Bucket every todo:
      //   0 = pending today + overdue
      //   1 = inbox pending (no date)
      //   2 = completed today (still shown so other apps can untick)
      //  -1 = irrelevant (skip)
      int bucket(Todo t) {
        if (t.isCompleted) {
          if (t.completedAt == null) return -1;
          final c = DateTime(
              t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
          return c.isAtSameMomentAs(today) ? 2 : -1;
        }
        if (t.dueDate == null) return 1;
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        if (due.isAfter(today)) return -1;
        return 0;
      }

      // Same sort key as Chukdoo's own UI: sortOrder ascending, then
      // createdAt descending (newest first). Bucket separates active from
      // recently-completed so the consumer can render them differently.
      final relevant = all.where((t) => bucket(t) >= 0).toList()
        ..sort((a, b) {
          final bk = bucket(a).compareTo(bucket(b));
          if (bk != 0) return bk;
          final orderCompare = a.sortOrder.compareTo(b.sortOrder);
          if (orderCompare != 0) return orderCompare;
          return b.createdAt.compareTo(a.createdAt);
        });

      final top = relevant.take(20).map((t) {
        return {
          'id': t.id,
          'title': t.title,
          'due_date': t.dueDate?.toIso8601String(),
          'due_time': t.dueTime != null
              ? '${t.dueTime!.hour.toString().padLeft(2, '0')}:${t.dueTime!.minute.toString().padLeft(2, '0')}'
              : null,
          'priority': t.priority.value,
          'is_completed': t.isCompleted,
          'created_at': t.createdAt.toIso8601String(),
          'completed_at': t.completedAt?.toIso8601String(),
        };
      }).toList();

      await p.setString(_keyTodos, jsonEncode(top));
      await p.setInt(_keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
      _notify();
    } catch (e) {
      debugPrint('SunriseExportService: $e');
    }
  }

  /// Apply queued mutations (complete/uncomplete) from Sunrise or any other
  /// observer app. Called on Chukdoo cold-start and resume.
  static Future<void> processPending() async {
    if (!PlatformUtils.isAndroid) return;
    try {
      final p = await SharedPreferences.getInstance();
      // The native ContentProvider writes directly to the underlying
      // SharedPreferences file. Flutter's in-memory cache won't see those
      // writes unless we explicitly reload.
      await p.reload();
      final completeRaw = p.getString(_keyPendingComplete);
      final uncompleteRaw = p.getString(_keyPendingUncomplete);
      final completeIds = _decodeIds(completeRaw);
      final uncompleteIds = _decodeIds(uncompleteRaw);
      debugPrint('SunriseExportService.processPending: complete=$completeIds uncomplete=$uncompleteIds');
      if (completeIds.isEmpty && uncompleteIds.isEmpty) return;

      final box = Hive.box<Map>(AppConstants.hiveTodosBox);
      final now = DateTime.now();
      var mutated = false;

      for (final id in completeIds) {
        final raw = box.get(id);
        if (raw == null) continue;
        final todo = Todo.fromJson(Map<String, dynamic>.from(raw));
        if (todo.isCompleted) continue;
        final updated = todo.copyWith(
          isCompleted: true,
          completedAt: now,
          updatedAt: now,
        );
        await box.put(updated.id, updated.toJson());
        await SyncService.queueOperation(
          entityType: SyncEntityType.todo,
          operation: SyncOperation.update,
          entityId: updated.id,
          data: updated.toJson(),
        );
        mutated = true;
      }

      for (final id in uncompleteIds) {
        final raw = box.get(id);
        if (raw == null) continue;
        final todo = Todo.fromJson(Map<String, dynamic>.from(raw));
        if (!todo.isCompleted) continue;
        final updated = todo.copyWith(
          isCompleted: false,
          completedAt: null,
          updatedAt: now,
        );
        await box.put(updated.id, updated.toJson());
        await SyncService.queueOperation(
          entityType: SyncEntityType.todo,
          operation: SyncOperation.update,
          entityId: updated.id,
          data: updated.toJson(),
        );
        mutated = true;
      }

      await p.remove(_keyPendingComplete);
      await p.remove(_keyPendingUncomplete);
      if (mutated) await update();
    } catch (e) {
      debugPrint('SunriseExportService.processPending: $e');
    }
  }

  static List<String> _decodeIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return const [];
  }
}
