import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Manages the current app locale, persisted in Hive.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  static const _localeKey = 'locale';

  Box? _box;

  Box get _settingsBox {
    _box ??= Hive.box(AppConstants.hiveSettingsBox);
    return _box!;
  }

  void _loadLocale() {
    final saved = _settingsBox.get(_localeKey, defaultValue: 'en') as String;
    state = Locale(saved);
  }

  Future<void> setLocale(String languageCode) async {
    await _settingsBox.put(_localeKey, languageCode);
    state = Locale(languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
