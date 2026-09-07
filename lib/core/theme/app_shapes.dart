import 'package:flutter/material.dart';

/// Material 3 Expressive shape scale used by the grouped lists and the
/// bottom input dock.
///
/// A list is drawn as one *group* of filled rows: the outer corners of the
/// group are strongly rounded, the corners between two rows are barely
/// rounded, so the group reads as a single block instead of loose cards.
class AppShapes {
  const AppShapes._();

  /// Outer corners of a list group (top of the first row, bottom of the last).
  static const double groupOuter = 26;

  /// Corners shared by two neighbouring rows.
  static const double groupInner = 6;

  /// Vertical gap between two rows of the same group.
  static const double groupGap = 3;

  /// Horizontal inset of a list group from the screen edge.
  static const double listInset = 12;

  /// Footprint of the floating nav bar: its 64 height plus the 8 gap under
  /// it. Content scrolls *under* the bar, so every scrollable adds this much
  /// bottom padding to keep its last row reachable.
  static const double navBarHeight = 72;

  /// Top corners of bottom sheets and the quick-add input dock.
  static const double sheetTop = 28;

  /// Gap between the floating input dock and the screen edge / keyboard.
  static const double dockMargin = 8;

  /// Controls inside a dock/sheet (fields, chips, menus).
  static const double dockField = 20;
  static const double dockChip = 16;

  /// Bottom padding a scrollable needs so its last row clears the floating
  /// nav bar: the bar's own footprint plus the system gesture inset.
  ///
  /// Every list in the app uses this instead of its own guess — the hardcoded
  /// 96 / 100 / SafeArea mix was why the bar looked different per section.
  ///
  /// The inset is read from the view, not from `MediaQuery`: a page sits
  /// inside its own `Scaffold`, which has already eaten the bottom inset, so
  /// `MediaQuery.viewPaddingOf` answers 0 there and the padding came out one
  /// gesture bar too short.
  static double contentBottom(BuildContext context) {
    final view = View.of(context);
    return navBarHeight + view.viewPadding.bottom / view.devicePixelRatio;
  }

  /// Radius for a row at [isFirst]/[isLast] position inside its group.
  static BorderRadius row({required bool isFirst, required bool isLast}) {
    return BorderRadius.vertical(
      top: Radius.circular(isFirst ? groupOuter : groupInner),
      bottom: Radius.circular(isLast ? groupOuter : groupInner),
    );
  }

  /// Top-rounded shape for modal bottom sheets.
  static const RoundedRectangleBorder sheet = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(sheetTop)),
  );
}
