import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';

/// Checkbox size options
enum CheckboxSize {
  normal,
  large,
}

/// User settings stored locally
class AppSettings {
  /// Size of the checkbox circle in todo items
  final CheckboxSize checkboxSize;

  /// User-chosen name for the main list (formerly "Eingang").
  final String mainListName;

  /// All tag names the user has ever used — drives autocomplete suggestions.
  final List<String> knownTags;

  const AppSettings({
    this.checkboxSize = CheckboxSize.normal,
    this.mainListName = 'Aufgaben',
    this.knownTags = const [],
  });

  AppSettings copyWith({
    CheckboxSize? checkboxSize,
    String? mainListName,
    List<String>? knownTags,
  }) {
    return AppSettings(
      checkboxSize: checkboxSize ?? this.checkboxSize,
      mainListName: mainListName ?? this.mainListName,
      knownTags: knownTags ?? this.knownTags,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _checkboxSizeKey = 'checkbox_size';
  static const _mainListNameKey = 'main_list_name';
  static const _knownTagsKey = 'known_tags';

  Box? _box;

  Box get _settingsBox {
    _box ??= Hive.box(AppConstants.hiveSettingsBox);
    return _box!;
  }

  void _loadSettings() {
    final sizeIndex = _settingsBox.get(_checkboxSizeKey, defaultValue: 0) as int;
    final size = sizeIndex < CheckboxSize.values.length
        ? CheckboxSize.values[sizeIndex]
        : CheckboxSize.normal;
    final mainListName =
        _settingsBox.get(_mainListNameKey, defaultValue: 'Aufgaben') as String;
    final knownTags = (_settingsBox.get(_knownTagsKey) as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    state = AppSettings(
      checkboxSize: size,
      mainListName: mainListName,
      knownTags: knownTags,
    );
  }

  Future<void> setCheckboxSize(CheckboxSize size) async {
    await _settingsBox.put(_checkboxSizeKey, size.index);
    state = state.copyWith(checkboxSize: size);
  }

  Future<void> setMainListName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _settingsBox.put(_mainListNameKey, trimmed);
    state = state.copyWith(mainListName: trimmed);
  }

  /// Remember new tag names so they can be suggested later (case-insensitive).
  Future<void> rememberTags(Iterable<String> tags) async {
    final existing = {for (final t in state.knownTags) t.toLowerCase(): t};
    var changed = false;
    for (final raw in tags) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (!existing.containsKey(t.toLowerCase())) {
        existing[t.toLowerCase()] = t;
        changed = true;
      }
    }
    if (!changed) return;
    final merged = existing.values.toList()..sort();
    await _settingsBox.put(_knownTagsKey, merged);
    state = state.copyWith(knownTags: merged);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
