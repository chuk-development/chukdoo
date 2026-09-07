# third_party

Vendored packages that upstream no longer maintains.

## material_design_icons_flutter (7.0.7296, patched)

Flutter 3.47 made `IconData` a `final` class. The published package builds its
icons with `class _MdiIconData extends IconData`, so `flutter build` fails with:

```
Error: The class 'IconData' can't be extended outside of its library because it's a final class.
```

Upstream is unmaintained (7.0.7296 is the newest release), so this copy patches
`lib/icon_map.dart` to use plain `const IconData(...)` values. Nothing else is
changed; the font asset and the `MdiIcons.*` API are identical.

Wired up through `dependency_overrides` in the root `pubspec.yaml`. If upstream
ever ships a fixed release, drop the override and this directory.
