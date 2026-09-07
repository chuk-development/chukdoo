import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/ics_feed_service.dart';

/// The subscribed ICS feeds as watchable state.
///
/// The service owns the Hive box, but the drawer, the feeds sheet and the
/// item filter all have to react to the same list — reading the box directly
/// from three places is how the drawer used to miss a change.
class IcsFeedsNotifier extends StateNotifier<List<IcsFeed>> {
  IcsFeedsNotifier() : super(IcsFeedService.feeds) {
    // The refresh on app start writes straight into the box, after this
    // notifier may already exist. Watching the box is what makes a renamed
    // or freshly loaded feed appear without reopening the panel.
    _boxSub = IcsFeedService.watch().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), _reload);
    });
  }

  StreamSubscription<BoxEvent>? _boxSub;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _boxSub?.cancel();
    super.dispose();
  }

  void _reload() {
    if (mounted) state = IcsFeedService.feeds;
  }

  Future<IcsFeed> add({required String url, String name = ''}) async {
    final feed = await IcsFeedService.addFeed(url: url, name: name);
    _reload();
    return feed;
  }

  Future<void> refresh(IcsFeed feed) async {
    await IcsFeedService.refresh(feed);
    _reload();
  }

  Future<void> remove(IcsFeed feed) async {
    await IcsFeedService.removeFeed(feed.id);
    _reload();
  }

  Future<void> toggleVisibility(IcsFeed feed) async {
    await IcsFeedService.setVisible(feed, !feed.isVisible);
    _reload();
  }

  Future<void> update(IcsFeed feed, {String? name, int? color}) async {
    await IcsFeedService.update(feed, name: name, color: color);
    _reload();
  }
}

final icsFeedsProvider = StateNotifierProvider<IcsFeedsNotifier, List<IcsFeed>>(
  (ref) {
    return IcsFeedsNotifier();
  },
);

/// Feed ids the views must leave out.
final hiddenFeedIdsProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(icsFeedsProvider)
      .where((f) => !f.isVisible)
      .map((f) => f.id)
      .toSet();
});
