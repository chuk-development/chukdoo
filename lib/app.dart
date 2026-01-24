import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/error/error_overlay.dart';
import 'core/theme/app_theme.dart';
import 'features/system_tray/tray_aware_app.dart';
import 'router.dart';

class ChukdooApp extends ConsumerWidget {
  const ChukdooApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // TrayAwareApp handles window close events on desktop (minimize to tray)
    return TrayAwareApp(
      child: MaterialApp.router(
        title: 'Chukdoo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: router,
        builder: (context, child) {
          // Wrap the entire app with error overlay
          return ErrorOverlay(
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
