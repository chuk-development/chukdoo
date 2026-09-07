import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../providers/settings_provider.dart';

/// Confirmation, password entry and progress in the app's own modal surface.
///
/// Settings used to raise bare `AlertDialog`s here, which are the only place
/// in the app that still looked like stock Material. Everything goes through
/// [showAppPicker] now, so a settings modal flies in exactly like a priority
/// or reminder picker.

/// Body padding shared by every sheet below, matching a picker's row inset.
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(
  AppShapes.listInset + 8,
  0,
  AppShapes.listInset + 8,
  0,
);

Widget _message(String text) {
  return Padding(
    padding: _bodyPadding,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

Widget _actions({
  required BuildContext context,
  required String cancelLabel,
  required String confirmLabel,
  required VoidCallback onConfirm,
  bool destructive = false,
}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(
      AppShapes.listInset + 8,
      18,
      AppShapes.listInset + 8,
      0,
    ),
    child: Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: onConfirm,
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ),
      ],
    ),
  );
}

/// Yes/no question. Returns true only when the user confirmed.
Future<bool> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showAppPicker<bool>(
    context: context,
    builder: (ctx) => PickerSheetScaffold(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _message(message),
          _actions(
            context: ctx,
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            destructive: destructive,
            onConfirm: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// One-button notice with an optional second action (e.g. "Share").
///
/// Returns true when the extra action was tapped.
Future<bool> showNoticeSheet({
  required BuildContext context,
  required String title,
  required String message,
  String dismissLabel = 'OK',
  String? actionLabel,
}) async {
  final result = await showAppPicker<bool>(
    context: context,
    builder: (ctx) => PickerSheetScaffold(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _message(message),
          if (actionLabel == null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppShapes.listInset + 8,
                18,
                AppShapes.listInset + 8,
                0,
              ),
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dismissLabel),
              ),
            )
          else
            _actions(
              context: ctx,
              cancelLabel: dismissLabel,
              confirmLabel: actionLabel,
              onConfirm: () => Navigator.pop(ctx, true),
            ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Asks for the account password. Returns null when the sheet was dismissed.
Future<String?> showPasswordSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) {
  return showAppPicker<String>(
    context: context,
    builder: (_) => _TextSheet(
      title: title,
      message: message,
      label: 'Password',
      hint: 'Your password',
      confirmLabel: confirmLabel,
      obscure: true,
    ),
  );
}

/// Asks for one line of text. Returns null when the sheet was dismissed.
Future<String?> showTextSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String label,
  required String hint,
  required String confirmLabel,
  String initialValue = '',
}) {
  return showAppPicker<String>(
    context: context,
    builder: (_) => _TextSheet(
      title: title,
      message: message,
      label: label,
      hint: hint,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );
}

class _TextSheet extends StatefulWidget {
  final String title;
  final String message;
  final String label;
  final String hint;
  final String confirmLabel;
  final String initialValue;
  final bool obscure;

  const _TextSheet({
    required this.title,
    required this.message,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    this.initialValue = '',
    this.obscure = false,
  });

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.obscure ? _controller.text : _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return PickerSheetScaffold(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message.isNotEmpty) _message(widget.message),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppShapes.listInset,
              widget.message.isEmpty ? 0 : 14,
              AppShapes.listInset,
              0,
            ),
            child: AppField(
              label: widget.label,
              child: TextField(
                controller: _controller,
                obscureText: widget.obscure,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                decoration: AppField.decoration(widget.hint),
              ),
            ),
          ),
          _actions(
            context: context,
            cancelLabel: 'Cancel',
            confirmLabel: widget.confirmLabel,
            onConfirm: _submit,
          ),
        ],
      ),
    );
  }
}

/// First day of the week. Calendar and habits ask the same question, so they
/// ask it through the same sheet.
Future<void> pickWeekStart(
  BuildContext context, {
  required WeekStart current,
  required ValueChanged<WeekStart> onPicked,
}) async {
  final picked = await showPickerSheet<WeekStart>(
    context: context,
    title: 'First day of week',
    options: [
      for (final start in WeekStart.values)
        PickerOption(
          value: start,
          label: start.label,
          icon: MdiIcons.calendarWeekBeginOutline,
          selected: start == current,
        ),
    ],
  );
  if (picked != null) onPicked(picked);
}

/// Blocking spinner in the same surface. Close it with `Navigator.pop`.
void showProgressSheet(BuildContext context, String message) {
  showAppPicker<void>(
    context: context,
    dismissible: false,
    builder: (ctx) => PickerSheetScaffold(
      title: message,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
}
