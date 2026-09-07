import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import 'app_field.dart';
import 'picker_sheet.dart';

/// One duration for every state change inside this form.
const Duration _kMotion = Duration(milliseconds: 180);

/// What the user typed when the sheet was saved.
class EntityEditValues {
  final String name;

  /// Empty when the form has no second field, or when it was left blank.
  final String description;

  const EntityEditValues({required this.name, required this.description});
}

/// The one form of the app for "a thing with a name, a colour and maybe an
/// icon": projects, calendars, note folders, habits, subscribed feeds.
///
/// Every one of these used to build its own form, which is why "New calendar"
/// and "New project" looked nothing alike. Now they all raise this sheet and
/// only hand it their own data — palette, icon set, labels, delete action.
///
/// It is raised through [showAppPicker] and wrapped in [PickerSheetScaffold],
/// so it flies in and sits above the keyboard exactly like every picker.
class EntityEditSheet extends StatefulWidget {
  /// Sheet title, e.g. "New calendar".
  final String title;

  /// Small explanatory line under the actions. Optional.
  final String? footnote;

  /// Label and hint of the required name field.
  final String nameLabel;
  final String nameHint;
  final String initialName;

  /// Second, optional field. Both null means the form has one field only.
  final String? secondLabel;
  final String? secondHint;
  final String initialSecond;

  /// A palette. Null hides the colour block.
  final List<Color>? colors;
  final int? selectedColor;
  final ValueChanged<int>? onColorChanged;

  /// Icon set, keyed by the string that gets stored. Null hides the block.
  final Map<String, IconData>? icons;
  final String? selectedIcon;
  final ValueChanged<String>? onIconChanged;

  /// Extra controls this entity needs and no other does (habit frequency).
  /// Drawn between the icons and the delete row, so the shared parts of the
  /// form keep their order no matter what is added here.
  final Widget? extra;

  /// Destructive row, shown only when editing.
  final String? deleteLabel;
  final VoidCallback? onDelete;

  /// Label of the confirming button, e.g. "Create" or "Save".
  final String saveLabel;

  /// Called with the typed values when Save is tapped. The caller pops.
  final ValueChanged<EntityEditValues> onSave;

  const EntityEditSheet({
    super.key,
    required this.title,
    required this.onSave,
    this.footnote,
    this.nameLabel = 'Name',
    this.nameHint = 'Name',
    this.initialName = '',
    this.secondLabel,
    this.secondHint,
    this.initialSecond = '',
    this.colors,
    this.selectedColor,
    this.onColorChanged,
    this.icons,
    this.selectedIcon,
    this.onIconChanged,
    this.extra,
    this.deleteLabel,
    this.onDelete,
    this.saveLabel = 'Save',
  });

  /// Raise the form the way every modal in the app is raised.
  static Future<T?> show<T>(BuildContext context, EntityEditSheet sheet) {
    return showAppPicker<T>(context: context, builder: (_) => sheet);
  }

  @override
  State<EntityEditSheet> createState() => _EntityEditSheetState();
}

class _EntityEditSheetState extends State<EntityEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _second = TextEditingController(
    text: widget.initialSecond,
  );

  /// The icon area never grows: the sheet has to stay on screen with the
  /// keyboard open, so the icons scroll inside this box instead.
  static const double _iconAreaHeight = 168;

  @override
  void initState() {
    super.initState();
    // Save is disabled while the name is empty, so the button has to rebuild
    // on every keystroke.
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _second.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    widget.onSave(
      EntityEditValues(
        name: _name.text.trim(),
        description: _second.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSecond = widget.secondLabel != null || widget.secondHint != null;
    final colors = widget.colors;
    final icons = widget.icons;

    return PickerSheetScaffold(
      title: widget.title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFieldGroup(
              children: [
                AppField(
                  label: widget.nameLabel,
                  isFirst: true,
                  isLast: !hasSecond,
                  child: TextField(
                    controller: _name,
                    autofocus: widget.initialName.isEmpty,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: AppColors.primary,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    decoration: AppField.decoration(widget.nameHint),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                if (hasSecond)
                  AppField(
                    label: widget.secondLabel,
                    isFirst: false,
                    isLast: true,
                    child: TextField(
                      controller: _second,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: AppColors.primary,
                      minLines: 1,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                      decoration: AppField.decoration(
                        widget.secondHint ?? 'Optional',
                      ),
                    ),
                  ),
              ],
            ),
            if (colors != null) ...[
              const SizedBox(height: AppShapes.groupGap),
              AppField(
                label: 'Colour',
                child: EntityFlushGrid(
                  count: colors.length,
                  minCell: 40,
                  itemBuilder: (i, cell) => EntitySwatch(
                    color: colors[i],
                    size: cell,
                    selected: colors[i].toARGB32() == widget.selectedColor,
                    onTap: () =>
                        widget.onColorChanged?.call(colors[i].toARGB32()),
                  ),
                ),
              ),
            ],
            if (icons != null) ...[
              const SizedBox(height: AppShapes.groupGap),
              AppField(
                label: 'Icon',
                child: SizedBox(
                  height: _iconAreaHeight,
                  child: SingleChildScrollView(
                    child: EntityFlushGrid(
                      count: icons.length,
                      minCell: 40,
                      itemBuilder: (i, cell) {
                        final entry = icons.entries.elementAt(i);
                        final tint = widget.selectedColor != null
                            ? Color(widget.selectedColor!)
                            : AppColors.primary;
                        return _IconTile(
                          icon: entry.value,
                          size: cell,
                          tint: tint,
                          selected: entry.key == widget.selectedIcon,
                          onTap: () => widget.onIconChanged?.call(entry.key),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            if (widget.extra != null) ...[
              const SizedBox(height: AppShapes.groupGap),
              widget.extra!,
            ],
            if (widget.onDelete != null) ...[
              const SizedBox(height: AppShapes.groupGap),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppShapes.groupOuter),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onDelete,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          MdiIcons.trashCanOutline,
                          size: 22,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          widget.deleteLabel ?? 'Delete',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (widget.footnote != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  widget.footnote!,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  // Nothing can be saved without a name, so the button says so
                  // instead of silently doing nothing on tap.
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(widget.saveLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid that fills the width it is given.
///
/// The colour and icon rows used to be a [Wrap] of fixed 36/40px cells, which
/// left a ragged gap at the right edge whenever the row did not divide evenly.
/// Here the cell size comes from the constraints instead, so the last item of
/// every row always ends flush with the right edge.
class EntityFlushGrid extends StatelessWidget {
  final int count;

  /// Smallest cell that still reads well; the column count is derived from it.
  final double minCell;
  final double spacing;

  /// Builds item [index] at the computed [cell] edge length.
  final Widget Function(int index, double cell) itemBuilder;

  const EntityFlushGrid({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.minCell = 40,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // As many columns as fit at [minCell], never fewer than four.
        var columns = ((width + spacing) / (minCell + spacing)).floor();
        if (columns < 4) columns = 4;
        if (columns > count) columns = count;
        if (columns < 1) columns = 1;
        final cell = (width - spacing * (columns - 1)) / columns;
        final rows = (count / columns).ceil();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows; r++)
              Padding(
                padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : spacing),
                child: Row(
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) SizedBox(width: spacing),
                      SizedBox(
                        width: cell,
                        height: cell,
                        // The trailing cells of the last row stay empty so the
                        // items above them keep their column.
                        child: r * columns + c < count
                            ? itemBuilder(r * columns + c, cell)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One colour swatch. The selection ring is the one border the design system
/// allows, because it carries meaning; it is drawn outside the colour so the
/// swatch itself never changes size.
class EntitySwatch extends StatelessWidget {
  final Color color;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  const EntitySwatch({
    super.key,
    required this.color,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  /// Foreground that stays readable on top of [background].
  static Color onColor(Color background) => background.computeLuminance() > 0.6
      ? const Color(0xFF1A1A22)
      : Colors.white;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _kMotion,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            // Transparent when unselected, so the swatch keeps its size.
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? Center(
                  child: Icon(
                    MdiIcons.check,
                    size: size * 0.42,
                    color: onColor(color),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// One icon tile, with the same selection ring as the colour swatches.
class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  const _IconTile({
    required this.icon,
    required this.size,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _kMotion,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? tint.withValues(alpha: 0.18)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppShapes.dockChip),
          border: Border.all(
            color: selected ? tint : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: selected ? tint : AppColors.textSecondary,
        ),
      ),
    );
  }
}
