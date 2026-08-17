import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_log_record.dart';

/// Stores a deliberately small, recent subset of session records locally.
class SessionLogStore {
  SessionLogStore([this._preferences]);

  static const int maxRecords = 300;
  static const int maxDataBytes = 512;
  static const int maxMessageLength = 1024;
  static const int maxMetadataLength = 128;
  static const String _storageKey = 'blexpert.session-log-store.v1';

  SharedPreferences? _preferences;

  Future<List<SessionLogRecord>> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    final String? jsonText = _preferences!.getString(_storageKey);
    if (jsonText == null || jsonText.trim().isEmpty) {
      return const <SessionLogRecord>[];
    }
    try {
      final Object? decoded = jsonDecode(jsonText);
      if (decoded is! Map) return const <SessionLogRecord>[];
      final Object? rawRecords = decoded['records'];
      if (rawRecords is! List) return const <SessionLogRecord>[];
      return <SessionLogRecord>[
        for (final Object? rawRecord in rawRecords.take(maxRecords))
          if (rawRecord is Map)
            if (SessionLogRecord.tryParse(Map<String, dynamic>.from(rawRecord))
                case final SessionLogRecord record)
              record,
      ];
    } catch (_) {
      return const <SessionLogRecord>[];
    }
  }

  Future<void> save(Iterable<SessionLogRecord> records) async {
    _preferences ??= await SharedPreferences.getInstance();
    final List<SessionLogRecord> bounded = records
        .take(maxRecords)
        .map(_sanitize)
        .toList(growable: false);
    final bool saved = await _preferences!.setString(
      _storageKey,
      jsonEncode(<String, dynamic>{
        'version': 1,
        'records': bounded
            .map((SessionLogRecord item) => item.toJson())
            .toList(),
      }),
    );
    if (!saved) throw StateError('Unable to save session logs.');
  }

  Future<void> clear() async {
    _preferences ??= await SharedPreferences.getInstance();
    final bool cleared = await _preferences!.remove(_storageKey);
    if (!cleared && _preferences!.containsKey(_storageKey)) {
      throw StateError('Unable to clear session logs.');
    }
  }

  static SessionLogRecord _sanitize(SessionLogRecord record) =>
      SessionLogRecord(
        kind: record.kind,
        timestamp: record.timestamp,
        data: record.data.take(maxDataBytes).toList(growable: false),
        message: _truncate(record.message, maxMessageLength),
        characteristicId: _truncate(record.characteristicId, maxMetadataLength),
        commandName: _truncate(record.commandName, maxMetadataLength),
        transactionId: _truncate(record.transactionId, maxMetadataLength),
        bookmarked: record.bookmarked,
      );

  static String? _truncate(String? value, int maxLength) =>
      value == null || value.length <= maxLength
      ? value
      : value.substring(0, maxLength);
}
