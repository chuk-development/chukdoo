import 'package:flutter/widgets.dart';
import 'package:solar_icons/solar_icons.dart';

/// Fixed palette of selectable project icons. Stored by string key (the solar
/// icon name) so the [IconData] stays `const` and tree-shaking still works.
const Map<String, IconData> kProjectIcons = {
  'folder': SolarIconsBold.folder,
  'checklist': SolarIconsBold.checklist,
  'notes': SolarIconsBold.notes,
  'home': SolarIconsBold.home,
  'cart': SolarIconsBold.cart,
  'bag': SolarIconsBold.bag,
  'heart': SolarIconsBold.heart,
  'star': SolarIconsBold.star,
  'flag': SolarIconsBold.flag,
  'book': SolarIconsBold.book,
  'case': SolarIconsBold.caseRound,
  'wallet': SolarIconsBold.wallet,
  'chart': SolarIconsBold.chartSquare,
  'target': SolarIconsBold.target,
  'fire': SolarIconsBold.fire,
  'cup': SolarIconsBold.cupHot,
  'dumbbell': SolarIconsBold.dumbbell,
  'gift': SolarIconsBold.gift,
  'suitcase': SolarIconsBold.suitcase,
  'music': SolarIconsBold.musicNote,
  'gamepad': SolarIconsBold.gamepad,
  'palette': SolarIconsBold.palette,
  'code': SolarIconsBold.codeSquare,
  'cpu': SolarIconsBold.cpu,
  'smartphone': SolarIconsBold.smartphone,
  'camera': SolarIconsBold.camera,
  'leaf': SolarIconsBold.leaf,
  'sun': SolarIconsBold.sun,
  'moon': SolarIconsBold.moon,
  'cloud': SolarIconsBold.cloud,
  'football': SolarIconsBold.football,
  'crown': SolarIconsBold.crown,
  'key': SolarIconsBold.key,
  'lock': SolarIconsBold.lock,
  'shield': SolarIconsBold.shield,
  'bell': SolarIconsBold.bell,
  'calendar': SolarIconsBold.calendar,
  'clock': SolarIconsBold.clockCircle,
  'map': SolarIconsBold.mapPoint,
  'rocket': SolarIconsBold.rocket,
  'atom': SolarIconsBold.atom,
  'pill': SolarIconsBold.pill,
  'heartPulse': SolarIconsBold.heartPulse,
  'tag': SolarIconsBold.tag,
};

const String kDefaultProjectIcon = 'folder';

/// Resolve a stored icon key to its [IconData], falling back to the default.
IconData projectIconFor(String? key) =>
    kProjectIcons[key] ?? kProjectIcons[kDefaultProjectIcon]!;
