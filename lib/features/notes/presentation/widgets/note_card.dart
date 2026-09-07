import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/markdown_preview.dart';
import '../../domain/models/note.dart';
import '../../domain/models/note_folder.dart';

/// One note in the overview: title, a few words of the text, and a quiet meta
/// line with the date, the folder and the pin.
///
/// One visual weight only — a filled block on the page ground, nothing drawn
/// inside it, no outline. The height is intrinsic (it grows with the text),
/// which is what gives the grid its staggered look; in the list layout the
/// cards form one group, so [isFirst]/[isLast] shape their corners.
class NoteCard extends StatelessWidget {
  final Note note;

  /// Folder the note lives in. Shown as a tint dot with its name, so the
  /// unfiltered grid still says where a note belongs.
  final NoteFolder? folder;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDragging;

  /// Position inside a group. Both true (the default) is a standalone card,
  /// which is what every card in the masonry grid is.
  final bool isFirst;
  final bool isLast;

  const NoteCard({
    super.key,
    required this.note,
    this.folder,
    required this.onTap,
    this.onLongPress,
    this.isDragging = false,
    this.isFirst = true,
    this.isLast = true,
  });

  /// Date the way a human says it: a time today, a word yesterday, a date
  /// after that.
  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return DateFormat.Hm().format(d); // e.g. 18:14
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.EEEE().format(d); // Tuesday
    if (d.year == now.year) return DateFormat.MMMd().format(d); // Apr 11
    return DateFormat.yMMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = note.color != null
        ? Color(note.color!)
        : AppColors.surface;
    final title = note.title.trim();
    // Notes are Markdown; a card shows the words, not the marks.
    final preview = markdownToPlainText(note.content);

    return Opacity(
      opacity: isDragging ? 0.4 : 1,
      child: Material(
        color: cardColor,
        borderRadius: AppShapes.row(isFirst: isFirst, isLast: isLast),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                if (title.isNotEmpty && preview.isNotEmpty)
                  const SizedBox(height: 6),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: title.isNotEmpty ? 6 : 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                if (title.isEmpty && preview.isEmpty)
                  Text(
                    'Empty note',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 10),
                _buildMeta(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Date, folder and pin on one line, all in the same quiet weight.
  Widget _buildMeta() {
    return Row(
      children: [
        Text(
          _formatDate(note.updatedAt),
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
        if (folder != null) ...[
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(folder!.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              folder!.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        ],
        if (note.isPinned) ...[
          const Spacer(),
          Icon(MdiIcons.pin, size: 14, color: AppColors.textTertiary),
        ],
      ],
    );
  }
}
