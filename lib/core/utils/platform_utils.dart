import 'package:flutter/foundation.dart';

/// Web-safe platform detection.
/// Replaces dart:io Platform which crashes on web.
class PlatformUtils {
  static bool get isWeb => kIsWeb;

  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isDesktop => isLinux || isWindows || isMacOS;

  static bool get isMobile => isAndroid || isIOS;
}
