import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const AppSettings({
    this.checkboxSize = CheckboxSize.normal,
  });

  AppSettings copyWith({
    CheckboxSize? checkboxSize,
  }) {
    return AppSettings(
      checkboxSize: checkboxSize ?? this.checkboxSize,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _checkboxSizeKey = 'checkbox_size';

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
    state = AppSettings(checkboxSize: size);
  }

  Future<void> setCheckboxSize(CheckboxSize size) async {
    await _settingsBox.put(_checkboxSizeKey, size.index);
    state = state.copyWith(checkboxSize: size);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
