import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/ics_feeds_provider.dart';
import '../../services/ics_feed_service.dart';

/// Subscribed ICS calendars: add a feed URL, refresh it, remove it.
///
/// Feeds are fetched on the client when the app opens, so nothing has to run
/// on a server for a subscription to stay current.
class IcsFeedsSheet extends ConsumerStatefulWidget {
  const IcsFeedsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAppPicker<void>(
      context: context,
      builder: (_) => const IcsFeedsSheet(),
    );
  }

  @override
  ConsumerState<IcsFeedsSheet> createState() => _IcsFeedsSheetState();
}

class _IcsFeedsSheetState extends ConsumerState<IcsFeedsSheet> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // webcal:// is just https:// under another name.
    final normalized = IcsFeedService.normalizeUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() => _error = 'Enter a full URL (https://… or webcal://…)');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final feed = await ref
        .read(icsFeedsProvider.notifier)
        .add(url: normalized, name: _nameController.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = feed.lastError;
      if (feed.lastError == null) {
        _urlController.clear();
        _nameController.clear();
      }
    });
    ref.read(calendarEventProvider.notifier).refresh();
  }

  Future<void> _refresh(IcsFeed feed) async {
    setState(() => _busy = true);
    await ref.read(icsFeedsProvider.notifier).refresh(feed);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(calendarEventProvider.notifier).refresh();
  }

  Future<void> _remove(IcsFeed feed) async {
    await ref.read(icsFeedsProvider.notifier).remove(feed);
    if (!mounted) return;
    ref.read(calendarEventProvider.notifier).refresh();
  }

  String _subtitle(IcsFeed feed) {
    if (feed.lastError != null) return 'Failed: ${feed.lastError}';
    if (feed.lastSyncAt == null) return 'Not loaded yet';
    final t = feed.lastSyncAt!;
    return 'Updated ${t.day}.${t.month}. '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final feeds = ref.watch(icsFeedsProvider);

    return PickerSheetScaffold(
      title: 'Subscribed calendars',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (feeds.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppShapes.listInset,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < feeds.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppShapes.groupGap,
                      ),
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: AppShapes.row(
                          isFirst: i == 0,
                          isLast: i == feeds.length - 1,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _FeedRow(
                          feed: feeds[i],
                          subtitle: _subtitle(feeds[i]),
                          busy: _busy,
                          onRefresh: () => _refresh(feeds[i]),
                          onRemove: () => _remove(feeds[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Add a feed — filled blocks, no outline.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: AppFieldGroup(
              children: [
                AppField(
                  label: 'Calendar URL (.ics)',
                  isFirst: true,
                  isLast: false,
                  child: TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    cursorColor: AppColors.primary,
                    style: const TextStyle(fontSize: 15),
                    decoration: AppField.decoration('https://…'),
                  ),
                ),
                AppField(
                  label: 'Name (optional)',
                  isFirst: false,
                  isLast: true,
                  child: TextField(
                    controller: _nameController,
                    cursorColor: AppColors.primary,
                    style: const TextStyle(fontSize: 15),
                    decoration: AppField.decoration('Taken from the feed'),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _busy ? null : _add,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: const StadiumBorder(),
                ),
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Icon(MdiIcons.plus, size: 20),
                label: const Text('Subscribe'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Feeds are read-only and reload when you open the app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  final IcsFeed feed;
  final String subtitle;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;

  const _FeedRow({
    required this.feed,
    required this.subtitle,
    required this.busy,
    required this.onRefresh,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final failed = feed.lastError != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Color(feed.color),
              shape: BoxShape.circle,
            ),
            child: Icon(
              failed ? MdiIcons.alert : MdiIcons.calendarSync,
              size: 15,
              color: Color(feed.color).computeLuminance() > 0.6
                  ? const Color(0xFF1A1A22)
                  : Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feed.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: failed ? AppColors.error : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(MdiIcons.refresh, size: 20),
            color: AppColors.textSecondary,
            onPressed: busy ? null : onRefresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(MdiIcons.trashCanOutline, size: 20),
            color: AppColors.error,
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
