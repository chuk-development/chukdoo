import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/markdown_editing.dart';

/// Read state of a note: Markdown, rendered, with working checkboxes.
///
/// The renderer is [GptMarkdown] — the same one the task description uses, so
/// a note and a task read identically. What it cannot do is let a checkbox be
/// ticked, so task lines are pulled out of the source first and drawn here;
/// everything between them is handed to the renderer untouched.
class NoteMarkdownView extends StatelessWidget {
  final String source;

  /// Called with the rewritten source when a checkbox is tapped.
  final ValueChanged<String> onSourceChanged;

  final TextStyle style;

  const NoteMarkdownView({
    super.key,
    required this.source,
    required this.onSourceChanged,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final buffer = <String>[];
    var inFence = false;

    void flush() {
      if (buffer.isEmpty) return;
      final text = buffer.join('\n');
      buffer.clear();
      if (text.trim().isEmpty) {
        // Blank lines between two task groups still carry the spacing the
        // author typed, so keep them as height instead of dropping them.
        children.add(SizedBox(height: (style.fontSize ?? 16) * 0.6));
        return;
      }
      children.add(
        SizedBox(
          width: double.infinity,
          child: GptMarkdown(text, style: style),
        ),
      );
    }

    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) inFence = !inFence;

      final match = inFence ? null : taskLine.firstMatch(line);
      if (match == null) {
        buffer.add(line);
        continue;
      }

      flush();
      children.add(
        _TaskRow(
          indent: match[1]!.length,
          checked: match[3] != ' ',
          label: match[4] ?? '',
          style: style,
          onToggle: () => onSourceChanged(toggleTaskLine(source, i)),
        ),
      );
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// One `- [ ]` line: a tappable box and its label.
class _TaskRow extends StatelessWidget {
  final int indent;
  final bool checked;
  final String label;
  final TextStyle style;
  final VoidCallback onToggle;

  const _TaskRow({
    required this.indent,
    required this.checked,
    required this.label,
    required this.style,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final size = (style.fontSize ?? 16) + 4;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        // Two nested list levels are two indents of one space unit each.
        padding: EdgeInsets.fromLTRB(indent * 8.0, 3, 0, 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  // A filled block, ticked or not — the design system draws no
                  // outlines, so an empty box is a darker square.
                  color: checked ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: checked
                    ? Icon(
                        MdiIcons.check,
                        size: size - 6,
                        color: AppColors.onPrimary,
                      )
                    : null,
              ),
            ),
            Expanded(
              child: GptMarkdown(
                label.isEmpty ? ' ' : label,
                style: checked
                    ? style.copyWith(
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.textSecondary,
                      )
                    : style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
