import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/markdown_editing.dart';

/// The Markdown bar that sits directly above the keyboard while the note body
/// is being written.
///
/// Markdown on a phone is unusable if every `#`, `*` and `- [ ]` has to be
/// typed on the symbol layer of the keyboard. Each button rewrites the source
/// around the current selection and puts the caret back where writing can go
/// on, so the keyboard never has to be dismissed.
class NoteFormatBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const NoteFormatBar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  /// Apply one transform and hand the caret back to the field.
  void _apply(MarkdownEdit Function(String text, int start, int end) edit) {
    final text = controller.text;
    final selection = controller.selection;
    // A bar press can arrive before the field ever held a caret; the end of
    // the text is the only safe place to work from.
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    final result = edit(text, start, end);
    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.selectionStart.clamp(0, result.text.length),
        extentOffset: result.selectionEnd.clamp(0, result.text.length),
      ),
    );
    if (!focusNode.hasFocus) focusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <_FormatButton>[
      _FormatButton(MdiIcons.formatHeader1, 'Heading 1', () {
        _apply((t, s, e) => toggleLinePrefix(t, s, e, '# '));
      }),
      _FormatButton(MdiIcons.formatHeader2, 'Heading 2', () {
        _apply((t, s, e) => toggleLinePrefix(t, s, e, '## '));
      }),
      _FormatButton(MdiIcons.formatBold, 'Bold', () {
        _apply(
          (t, s, e) => wrapSelection(t, s, e, '**', '**', placeholder: 'bold'),
        );
      }),
      _FormatButton(MdiIcons.formatItalic, 'Italic', () {
        _apply(
          (t, s, e) => wrapSelection(t, s, e, '*', '*', placeholder: 'italic'),
        );
      }),
      _FormatButton(MdiIcons.formatListBulleted, 'Bullet list', () {
        _apply((t, s, e) => toggleLinePrefix(t, s, e, '- '));
      }),
      _FormatButton(MdiIcons.formatListNumbered, 'Numbered list', () {
        _apply((t, s, e) => toggleLinePrefix(t, s, e, '1. ', ordered: true));
      }),
      _FormatButton(MdiIcons.checkboxMarkedOutline, 'Checkbox', () {
        _apply((t, s, e) => toggleLinePrefix(t, s, e, '- [ ] '));
      }),
      _FormatButton(MdiIcons.formatQuoteClose, 'Quote', () {
        _apply((t, s, e) => toggleLinePrefix(t, s, e, '> '));
      }),
      _FormatButton(MdiIcons.codeTags, 'Code', () {
        _apply(
          (t, s, e) => wrapSelection(t, s, e, '`', '`', placeholder: 'code'),
        );
      }),
      _FormatButton(MdiIcons.linkVariant, 'Link', () {
        _apply(insertLink);
      }),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        AppShapes.groupGap,
        AppShapes.listInset,
        AppShapes.dockMargin,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShapes.dockField),
      ),
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: buttons.length,
        itemBuilder: (context, i) => buttons[i],
      ),
    );
  }
}

/// One bar button: icon only, same weight as every other one.
class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FormatButton(this.icon, this.tooltip, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      color: AppColors.textSecondary,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
