import 'package:flutter/material.dart';

/// Chrome that follows a [PageView] under the finger without being a second
/// pager.
///
/// The time grid pages only its day columns, but the date header above them
/// has to travel with those columns — while staying put vertically, outside
/// the scroll view. A second [PageView] cannot do that: one [PageController]
/// drives one viewport, and a second controller kept in sync would always lag
/// by a frame and would fight the first one for the drag.
///
/// So this is not a scrollable at all. It listens to the page controller,
/// reads the *fractional* page and paints the one or two pages that are on
/// screen, each translated by the fraction — the same offset the columns under
/// it have, to the pixel.
class SlidingPageRow extends StatelessWidget {
  /// The controller of the paged viewport this follows.
  final PageController controller;

  /// The page to draw before the controller has a position, and whenever it
  /// cannot answer (a rebase, the very first frame).
  final int fallbackPage;

  /// Builds the chrome of one page. Every page must build to the same height
  /// for the row not to jump — the callers reserve a fixed header height and a
  /// fixed number of all-day rows for exactly that reason.
  final Widget Function(BuildContext context, int page) builder;

  const SlidingPageRow({
    super.key,
    required this.controller,
    required this.fallbackPage,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = _page();
        final base = page.floor();
        final fraction = page - base;

        // The page width is the paged viewport's own, not this row's: both sit
        // beside the same hour gutter, so they are equal — but reading it from
        // the controller means no LayoutBuilder here, which would break the
        // intrinsic sizing the surrounding rows rely on.
        final width = controller.hasClients
            ? controller.position.viewportDimension
            : 0.0;

        // Settled, or nothing to slide against: one page, full width, no
        // transform. This is also the state the very first frame is in.
        if (fraction == 0 || width <= 0) {
          return builder(context, base);
        }

        return ClipRect(
          child: Stack(
            children: [
              // Both children are laid out unpositioned, so the stack takes
              // the height of the taller one and the translate is paint-only.
              _slot(context, base, -fraction * width, width),
              _slot(context, base + 1, (1 - fraction) * width, width),
            ],
          ),
        );
      },
    );
  }

  Widget _slot(BuildContext context, int page, double dx, double width) {
    return Transform.translate(
      offset: Offset(dx, 0),
      child: SizedBox(width: width, child: builder(context, page)),
    );
  }

  /// The fractional page, or the fallback while the controller has no
  /// position to read.
  double _page() {
    if (!controller.hasClients || controller.positions.length != 1) {
      return fallbackPage.toDouble();
    }
    final position = controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return fallbackPage.toDouble();
    }
    return controller.page ?? fallbackPage.toDouble();
  }
}
