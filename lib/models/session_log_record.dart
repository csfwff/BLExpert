enum SessionLogKind { sent, received, system, error }

/// A serializable record of one BLE or application event in the current session.
class SessionLogRecord {
  const SessionLogRecord({
    required this.kind,
    required this.timestamp,
    this.data = const <int>[],
    this.message,
  });

  const SessionLogRecord.system({
    required DateTime timestamp,
    required String message,
  }) : this(
         kind: SessionLogKind.system,
         timestamp: timestamp,
         message: message,
       );

  const SessionLogRecord.error({
    required DateTime timestamp,
    required String message,
  }) : this(kind: SessionLogKind.error, timestamp: timestamp, message: message);

  final SessionLogKind kind;
  final DateTime timestamp;
  final List<int> data;
  final String? message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (data.isNotEmpty) 'data': data,
    if (message != null && message!.isNotEmpty) 'message': message,
  };

  static SessionLogRecord? tryParse(Map<String, dynamic> json) {
    final String? kindName = json['kind'] as String?;
    final SessionLogKind? kind = SessionLogKind.values
        .where((SessionLogKind item) => item.name == kindName)
        .firstOrNull;
    final String? timestampText = json['timestamp'] as String?;
    final DateTime? timestamp = timestampText == null
        ? null
        : DateTime.tryParse(timestampText);
    if (kind == null || timestamp == null) return null;

    final Object? rawData = json['data'];
    if (rawData != null && rawData is! List) return null;
    final List<int> data = rawData == null
        ? const <int>[]
        : <int>[
            for (final Object? value in rawData as List)
              if (value is int && value >= 0 && value <= 255) value,
          ];
    if (rawData is List && data.length != rawData.length) return null;
    final Object? rawMessage = json['message'];
    if (rawMessage != null && rawMessage is! String) return null;
    return SessionLogRecord(
      kind: kind,
      timestamp: timestamp.toLocal(),
      data: data,
      message: rawMessage as String?,
    );
  }
}
