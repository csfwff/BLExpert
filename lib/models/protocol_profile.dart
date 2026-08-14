enum ProtocolByteOrder { littleEndian, bigEndian }

enum ProtocolChecksumAlgorithm {
  xor,
  sum8,
  crc8,
  crc16Modbus,
  crc16Ccitt,
  crc32,
}

enum ProtocolCalculationRange { payloadOnly, frameExcludingSelf }

enum ProtocolSegmentType {
  fixedHex,
  payload,
  length,
  sequence,
  checksum,
}

class ProtocolSegment {
  const ProtocolSegment({
    required this.id,
    required this.type,
    required this.label,
    required this.byteLength,
    required this.byteOrder,
    required this.fixedHex,
    required this.checksumAlgorithm,
    required this.calculationRange,
  });

  final String id;
  final ProtocolSegmentType type;
  final String label;
  final int? byteLength;
  final ProtocolByteOrder? byteOrder;
  final String fixedHex;
  final ProtocolChecksumAlgorithm? checksumAlgorithm;
  final ProtocolCalculationRange? calculationRange;

  factory ProtocolSegment.fromJson(Map<String, dynamic> json) {
    return ProtocolSegment(
      id: json['id'] as String? ?? '',
      type: _segmentTypeFromJson(json['type']),
      label: json['label'] as String? ?? '',
      byteLength: json['byteLength'] as int?,
      byteOrder: json['byteOrder'] == null
          ? null
          : _byteOrderFromJson(json['byteOrder']),
      fixedHex: json['fixedHex'] as String? ?? '',
      checksumAlgorithm: json['checksumAlgorithm'] == null
          ? null
          : _checksumFromJson(json['checksumAlgorithm']),
      calculationRange: json['calculationRange'] == null
          ? null
          : _calculationRangeFromJson(json['calculationRange']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.name,
    'label': label,
    if (byteLength != null) 'byteLength': byteLength,
    if (byteOrder != null) 'byteOrder': byteOrder!.name,
    if (fixedHex.isNotEmpty) 'fixedHex': fixedHex,
    if (checksumAlgorithm != null) 'checksumAlgorithm': checksumAlgorithm!.name,
    if (calculationRange != null) 'calculationRange': calculationRange!.name,
  };

  ProtocolSegment copyWith({
    String? id,
    ProtocolSegmentType? type,
    String? label,
    int? byteLength,
    bool clearByteLength = false,
    ProtocolByteOrder? byteOrder,
    bool clearByteOrder = false,
    String? fixedHex,
    ProtocolChecksumAlgorithm? checksumAlgorithm,
    bool clearChecksumAlgorithm = false,
    ProtocolCalculationRange? calculationRange,
    bool clearCalculationRange = false,
  }) {
    return ProtocolSegment(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      byteLength: clearByteLength ? null : (byteLength ?? this.byteLength),
      byteOrder: clearByteOrder ? null : (byteOrder ?? this.byteOrder),
      fixedHex: fixedHex ?? this.fixedHex,
      checksumAlgorithm: clearChecksumAlgorithm
          ? null
          : (checksumAlgorithm ?? this.checksumAlgorithm),
      calculationRange: clearCalculationRange
          ? null
          : (calculationRange ?? this.calculationRange),
    );
  }
}

class ProtocolDefinition {
  const ProtocolDefinition({
    required this.name,
    required this.description,
    required this.sendSegments,
    required this.receiveSegments,
  });

  final String name;
  final String description;
  final List<ProtocolSegment> sendSegments;
  final List<ProtocolSegment> receiveSegments;

  factory ProtocolDefinition.empty() => const ProtocolDefinition(
    name: '',
    description: '',
    sendSegments: <ProtocolSegment>[],
    receiveSegments: <ProtocolSegment>[],
  );

  factory ProtocolDefinition.fromJson(Map<String, dynamic> json) {
    if (json['sendSegments'] case final List<dynamic> sendList) {
      return ProtocolDefinition(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        sendSegments: sendList
            .whereType<Map>()
            .map((Map item) => ProtocolSegment.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        receiveSegments: (json['receiveSegments'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((Map item) => ProtocolSegment.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
    }

    final ProtocolProfile legacy = ProtocolProfile.fromJson(json);
    return ProtocolDefinition(
      name: legacy.name,
      description: legacy.description,
      sendSegments: _legacyFrameToSegments(legacy.sendFrame),
      receiveSegments: _legacyFrameToSegments(legacy.receiveFrame),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'description': description,
    'sendSegments': sendSegments
        .map((ProtocolSegment item) => item.toJson())
        .toList(growable: false),
    'receiveSegments': receiveSegments
        .map((ProtocolSegment item) => item.toJson())
        .toList(growable: false),
  };

  ProtocolDefinition copyWith({
    String? name,
    String? description,
    List<ProtocolSegment>? sendSegments,
    List<ProtocolSegment>? receiveSegments,
  }) {
    return ProtocolDefinition(
      name: name ?? this.name,
      description: description ?? this.description,
      sendSegments: sendSegments ?? this.sendSegments,
      receiveSegments: receiveSegments ?? this.receiveSegments,
    );
  }
}

class ProtocolLengthField {
  const ProtocolLengthField({
    required this.offset,
    required this.byteLength,
    required this.byteOrder,
    required this.calculationRange,
  });

  final int offset;
  final int byteLength;
  final ProtocolByteOrder byteOrder;
  final ProtocolCalculationRange calculationRange;

  factory ProtocolLengthField.fromJson(Map<String, dynamic> json) {
    return ProtocolLengthField(
      offset: json['offset'] as int? ?? 0,
      byteLength: json['byteLength'] as int? ?? 1,
      byteOrder: _byteOrderFromJson(json['byteOrder']),
      calculationRange: _calculationRangeFromJson(json['calculationRange']),
    );
  }
}

class ProtocolSequenceField {
  const ProtocolSequenceField({
    required this.offset,
    required this.byteLength,
    required this.byteOrder,
  });

  final int offset;
  final int byteLength;
  final ProtocolByteOrder byteOrder;

  factory ProtocolSequenceField.fromJson(Map<String, dynamic> json) {
    return ProtocolSequenceField(
      offset: json['offset'] as int? ?? 0,
      byteLength: json['byteLength'] as int? ?? 1,
      byteOrder: _byteOrderFromJson(json['byteOrder']),
    );
  }
}

class ProtocolChecksumField {
  const ProtocolChecksumField({
    required this.offset,
    required this.algorithm,
    required this.byteOrder,
    required this.calculationRange,
  });

  final int offset;
  final ProtocolChecksumAlgorithm algorithm;
  final ProtocolByteOrder byteOrder;
  final ProtocolCalculationRange calculationRange;

  factory ProtocolChecksumField.fromJson(Map<String, dynamic> json) {
    return ProtocolChecksumField(
      offset: json['offset'] as int? ?? 0,
      algorithm: _checksumFromJson(json['algorithm']),
      byteOrder: _byteOrderFromJson(json['byteOrder']),
      calculationRange: _calculationRangeFromJson(json['calculationRange']),
    );
  }
}

class ProtocolFrameDefinition {
  const ProtocolFrameDefinition({
    required this.headerHex,
    required this.footerHex,
    required this.lengthField,
    required this.sequenceField,
    required this.checksumField,
  });

  final String headerHex;
  final String footerHex;
  final ProtocolLengthField? lengthField;
  final ProtocolSequenceField? sequenceField;
  final ProtocolChecksumField? checksumField;

  factory ProtocolFrameDefinition.empty() => const ProtocolFrameDefinition(
    headerHex: '',
    footerHex: '',
    lengthField: null,
    sequenceField: null,
    checksumField: null,
  );

  factory ProtocolFrameDefinition.fromJson(Map<String, dynamic> json) {
    return ProtocolFrameDefinition(
      headerHex: json['headerHex'] as String? ?? '',
      footerHex: json['footerHex'] as String? ?? '',
      lengthField: _nullableMap(json['lengthField'])?.let(ProtocolLengthField.fromJson),
      sequenceField: _nullableMap(json['sequenceField'])?.let(ProtocolSequenceField.fromJson),
      checksumField: _nullableMap(json['checksumField'])?.let(ProtocolChecksumField.fromJson),
    );
  }
}

class ProtocolProfile {
  const ProtocolProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.sendFrame,
    required this.receiveFrame,
  });

  final String id;
  final String name;
  final String description;
  final ProtocolFrameDefinition sendFrame;
  final ProtocolFrameDefinition receiveFrame;

  factory ProtocolProfile.fromJson(Map<String, dynamic> json) {
    return ProtocolProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sendFrame: ProtocolFrameDefinition.fromJson(
        Map<String, dynamic>.from(json['sendFrame'] as Map? ?? const <String, dynamic>{}),
      ),
      receiveFrame: ProtocolFrameDefinition.fromJson(
        Map<String, dynamic>.from(json['receiveFrame'] as Map? ?? const <String, dynamic>{}),
      ),
    );
  }
}

List<ProtocolSegment> _legacyFrameToSegments(ProtocolFrameDefinition frame) {
  final List<ProtocolSegment> segments = <ProtocolSegment>[];
  if (frame.headerHex.trim().isNotEmpty) {
    segments.add(
      ProtocolSegment(
        id: 'segment-header-${segments.length}',
        type: ProtocolSegmentType.fixedHex,
        label: 'Header',
        byteLength: null,
        byteOrder: null,
        fixedHex: frame.headerHex,
        checksumAlgorithm: null,
        calculationRange: null,
      ),
    );
  }
  if (frame.lengthField case final ProtocolLengthField field) {
    segments.add(
      ProtocolSegment(
        id: 'segment-length-${segments.length}',
        type: ProtocolSegmentType.length,
        label: 'Length',
        byteLength: field.byteLength,
        byteOrder: field.byteOrder,
        fixedHex: '',
        checksumAlgorithm: null,
        calculationRange: field.calculationRange,
      ),
    );
  }
  if (frame.sequenceField case final ProtocolSequenceField field) {
    segments.add(
      ProtocolSegment(
        id: 'segment-sequence-${segments.length}',
        type: ProtocolSegmentType.sequence,
        label: 'Sequence',
        byteLength: field.byteLength,
        byteOrder: field.byteOrder,
        fixedHex: '',
        checksumAlgorithm: null,
        calculationRange: null,
      ),
    );
  }
  segments.add(
    ProtocolSegment(
      id: 'segment-payload-${segments.length}',
      type: ProtocolSegmentType.payload,
      label: 'Payload',
      byteLength: null,
      byteOrder: null,
      fixedHex: '',
      checksumAlgorithm: null,
      calculationRange: null,
    ),
  );
  if (frame.checksumField case final ProtocolChecksumField field) {
    segments.add(
      ProtocolSegment(
        id: 'segment-checksum-${segments.length}',
        type: ProtocolSegmentType.checksum,
        label: 'Checksum',
        byteLength: null,
        byteOrder: field.byteOrder,
        fixedHex: '',
        checksumAlgorithm: field.algorithm,
        calculationRange: field.calculationRange,
      ),
    );
  }
  if (frame.footerHex.trim().isNotEmpty) {
    segments.add(
      ProtocolSegment(
        id: 'segment-footer-${segments.length}',
        type: ProtocolSegmentType.fixedHex,
        label: 'Footer',
        byteLength: null,
        byteOrder: null,
        fixedHex: frame.footerHex,
        checksumAlgorithm: null,
        calculationRange: null,
      ),
    );
  }
  return List<ProtocolSegment>.unmodifiable(segments);
}

Map<String, dynamic>? _nullableMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

extension<T> on T? {
  R? let<R>(R Function(T value) transform) {
    final T? value = this;
    return value == null ? null : transform(value);
  }
}

ProtocolByteOrder _byteOrderFromJson(dynamic value) {
  return value == ProtocolByteOrder.bigEndian.name
      ? ProtocolByteOrder.bigEndian
      : ProtocolByteOrder.littleEndian;
}

ProtocolCalculationRange _calculationRangeFromJson(dynamic value) {
  return value == ProtocolCalculationRange.frameExcludingSelf.name
      ? ProtocolCalculationRange.frameExcludingSelf
      : ProtocolCalculationRange.payloadOnly;
}

ProtocolChecksumAlgorithm _checksumFromJson(dynamic value) {
  return ProtocolChecksumAlgorithm.values.firstWhere(
    (ProtocolChecksumAlgorithm algorithm) => algorithm.name == value,
    orElse: () => ProtocolChecksumAlgorithm.crc16Modbus,
  );
}

ProtocolSegmentType _segmentTypeFromJson(dynamic value) {
  return ProtocolSegmentType.values.firstWhere(
    (ProtocolSegmentType type) => type.name == value,
    orElse: () => ProtocolSegmentType.fixedHex,
  );
}
