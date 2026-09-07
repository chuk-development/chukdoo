import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/entity_edit_sheet.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/calendar.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/ics_feeds_provider.dart';
import '../../services/ics_feed_service.dart';
import 'calendar_style.dart';

/// Creates a calendar, or renames, recolours and deletes an existing one.
///
/// One sheet for both jobs: the drawer's footer opens it empty, a long press
/// on a calendar row opens it filled. The form itself is [EntityEditSheet],
/// the same one "New project" and "New folder" use — only the palette, the
/// labels and the delete action come from here.
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
  late int _color =
      widget.calendar?.color ?? CalendarStyle.eventColors.first.toARGB32();

  bool get _isEditing => widget.calendar != null;

  Future<void> _save(EntityEditValues values) async {
    final notifier = ref.read(calendarContainerProvider.notifier);
    if (_isEditing) {
      await notifier.updateCalendar(
        widget.calendar!.copyWith(name: values.name, color: _color),
      );
    } else {
      await notifier.addCalendar(name: values.name, color: _color);
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
    return EntityEditSheet(
      title: _isEditing ? 'Edit calendar' : 'New calendar',
      nameHint: 'Work, Family, Sport…',
      initialName: widget.calendar?.name ?? '',
      colors: CalendarStyle.eventColors,
      selectedColor: _color,
      onColorChanged: (value) => setState(() => _color = value),
      deleteLabel: _isEditing ? 'Delete calendar' : null,
      onDelete: _isEditing ? _delete : null,
      saveLabel: _isEditing ? 'Save' : 'Create',
      onSave: _save,
    );
  }
}

/// Rename a subscribed feed and repaint it. The URL and the events stay as
/// they are — a feed is read-only, only its label belongs to the user.
///
/// The URL is a fact, not an input, so it is shown as the sheet's footnote
/// instead of a second field; everything else is the shared form.
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
  late int _color = widget.feed.color;

  Future<void> _save(EntityEditValues values) async {
    await ref
        .read(icsFeedsProvider.notifier)
        .update(widget.feed, name: values.name, color: _color);
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
    return EntityEditSheet(
      title: 'Subscribed calendar',
      nameHint: 'Taken from the feed',
      initialName: widget.feed.name,
      footnote: 'Source: ${widget.feed.url}',
      colors: CalendarStyle.eventColors,
      selectedColor: _color,
      onColorChanged: (value) => setState(() => _color = value),
      deleteLabel: 'Unsubscribe',
      onDelete: _remove,
      onSave: _save,
    );
  }
}
