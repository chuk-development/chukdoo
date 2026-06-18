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

  const AppSettings({
    this.checkboxSize = CheckboxSize.normal,
    this.mainListName = 'Aufgaben',
  });

  AppSettings copyWith({
    CheckboxSize? checkboxSize,
    String? mainListName,
  }) {
    return AppSettings(
      checkboxSize: checkboxSize ?? this.checkboxSize,
      mainListName: mainListName ?? this.mainListName,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _checkboxSizeKey = 'checkbox_size';
  static const _mainListNameKey = 'main_list_name';

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
    state = AppSettings(checkboxSize: size, mainListName: mainListName);
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
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
