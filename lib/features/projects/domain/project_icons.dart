import 'package:flutter/widgets.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Fixed palette of selectable project icons. Stored by string key (the solar
/// icon name) so the [IconData] stays `const` and tree-shaking still works.
// MDI icon getters are non-const, so this map can't be `const` (use `final`).
final Map<String, IconData> kProjectIcons = {
  'folder': MdiIcons.folder,
  'checklist': MdiIcons.formatListChecks,
  'notes': MdiIcons.noteText,
  'home': MdiIcons.home,
  'cart': MdiIcons.cart,
  'bag': MdiIcons.shopping,
  'heart': MdiIcons.heart,
  'star': MdiIcons.star,
  'flag': MdiIcons.flag,
  'book': MdiIcons.book,
  'case': MdiIcons.briefcase,
  'wallet': MdiIcons.wallet,
  'chart': MdiIcons.chartBox,
  'target': MdiIcons.target,
  'fire': MdiIcons.fire,
  'cup': MdiIcons.coffee,
  'dumbbell': MdiIcons.dumbbell,
  'gift': MdiIcons.gift,
  'suitcase': MdiIcons.briefcase,
  'music': MdiIcons.musicNote,
  'gamepad': MdiIcons.gamepadVariant,
  'palette': MdiIcons.palette,
  'code': MdiIcons.codeTags,
  'cpu': MdiIcons.chip,
  'smartphone': MdiIcons.cellphone,
  'camera': MdiIcons.camera,
  'leaf': MdiIcons.leaf,
  'sun': MdiIcons.weatherSunny,
  'moon': MdiIcons.weatherNight,
  'cloud': MdiIcons.cloud,
  'football': MdiIcons.soccer,
  'crown': MdiIcons.crown,
  'key': MdiIcons.key,
  'lock': MdiIcons.lock,
  'shield': MdiIcons.shield,
  'bell': MdiIcons.bell,
  'calendar': MdiIcons.calendar,
  'clock': MdiIcons.clock,
  'map': MdiIcons.mapMarker,
  'rocket': MdiIcons.rocketLaunch,
  'atom': MdiIcons.atom,
  'pill': MdiIcons.pill,
  'heartPulse': MdiIcons.heartPulse,
  'tag': MdiIcons.tag,
};

const String kDefaultProjectIcon = 'folder';

/// Resolve a stored icon key to its [IconData], falling back to the default.
IconData projectIconFor(String? key) =>
    kProjectIcons[key] ?? kProjectIcons[kDefaultProjectIcon]!;
