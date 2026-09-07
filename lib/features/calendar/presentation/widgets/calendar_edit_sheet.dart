import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/calendar.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/ics_feeds_provider.dart';
import '../../services/ics_feed_service.dart';
import 'calendar_style.dart';
import 'color_swatch_grid.dart';

/// Creates a calendar, or renames, recolours and deletes an existing one.
///
/// One sheet for both jobs: the drawer's footer opens it empty, a long press
/// on a calendar row opens it filled.
class CalendarEditSheet extends ConsumerStatefulWidget {
  final Calendar? calendar;

  const CalendarEditSheet({super.key, this.calendar});

  static Future<void> show(BuildContext context, {Calendar? calendar}) {
    return showAppPicker<void>(
      context: context,
      builder: (_) => CalendarEditSheet(calendar: calendar),
    );
  }

  @override
  ConsumerState<CalendarEditSheet> createState() => _CalendarEditSheetState();
}

class _CalendarEditSheetState extends ConsumerState<CalendarEditSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.calendar?.name ?? '',
  );

  late int _color =
      widget.calendar?.color ?? CalendarStyle.eventColors.first.toARGB32();

  bool get _isEditing => widget.calendar != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(calendarContainerProvider.notifier);
    if (_isEditing) {
      await notifier.updateCalendar(
        widget.calendar!.copyWith(name: name, color: _color),
      );
    } else {
      await notifier.addCalendar(name: name, color: _color);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showPickerSheet<bool>(
      context: context,
      title: 'Delete "${widget.calendar!.name}"?',
      options: [
        PickerOption(
          value: true,
          label: 'Delete calendar',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
        PickerOption(
          value: false,
          label: 'Keep it',
          icon: MdiIcons.undoVariant,
        ),
      ],
      footnote: 'The events stay, but they lose their calendar.',
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(calendarContainerProvider.notifier)
        .deleteCalendar(widget.calendar!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PickerSheetScaffold(
      title: _isEditing ? 'Edit calendar' : 'New calendar',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: AppField(
              label: 'Name',
              child: TextField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: AppColors.primary,
                style: const TextStyle(fontSize: 15),
                onSubmitted: (_) => _save(),
                decoration: AppField.decoration('Work, Family, Sport…'),
              ),
            ),
          ),
          const SizedBox(height: AppShapes.groupGap),
          ColorSwatchGrid(
            selected: _color,
            onPick: (value) => setState(() => _color = value),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: Icon(MdiIcons.trashCanOutline, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      shape: const StadiumBorder(),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(_isEditing ? 'Save' : 'Create'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rename a subscribed feed and repaint it. The URL and the events stay as
/// they are — a feed is read-only, only its label belongs to the user.
class IcsFeedEditSheet extends ConsumerStatefulWidget {
  final IcsFeed feed;

  const IcsFeedEditSheet({super.key, required this.feed});

  static Future<void> show(BuildContext context, IcsFeed feed) {
    return showAppPicker<void>(
      context: context,
      builder: (_) => IcsFeedEditSheet(feed: feed),
    );
  }

  @override
  ConsumerState<IcsFeedEditSheet> createState() => _IcsFeedEditSheetState();
}

class _IcsFeedEditSheetState extends ConsumerState<IcsFeedEditSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.feed.name,
  );

  late int _color = widget.feed.color;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    await ref
        .read(icsFeedsProvider.notifier)
        .update(widget.feed, name: name.isEmpty ? null : name, color: _color);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    final confirmed = await showPickerSheet<bool>(
      context: context,
      title: 'Unsubscribe from "${widget.feed.name}"?',
      options: [
        PickerOption(
          value: true,
          label: 'Unsubscribe',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
        PickerOption(
          value: false,
          label: 'Keep it',
          icon: MdiIcons.undoVariant,
        ),
      ],
      footnote: 'Its events are removed from the device.',
    );
    if (confirmed != true || !mounted) return;

    await ref.read(icsFeedsProvider.notifier).remove(widget.feed);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PickerSheetScaffold(
      title: 'Subscribed calendar',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: AppFieldGroup(
              children: [
                AppField(
                  label: 'Name',
                  isFirst: true,
                  isLast: false,
                  child: TextField(
                    controller: _nameController,
                    cursorColor: AppColors.primary,
                    style: const TextStyle(fontSize: 15),
                    onSubmitted: (_) => _save(),
                    decoration: AppField.decoration('Taken from the feed'),
                  ),
                ),
                AppField(
                  label: 'Source',
                  isFirst: false,
                  isLast: true,
                  child: Text(
                    widget.feed.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppShapes.groupGap),
          ColorSwatchGrid(
            selected: _color,
            onPick: (value) => setState(() => _color = value),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _remove,
                  icon: Icon(MdiIcons.trashCanOutline, size: 18),
                  label: const Text('Unsubscribe'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    shape: const StadiumBorder(),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
