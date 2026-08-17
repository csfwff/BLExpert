enum SessionLogKind { sent, received, system, error }

/// A serializable record of one BLE or application event in the current session.
class SessionLogRecord {
  const SessionLogRecord({
    required this.kind,
    required this.timestamp,
    this.data = const <int>[],
    this.message,
    this.characteristicId,
    this.commandName,
    this.bookmarked = false,
  });

  const SessionLogRecord.system({
    required DateTime timestamp,
    required String message,
    String? characteristicId,
    String? commandName,
  }) : this(
         kind: SessionLogKind.system,
         timestamp: timestamp,
         message: message,
         characteristicId: characteristicId,
         commandName: commandName,
       );

  const SessionLogRecord.error({
    required DateTime timestamp,
    required String message,
    String? characteristicId,
    String? commandName,
  }) : this(
         kind: SessionLogKind.error,
         timestamp: timestamp,
         message: message,
         characteristicId: characteristicId,
         commandName: commandName,
       );

  final SessionLogKind kind;
  final DateTime timestamp;
  final List<int> data;
  final String? message;
  final String? characteristicId;
  final String? commandName;
  final bool bookmarked;

  SessionLogRecord copyWith({bool? bookmarked}) => SessionLogRecord(
    kind: kind,
    timestamp: timestamp,
    data: data,
    message: message,
    characteristicId: characteristicId,
    commandName: commandName,
    bookmarked: bookmarked ?? this.bookmarked,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (data.isNotEmpty) 'data': data,
    if (message != null && message!.isNotEmpty) 'message': message,
    if (characteristicId != null && characteristicId!.isNotEmpty)
      'characteristicId': characteristicId,
    if (commandName != null && commandName!.isNotEmpty)
      'commandName': commandName,
    if (bookmarked) 'bookmarked': true,
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
    final Object? rawCharacteristicId = json['characteristicId'];
    if (rawCharacteristicId != null && rawCharacteristicId is! String) {
      return null;
    }
    final Object? rawCommandName = json['commandName'];
    if (rawCommandName != null && rawCommandName is! String) return null;
    final Object? rawBookmarked = json['bookmarked'];
    if (rawBookmarked != null && rawBookmarked is! bool) return null;
    return SessionLogRecord(
      kind: kind,
      timestamp: timestamp.toLocal(),
      data: data,
      message: rawMessage as String?,
      characteristicId: rawCharacteristicId as String?,
      commandName: rawCommandName as String?,
      bookmarked: rawBookmarked as bool? ?? false,
    );
  }
}
