import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../notifications/reminder_scheduler.dart';
import '../../../sync/services/sync_service.dart';
import '../../../../core/utils/native_io.dart' as native_io;
import 'calendar_event.dart';

const _uuid = Uuid();

class IcsService {
  const IcsService._();

  /// Decode the bytes of a picked .ics file.
  ///
  /// RFC 5545 requires UTF-8, so decode it as such — reading the bytes as
  /// code units turned every umlaut into two broken characters.
  static String decodeBytes(Uint8List bytes) =>
      utf8.decode(bytes, allowMalformed: true);

  /// Export all calendar events as .ics file
  static Future<IcsExportResult> exportIcs() async {
    try {
      final box = Hive.box<Map>(AppConstants.hiveCalendarEventsBox);
      final events = box.values.map((m) {
        return CalendarEvent.fromJson(Map<String, dynamic>.from(m));
      }).toList();

      final ics = _buildIcsString(events);

      if (kIsWeb) {
        return IcsExportResult(
          success: true,
          eventCount: events.length,
          icsContent: ics,
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/chukdoo_calendar.ics';
      await native_io.writeFileAsString(path, ics);

      await Share.shareXFiles([
        XFile(path, mimeType: 'text/calendar'),
      ], subject: 'Chukdoo Kalender Export');

      return IcsExportResult(
        success: true,
        filePath: path,
        eventCount: events.length,
      );
    } catch (e) {
      debugPrint('IcsService: Export failed: $e');
      return IcsExportResult(success: false, error: e.toString());
    }
  }

  /// Import events from .ics file content
  static Future<IcsImportResult> importIcs(
    String icsContent,
    String userId,
  ) async {
    try {
      final events = _parseIcsString(icsContent, userId);
      final box = Hive.box<Map>(AppConstants.hiveCalendarEventsBox);

      int added = 0;
      int updated = 0;

      for (final event in events) {
        final existing = box.get(event.id);
        await box.put(event.id, event.toJson());
        if (existing != null) {
          updated++;
        } else {
          added++;
        }

        // Imported events belong to the account like any other event, so they
        // go through the sync queue instead of staying on this device.
        await SyncService.queueOperation(
          entityType: SyncEntityType.calendarEvent,
          operation: existing != null
              ? SyncOperation.update
              : SyncOperation.create,
          entityId: event.id,
          data: event.toJson(),
        );

        await ReminderScheduler.instance.scheduleForEvent(event);
      }

      return IcsImportResult(success: true, added: added, updated: updated);
    } catch (e) {
      debugPrint('IcsService: Import failed: $e');
      return IcsImportResult(success: false, error: e.toString());
    }
  }

  // ---- ICS Generation ----

  static String _buildIcsString(List<CalendarEvent> events) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Chukdoo//Calendar//DE');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');

    for (final event in events) {
      buf.writeln('BEGIN:VEVENT');
      buf.writeln('UID:${event.id}');
      buf.writeln('DTSTAMP:${_formatIcsDateTime(event.updatedAt)}');

      if (event.isAllDay) {
        buf.writeln('DTSTART;VALUE=DATE:${_formatIcsDate(event.startTime)}');
        buf.writeln(
          'DTEND;VALUE=DATE:${_formatIcsDate(event.endTime.add(const Duration(days: 1)))}',
        );
      } else {
        buf.writeln('DTSTART:${_formatIcsDateTime(event.startTime)}');
        buf.writeln('DTEND:${_formatIcsDateTime(event.endTime)}');
      }

      buf.writeln('SUMMARY:${_escapeIcs(event.title)}');

      if (event.description != null && event.description!.isNotEmpty) {
        buf.writeln('DESCRIPTION:${_escapeIcs(event.description!)}');
      }

      if (event.location != null && event.location!.isNotEmpty) {
        buf.writeln('LOCATION:${_escapeIcs(event.location!)}');
      }

      if (event.recurrenceRule != null && event.recurrenceRule!.isNotEmpty) {
        buf.writeln('RRULE:${event.recurrenceRule}');
      }

      if (event.recurrenceId != null && event.originalStartTime != null) {
        final origDt = DateTime.tryParse(event.originalStartTime!);
        if (origDt != null) {
          buf.writeln('RECURRENCE-ID:${_formatIcsDateTime(origDt)}');
        }
      }

      for (final minutes in event.reminderMinutes) {
        buf.writeln('BEGIN:VALARM');
        buf.writeln('ACTION:DISPLAY');
        buf.writeln('DESCRIPTION:Reminder');
        if (minutes == 0) {
          buf.writeln('TRIGGER:PT0S');
        } else {
          buf.writeln('TRIGGER:-PT${minutes}M');
        }
        buf.writeln('END:VALARM');
      }

      buf.writeln('CREATED:${_formatIcsDateTime(event.createdAt)}');
      buf.writeln('LAST-MODIFIED:${_formatIcsDateTime(event.updatedAt)}');
      buf.writeln('END:VEVENT');
    }

    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  static String _formatIcsDateTime(DateTime dt) {
    return '${dt.year}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        'T'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  static String _formatIcsDate(DateTime dt) {
    return '${dt.year}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static String _escapeIcs(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  // ---- ICS Parsing ----

  /// Parse an ICS document into events. Used by the file import and by the
  /// subscribed feeds.
  static List<CalendarEvent> parseEvents(String ics, String userId) =>
      _parseIcsString(ics, userId);

  static List<CalendarEvent> _parseIcsString(String ics, String userId) {
    final events = <CalendarEvent>[];
    final lines = _unfoldIcsLines(ics.split(RegExp(r'\r?\n')));

    int i = 0;
    while (i < lines.length) {
      if (lines[i].trim().toUpperCase() == 'BEGIN:VEVENT') {
        i++;
        final props = <String, String>{};
        final alarms = <int>[];

        while (i < lines.length &&
            lines[i].trim().toUpperCase() != 'END:VEVENT') {
          final line = lines[i].trim();

          if (line.toUpperCase() == 'BEGIN:VALARM') {
            // Parse alarm
            i++;
            String? trigger;
            while (i < lines.length &&
                lines[i].trim().toUpperCase() != 'END:VALARM') {
              if (lines[i].trim().toUpperCase().startsWith('TRIGGER')) {
                trigger = lines[i].trim().split(':').skip(1).join(':');
              }
              i++;
            }
            if (trigger != null) {
              alarms.add(_parseTriggerMinutes(trigger));
            }
          } else {
            final colonIdx = line.indexOf(':');
            if (colonIdx > 0) {
              final key = line.substring(0, colonIdx).toUpperCase();
              final value = line.substring(colonIdx + 1);
              props[key] = value;
            }
          }
          i++;
        }

        final event = _propsToEvent(props, alarms, userId);
        if (event != null) {
          events.add(event);
        }
      }
      i++;
    }

    return events;
  }

  /// Unfold lines per RFC 5545 (continuation lines start with space/tab)
  static List<String> _unfoldIcsLines(List<String> rawLines) {
    final result = <String>[];
    for (final line in rawLines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (result.isNotEmpty) {
          result[result.length - 1] += line.substring(1);
        }
      } else {
        result.add(line);
      }
    }
    return result;
  }

  static CalendarEvent? _propsToEvent(
    Map<String, String> props,
    List<int> alarms,
    String userId,
  ) {
    final summary = _unescapeIcs(props['SUMMARY'] ?? '');
    if (summary.isEmpty) return null;

    final now = DateTime.now();
    final uid = props['UID'] ?? _uuid.v4();

    // Parse dates
    DateTime? startTime;
    DateTime? endTime;
    bool isAllDay = false;

    final dtStartKey = props.keys.firstWhere(
      (k) => k.startsWith('DTSTART'),
      orElse: () => '',
    );
    final dtEndKey = props.keys.firstWhere(
      (k) => k.startsWith('DTEND'),
      orElse: () => '',
    );

    if (dtStartKey.contains('VALUE=DATE')) {
      isAllDay = true;
      startTime = _parseIcsDate(props[dtStartKey] ?? '');
      final parsedEnd = _parseIcsDate(props[dtEndKey] ?? '');
      // RFC 5545: DTEND for all-day events is exclusive, subtract 1 day to get inclusive end
      endTime = parsedEnd != null
          ? parsedEnd.subtract(const Duration(days: 1))
          : startTime;
    } else {
      startTime = _parseIcsDateTime(props[dtStartKey] ?? '');
      endTime = _parseIcsDateTime(props[dtEndKey] ?? '');
    }

    if (startTime == null) return null;
    endTime ??= startTime.add(const Duration(hours: 1));

    // Parse other fields
    final description = _unescapeIcs(props['DESCRIPTION'] ?? '');
    final location = _unescapeIcs(props['LOCATION'] ?? '');
    final rrule = props['RRULE'];
    final created = _parseIcsDateTime(props['CREATED'] ?? '') ?? now;
    final lastModified = _parseIcsDateTime(props['LAST-MODIFIED'] ?? '') ?? now;

    // Recurrence exception. RFC 5545 gives an exception the same UID as its
    // series, so it needs its own local id — otherwise importing a series
    // with exceptions overwrites the series itself.
    String? recurrenceId;
    String? originalStartTime;
    var localId = uid;
    final recIdKey = props.keys.firstWhere(
      (k) => k.startsWith('RECURRENCE-ID'),
      orElse: () => '',
    );
    if (recIdKey.isNotEmpty) {
      final origDt = _parseIcsDateTime(props[recIdKey] ?? '');
      if (origDt != null) {
        originalStartTime = origDt.toIso8601String();
        recurrenceId = uid;
        localId = '$uid#${_formatIcsDateTime(origDt)}';
      }
    }

    return CalendarEvent(
      id: localId,
      userId: userId,
      title: summary,
      description: description.isNotEmpty ? description : null,
      location: location.isNotEmpty ? location : null,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      recurrenceRule: rrule,
      recurrenceId: recurrenceId,
      originalStartTime: originalStartTime,
      reminderMinutes: alarms.isNotEmpty ? alarms : const [],
      createdAt: created,
      updatedAt: lastModified,
    );
  }

  static DateTime? _parseIcsDateTime(String value) {
    if (value.isEmpty) return null;
    // Remove TZID parameter if present
    final clean = value.replaceAll('Z', '').replaceAll('z', '');
    try {
      if (clean.length >= 15) {
        // YYYYMMDDTHHMMSS
        final d = clean.replaceAll('T', '');
        return DateTime(
          int.parse(d.substring(0, 4)),
          int.parse(d.substring(4, 6)),
          int.parse(d.substring(6, 8)),
          int.parse(d.substring(8, 10)),
          int.parse(d.substring(10, 12)),
          int.parse(d.substring(12, 14)),
        );
      } else if (clean.length >= 8) {
        return _parseIcsDate(clean);
      }
    } catch (_) {}
    return null;
  }

  static DateTime? _parseIcsDate(String value) {
    if (value.isEmpty) return null;
    final clean = value.replaceAll('-', '');
    try {
      if (clean.length >= 8) {
        return DateTime(
          int.parse(clean.substring(0, 4)),
          int.parse(clean.substring(4, 6)),
          int.parse(clean.substring(6, 8)),
        );
      }
    } catch (_) {}
    return null;
  }

  static int _parseTriggerMinutes(String trigger) {
    // e.g. "-PT15M", "-PT1H", "-P1D", "PT0S"
    final clean = trigger.replaceAll(RegExp(r'[+-]'), '').toUpperCase();

    int minutes = 0;
    final dayMatch = RegExp(r'(\d+)D').firstMatch(clean);
    final hourMatch = RegExp(r'(\d+)H').firstMatch(clean);
    final minMatch = RegExp(r'(\d+)M').firstMatch(clean);
    final secMatch = RegExp(r'(\d+)S').firstMatch(clean);

    if (dayMatch != null) minutes += int.parse(dayMatch.group(1)!) * 1440;
    if (hourMatch != null) minutes += int.parse(hourMatch.group(1)!) * 60;
    if (minMatch != null) minutes += int.parse(minMatch.group(1)!);
    if (secMatch != null && minutes == 0) minutes = 0; // PT0S = at event time

    return minutes;
  }

  static String _unescapeIcs(String text) {
    return text
        .replaceAll('\\n', '\n')
        .replaceAll('\\N', '\n')
        .replaceAll('\\;', ';')
        .replaceAll('\\,', ',')
        .replaceAll('\\\\', '\\');
  }
}

class IcsExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int eventCount;
  final String? icsContent;

  const IcsExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.eventCount = 0,
    this.icsContent,
  });
}

class IcsImportResult {
  final bool success;
  final String? error;
  final int added;
  final int updated;

  const IcsImportResult({
    required this.success,
    this.error,
    this.added = 0,
    this.updated = 0,
  });
}
