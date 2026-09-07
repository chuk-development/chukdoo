import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';

/// Checkbox size options
/// Row density of the task lists. [medium] is the default look; [small] fits
/// more tasks on screen, [large] gives a bigger tap target.
enum CheckboxSize {
  small,
  medium,
  large;

  /// Diameter of the circle.
  double get circle => switch (this) {
    CheckboxSize.small => 20,
    CheckboxSize.medium => 23,
    CheckboxSize.large => 28,
  };

  /// Vertical padding of a task row.
  double get rowPadding => switch (this) {
    CheckboxSize.small => 8,
    CheckboxSize.medium => 11,
    CheckboxSize.large => 15,
  };

  /// Title size of a task row.
  double get titleSize => switch (this) {
    CheckboxSize.small => 15,
    CheckboxSize.medium => 16,
    CheckboxSize.large => 17,
  };

  String get label => switch (this) {
    CheckboxSize.small => 'Small',
    CheckboxSize.medium => 'Medium',
    CheckboxSize.large => 'Large',
  };
}

/// User settings stored locally
class AppSettings {
  /// Size of the checkbox circle in todo items
  final CheckboxSize checkboxSize;

  /// User-chosen name for the main list (formerly "Eingang").
  final String mainListName;

  /// All tag names the user has ever used — drives autocomplete suggestions.
  final List<String> knownTags;

  /// When true, recolor accent + surfaces from the system wallpaper palette
  /// (Material You) instead of the default platinum theme.
  final bool materialYou;

  const AppSettings({
    this.checkboxSize = CheckboxSize.medium,
    this.mainListName = 'Aufgaben',
    this.knownTags = const [],
    this.materialYou = false,
  });

  AppSettings copyWith({
    CheckboxSize? checkboxSize,
    String? mainListName,
    List<String>? knownTags,
    bool? materialYou,
  }) {
    return AppSettings(
      checkboxSize: checkboxSize ?? this.checkboxSize,
      mainListName: mainListName ?? this.mainListName,
      knownTags: knownTags ?? this.knownTags,
      materialYou: materialYou ?? this.materialYou,
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
  static const _materialYouKey = 'material_you';

  Box? _box;

  Box get _settingsBox {
    _box ??= Hive.box(AppConstants.hiveSettingsBox);
    return _box!;
  }

  void _loadSettings() {
    // Stored as an index. The old setting only knew normal(0)/large(1), so a
    // stored 0 becomes medium and a stored 1 stays large.
    final sizeIndex = _settingsBox.get(_checkboxSizeKey, defaultValue: 1) as int;
    final size = sizeIndex < CheckboxSize.values.length
        ? CheckboxSize.values[sizeIndex]
        : CheckboxSize.medium;
    final mainListName =
        _settingsBox.get(_mainListNameKey, defaultValue: 'Aufgaben') as String;
    final knownTags = (_settingsBox.get(_knownTagsKey) as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final materialYou =
        _settingsBox.get(_materialYouKey, defaultValue: false) as bool;
    state = AppSettings(
      checkboxSize: size,
      mainListName: mainListName,
      knownTags: knownTags,
      materialYou: materialYou,
    );
  }

  Future<void> setMaterialYou(bool enabled) async {
    await _settingsBox.put(_materialYouKey, enabled);
    state = state.copyWith(materialYou: enabled);
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
