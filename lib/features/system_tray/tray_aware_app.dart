import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/utils/platform_utils.dart';
import 'system_tray_service.dart';

/// Widget that wraps the app to handle window close events.
/// On desktop, closing the window minimizes to tray instead.
class TrayAwareApp extends StatefulWidget {
  const TrayAwareApp({super.key, required this.child});

  final Widget child;

  @override
  State<TrayAwareApp> createState() => _TrayAwareAppState();
}

class _TrayAwareAppState extends State<TrayAwareApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  bool get _isDesktop => PlatformUtils.isDesktop;

  @override
  void onWindowClose() async {
    // Handle close request - minimize to tray on desktop
    final shouldClose = await SystemTrayService.instance.handleWindowClose();
    if (shouldClose) {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
