import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/calendar_event.dart';
import '../domain/models/ics_service.dart';

/// A subscribed ICS calendar feed (holidays, a shared team calendar, …).
///
/// Feeds are read-only: their events are fetched from the URL and cached
/// locally, never uploaded and never edited in the app.
class IcsFeed {
  final String id;
  final String url;
  final String name;
  final int color;
  final DateTime? lastSyncAt;
  final String? lastError;

  const IcsFeed({
    required this.id,
    required this.url,
    required this.name,
    required this.color,
    this.lastSyncAt,
    this.lastError,
  });

  IcsFeed copyWith({DateTime? lastSyncAt, String? lastError, String? name}) {
    return IcsFeed(
      id: id,
      url: url,
      name: name ?? this.name,
      color: color,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'name': name,
    'color': color,
    'last_sync_at': lastSyncAt?.toIso8601String(),
    'last_error': lastError,
  };

  factory IcsFeed.fromJson(Map<String, dynamic> json) => IcsFeed(
    id: json['id'] as String,
    url: json['url'] as String,
    name: json['name'] as String,
    color: json['color'] as int? ?? 0xFF64B5F6,
    lastSyncAt: json['last_sync_at'] != null
        ? DateTime.tryParse(json['last_sync_at'] as String)
        : null,
    lastError: json['last_error'] as String?,
  );
}

/// Subscribes to remote ICS feeds and refreshes them on the client.
///
/// The refresh runs when the app opens (and on demand), so a feed is up to
/// date without any server component.
class IcsFeedService {
  const IcsFeedService._();

  static const _uuid = Uuid();

  /// Colours a new feed can take, in the order they are handed out. Same
  /// palette the rest of the app paints projects and events with.
  static const _palette = <int>[
    0xFF64B5F6, // Blue
    0xFF7C82E0, // Indigo
    0xFFB388FF, // Purple
    0xFFFFB74D, // Amber
    0xFFC9A66B, // Sand
    0xFF8C90A0, // Slate
  ];

  static Box<Map> get _feedBox => Hive.box<Map>(AppConstants.hiveIcsFeedsBox);
  static Box<Map> get _eventBox =>
      Hive.box<Map>(AppConstants.hiveCalendarEventsBox);

  /// All subscribed feeds.
  static List<IcsFeed> get feeds => _feedBox.values
      .map((m) => IcsFeed.fromJson(Map<String, dynamic>.from(m)))
      .toList();

  /// `webcal://` is `https://` under another name — every calendar provider
  /// hands out that scheme, and `http.get` cannot speak it.
  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('webcal://')) {
      return trimmed.replaceFirst('webcal://', 'https://');
    }
    if (trimmed.startsWith('webcals://')) {
      return trimmed.replaceFirst('webcals://', 'https://');
    }
    return trimmed;
  }

  /// Subscribe to a feed and fetch it once. Returns the stored feed.
  static Future<IcsFeed> addFeed({
    required String url,
    required String name,
    int? color,
  }) async {
    final feed = IcsFeed(
      id: _uuid.v4(),
      url: normalizeUrl(url),
      name: name.trim().isEmpty ? 'Calendar feed' : name.trim(),
      // Each new feed takes the next colour, so two feeds never look alike.
      color: color ?? _palette[feeds.length % _palette.length],
    );
    await _feedBox.put(feed.id, feed.toJson());
    return refresh(feed);
  }

  /// Unsubscribe and drop every event that came from that feed.
  static Future<void> removeFeed(String feedId) async {
    await _deleteEventsOf(feedId);
    await _feedBox.delete(feedId);
  }

  /// Refresh every subscribed feed. Failures are recorded per feed and never
  /// throw, so a dead URL cannot break app start.
  static Future<void> refreshAll() async {
    for (final feed in feeds) {
      await refresh(feed);
    }
  }

  /// Fetch one feed and replace its cached events.
  static Future<IcsFeed> refresh(IcsFeed feed) async {
    try {
      final response = await http
          .get(Uri.parse(feed.url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return await _store(feed.copyWith(lastError: 'HTTP ${response.statusCode}'));
      }

      // ICS is required to be UTF-8; decode explicitly so umlauts survive.
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final events = IcsService.parseEvents(body, 'feed:${feed.id}');

      await _deleteEventsOf(feed.id);
      for (final event in events) {
        // The event id is the feed's own UID, which two feeds can share, so
        // it is namespaced by the feed before it is stored.
        final stored = event.copyWith(
          id: 'feed:${feed.id}:${event.id}',
          calendarId: feed.id,
          color: feed.color,
        );
        await _eventBox.put(stored.id, stored.toJson());
      }

      // A feed that was subscribed without a name takes the name the
      // publisher put in the file.
      final published = _calendarName(body);
      final name = feed.name == 'Calendar feed' && published != null
          ? published
          : feed.name;

      debugPrint('IcsFeedService: $name: ${events.length} events');
      return await _store(
        feed.copyWith(name: name, lastSyncAt: DateTime.now()),
      );
    } catch (e) {
      debugPrint('IcsFeedService: refresh of ${feed.name} failed: $e');
      return _store(feed.copyWith(lastError: e.toString()));
    }
  }

  /// The publisher's own name for the calendar (`X-WR-CALNAME`).
  static String? _calendarName(String ics) {
    for (final line in ics.split(RegExp(r'\r?\n'))) {
      if (line.toUpperCase().startsWith('X-WR-CALNAME')) {
        final value = line.substring(line.indexOf(':') + 1).trim();
        if (value.isNotEmpty) return value;
      }
      if (line.toUpperCase().startsWith('BEGIN:VEVENT')) break;
    }
    return null;
  }

  static Future<IcsFeed> _store(IcsFeed feed) async {
    await _feedBox.put(feed.id, feed.toJson());
    return feed;
  }

  /// Feed events are marked by their user id, so a refresh can replace them
  /// as a whole without touching the user's own events.
  static Future<void> _deleteEventsOf(String feedId) async {
    final keys = <dynamic>[];
    for (final entry in _eventBox.toMap().entries) {
      final map = Map<String, dynamic>.from(entry.value);
      if (map['user_id'] == 'feed:$feedId') keys.add(entry.key);
    }
    await _eventBox.deleteAll(keys);
  }

  /// Whether an event came from a subscribed feed (read-only).
  static bool isFeedEvent(CalendarEvent event) =>
      event.userId.startsWith('feed:');
}
