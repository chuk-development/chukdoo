import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/error/error_overlay.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

class ChukdooApp extends ConsumerWidget {
  const ChukdooApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    final app = MaterialApp.router(
      title: 'Chukdoo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return ErrorOverlay(child: child ?? const SizedBox.shrink());
      },
    );

    if (kIsWeb) {
      return app;
    }
    return _buildWithTray(app);
  }
}

Widget _buildWithTray(Widget child) {
  return child;
}
