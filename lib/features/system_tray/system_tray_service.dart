import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/native_io.dart' as native_io;
import '../../core/utils/platform_utils.dart';
import '../sync/services/sync_service.dart';

/// Service for managing system tray on Linux/Windows/macOS desktop.
/// Provides tray icon with menu for quick actions.
class SystemTrayService with TrayListener {
  SystemTrayService._();

  static final SystemTrayService instance = SystemTrayService._();

  bool _isInitialized = false;
  bool _isWindowVisible = true;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether the window is currently visible
  bool get isWindowVisible => _isWindowVisible;

  /// Get the absolute path to the tray icon
  String _getIconPath() {
    // Get the directory where the executable is located
    final exePath = native_io.getResolvedExecutable();
    final exeDir = path.dirname(exePath);

    if (PlatformUtils.isLinux) {
      // For installed app: /opt/chukdoo/data/flutter_assets/assets/images/app_icon.png
      // For dev build: build/linux/x64/release/bundle/data/flutter_assets/assets/images/app_icon.png
      final iconPath = path.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'images',
        'app_icon.png',
      );
      debugPrint('SystemTrayService: Icon path: $iconPath');

      // Check if file exists, fallback to system icon
      if (native_io.fileExists(iconPath)) {
        return iconPath;
      }

      // Try installed path
      const installedPath =
          '/opt/chukdoo/data/flutter_assets/assets/images/app_icon.png';
      if (native_io.fileExists(installedPath)) {
        return installedPath;
      }

      // Fallback to a system icon
      debugPrint('SystemTrayService: Icon not found, using fallback');
      return '/usr/share/icons/hicolor/256x256/apps/chukdoo.png';
    } else if (PlatformUtils.isWindows) {
      return path.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'images',
        'app_icon.ico',
      );
    } else {
      return path.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'images',
        'app_icon.png',
      );
    }
  }

  /// Initialize system tray (desktop only)
  Future<void> initialize() async {
    if (!_isDesktop || _isInitialized) return;

    try {
      debugPrint('SystemTrayService: Initializing...');

      // Initialize window manager
      await windowManager.ensureInitialized();

      // Prevent window from closing (minimize to tray instead)
      await windowManager.setPreventClose(true);

      // Set up tray icon with absolute path
      final iconPath = _getIconPath();
      debugPrint('SystemTrayService: Using icon: $iconPath');

      await trayManager.setIcon(iconPath);

      // Note: setToolTip is not implemented for Linux in tray_manager 0.2.x
      // Skip it on Linux to avoid MissingPluginException
      if (!PlatformUtils.isLinux) {
        await trayManager.setToolTip('Chukdoo - Todo App');
      }

      // Create context menu
      await _updateMenu();

      // Add listener for tray events
      trayManager.addListener(this);

      _isInitialized = true;
      debugPrint('SystemTrayService: Initialized successfully');
    } catch (e, stack) {
      debugPrint('SystemTrayService: Failed to initialize: $e');
      debugPrint('SystemTrayService: Stack: $stack');
      // Don't crash the app if tray fails
      _isInitialized = false;
    }
  }

  bool get _isDesktop => PlatformUtils.isDesktop;

  @override
  void onTrayIconMouseDown() {
    if (!_isInitialized) return;
    try {
      // Left click - toggle window visibility
      _toggleWindow();
    } catch (e) {
      debugPrint('SystemTrayService: Error on mouse down: $e');
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    if (!_isInitialized) return;
    try {
      // Right click - show context menu
      // Note: On Linux with AppIndicator, the menu is shown automatically
      // popUpContextMenu is not implemented for Linux in tray_manager 0.2.x
      if (!PlatformUtils.isLinux) {
        trayManager.popUpContextMenu();
      }
    } catch (e) {
      debugPrint('SystemTrayService: Error showing context menu: $e');
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (!_isInitialized) return;
    try {
      switch (menuItem.key) {
        case 'show_hide':
          _toggleWindow();
          break;
        case 'sync_now':
          _syncNow();
          break;
        case 'quit':
          _quit();
          break;
      }
    } catch (e) {
      debugPrint('SystemTrayService: Error on menu item click: $e');
    }
  }

  /// Toggle window visibility
  Future<void> _toggleWindow() async {
    try {
      if (_isWindowVisible) {
        await windowManager.hide();
        _isWindowVisible = false;
      } else {
        await windowManager.show();
        await windowManager.focus();
        _isWindowVisible = true;
      }
      await _updateMenu();
    } catch (e) {
      debugPrint('SystemTrayService: Error toggling window: $e');
    }
  }

  /// Show the window
  Future<void> showWindow() async {
    try {
      if (!_isWindowVisible) {
        await windowManager.show();
        await windowManager.focus();
        _isWindowVisible = true;
        await _updateMenu();
      }
    } catch (e) {
      debugPrint('SystemTrayService: Error showing window: $e');
    }
  }

  /// Hide the window
  Future<void> hideWindow() async {
    try {
      if (_isWindowVisible) {
        await windowManager.hide();
        _isWindowVisible = false;
        await _updateMenu();
      }
    } catch (e) {
      debugPrint('SystemTrayService: Error hiding window: $e');
    }
  }

  /// Update tray menu labels
  Future<void> _updateMenu() async {
    if (!_isInitialized) return;
    try {
      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_hide',
            label: _isWindowVisible ? 'Hide Window' : 'Show Window',
          ),
          MenuItem.separator(),
          MenuItem(key: 'sync_now', label: 'Sync Now'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('SystemTrayService: Error updating menu: $e');
    }
  }

  /// Trigger immediate sync
  Future<void> _syncNow() async {
    try {
      debugPrint('SystemTrayService: Manual sync triggered from tray');
      await SyncService.fullSync();
    } catch (e) {
      debugPrint('SystemTrayService: Error syncing: $e');
    }
  }

  /// Quit the application
  Future<void> _quit() async {
    debugPrint('SystemTrayService: Quitting application');
    _isInitialized = false;

    try {
      // Remove listener first to prevent callbacks during shutdown
      trayManager.removeListener(this);
      await trayManager.destroy();
    } catch (e) {
      debugPrint('SystemTrayService: Error destroying tray: $e');
    }

    // Use exit(0) for clean shutdown - windowManager.destroy() can crash
    native_io.exitApp(0);
  }

  /// Handle window close request (minimize to tray instead of closing)
  /// Returns true if the window should actually close, false to prevent closing.
  Future<bool> handleWindowClose() async {
    if (_isDesktop && _isInitialized) {
      // Minimize to tray instead of closing
      await hideWindow();
      return false;
    }
    return true;
  }

  /// Update tray tooltip (e.g., with sync status)
  /// Note: Not supported on Linux with tray_manager 0.2.x
  Future<void> updateTooltip(String message) async {
    if (!_isInitialized) return;
    // setToolTip is not implemented for Linux in tray_manager 0.2.x
    if (!PlatformUtils.isLinux) {
      try {
        await trayManager.setToolTip('Chukdoo - $message');
      } catch (e) {
        debugPrint('SystemTrayService: Error updating tooltip: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    if (_isInitialized) {
      trayManager.removeListener(this);
      trayManager.destroy();
      _isInitialized = false;
    }
  }
}
