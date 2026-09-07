import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/markdown_preview.dart';
import '../../domain/models/note.dart';
import '../../domain/models/note_folder.dart';

/// A single masonry card. Height is intrinsic (grows with content), which is
/// what gives the notes grid its staggered look.
class NoteCard extends StatelessWidget {
  final Note note;

  /// Folder the note lives in. Shown as a tint dot with its name, so the
  /// unfiltered grid still says where a note belongs.
  final NoteFolder? folder;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDragging;

  const NoteCard({
    super.key,
    required this.note,
    this.folder,
    required this.onTap,
    this.onLongPress,
    this.isDragging = false,
  });

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return DateFormat.Hm().format(d); // e.g. 18:14
    if (diff == 1) return 'Yesterday';
    if (d.year == now.year) return DateFormat.MMMMd().format(d); // April 11
    return DateFormat.yMMMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = note.color != null
        ? Color(note.color!)
        : AppColors.surface;
    final hasTitle = note.title.trim().isNotEmpty;
    // Notes are Markdown; a card shows the words, not the marks.
    final preview = markdownToPlainText(note.content);
    final hasContent = preview.isNotEmpty;

    return Opacity(
      opacity: isDragging ? 0.4 : 1,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Icon(
                      MdiIcons.pin,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                  ),
                if (hasTitle)
                  Text(
                    note.title.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                if (hasTitle && hasContent) const SizedBox(height: 8),
                Text(
                  hasContent ? preview : 'No text',
                  maxLines: hasTitle ? 6 : 9,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasContent
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                    height: 1.35,
                    fontStyle: hasContent ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      _formatDate(note.updatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
