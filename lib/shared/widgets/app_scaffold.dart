import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import 'lifted_fab.dart';

/// The one page frame every section of the app uses.
///
/// Every tab used to bring its own `Scaffold` + `AppBar` + its own guess for
/// the bottom padding (96 here, 100 there, a `SafeArea` in the calendar), so
/// the header height, the title size and the way content passes under the
/// floating nav bar differed per section. This widget fixes all of that in
/// one place:
///
/// * the page paints no background of its own, so the shell's background is
///   what the nav bar blurs — the glass reads the same everywhere;
/// * content runs *under* the nav bar; scrollables add
///   [AppShapes.contentBottom] so their last row stays reachable;
/// * the FAB is lifted clear of the bar by [LiftedFab];
/// * the title row has the same height, the same title style and the same
///   leading/action metrics in every section.
class AppScaffold extends StatelessWidget {
  /// Plain title. Ignored when [titleWidget] is given.
  final String? title;

  /// Title replacement for pages that need more than a string (search field,
  /// the calendar's tappable period title).
  final Widget? titleWidget;

  /// Opens the app drawer. Shows the hamburger when set.
  final VoidCallback? onMenu;

  /// Pops the route. Shows a back chevron when set and [onMenu] is null.
  final VoidCallback? onBack;

  final List<Widget> actions;

  /// Extra chrome directly under the title row — the calendar's view switcher,
  /// a filter strip. Sits in the same column, so it may change height freely.
  final Widget? headerBottom;

  final Widget body;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.onMenu,
    this.onBack,
    this.actions = const [],
    this.headerBottom,
    required this.body,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  /// Height of the title row. Same as the Material app bar it replaces.
  static const double headerHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The shell paints the background. A page that paints its own puts an
      // opaque sheet under the nav bar and kills its blur.
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        // Never bottom: content is meant to pass under the floating bar.
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: title,
              titleWidget: titleWidget,
              onMenu: onMenu,
              onBack: onBack,
              actions: actions,
            ),
            ?headerBottom,
            Expanded(child: body),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton == null
          ? null
          : LiftedFab(child: floatingActionButton),
    );
  }
}

/// The title row of [AppScaffold]. Exposed so a page that cannot use the full
/// frame (an embedded panel, a dialog) still gets the same header.
class AppPageHeader extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onMenu;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const AppPageHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.onMenu,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final leading = onMenu != null
        ? IconButton(
            icon: const Icon(Icons.menu),
            iconSize: 26,
            color: AppColors.textPrimary,
            onPressed: onMenu,
            tooltip: 'Menu',
          )
        : onBack != null
        ? IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 30,
            color: AppColors.textPrimary,
            onPressed: onBack,
            tooltip: 'Back',
          )
        : null;

    return SizedBox(
      height: AppScaffold.headerHeight,
      child: Row(
        children: [
          if (leading != null)
            SizedBox(width: 56, child: leading)
          else
            const SizedBox(width: 20),
          Expanded(
            child:
                titleWidget ??
                Text(
                  title ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
          ),
          // Actions keep the app-bar icon metrics without every page having
          // to say so.
          IconTheme(
            data: IconThemeData(color: AppColors.textPrimary, size: 26),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// An action of [AppPageHeader]: one icon, same size and colour everywhere.
class AppHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;

  const AppHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 26,
      color: color ?? AppColors.textPrimary,
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}
