import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/error/error_overlay.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_provider.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart';
import 'router.dart';

/// Seed used when the platform can't provide a wallpaper-based palette
/// (non-Android-12 phones, desktop, web) but Material You is switched on.
const _materialYouSeed = Color(0xFF6750A4);

class ChukdooApp extends ConsumerWidget {
  const ChukdooApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final materialYou = ref.watch(
      settingsProvider.select((s) => s.materialYou),
    );

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Recolor the global palette BEFORE the theme is read from AppColors.
        if (materialYou) {
          final scheme = darkDynamic?.harmonized() ??
              ColorScheme.fromSeed(
                seedColor: _materialYouSeed,
                brightness: Brightness.dark,
              );
          AppColors.applyMaterialYou(scheme);
        } else {
          AppColors.resetToPlatinum();
        }

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
            // Widgets read AppColors statics (not InheritedWidgets), so toggling
            // the palette must force the page subtree to rebuild. Keying on the
            // active palette does that without resetting GoRouter's navigation.
            // Key on the live accent so ANY palette change — platinum↔Material
            // You and the late wallpaper-scheme resolution — forces the page
            // subtree to rebuild and re-read the AppColors statics.
            return KeyedSubtree(
              key: ValueKey(AppColors.primary),
              child: ErrorOverlay(child: child ?? const SizedBox.shrink()),
            );
          },
        );

        if (kIsWeb) {
          return app;
        }
        return _buildWithTray(app);
      },
    );
  }
}

Widget _buildWithTray(Widget child) {
  return child;
}
