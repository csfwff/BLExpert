import 'protocol_profile.dart';

enum DataFieldType {
  uint8,
  int8,
  uint16,
  int16,
  uint32,
  int32,
  hex,
  ascii,
  utf8,
  boolean,
  enumValue,
  bit,
}

/// A business response identified by its command byte after protocol decoding.
class ResponseMapping {
  const ResponseMapping({
    required this.id,
    required this.name,
    required this.commandHex,
    required this.fields,
    this.asciiLogEnabled = false,
  });

  final String id;
  final String name;
  final String commandHex;
  final List<DataField> fields;

  /// Emits a printable ASCII view of this response's decoded DATA bytes.
  final bool asciiLogEnabled;

  factory ResponseMapping.fromJson(Map<String, dynamic> json) =>
      ResponseMapping(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        commandHex: json['commandHex'] as String? ?? '',
        asciiLogEnabled: json['asciiLogEnabled'] as bool? ?? false,
        fields: (json['fields'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (Map item) => DataField.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'commandHex': commandHex,
    'asciiLogEnabled': asciiLogEnabled,
    'fields': fields
        .map((DataField item) => item.toJson())
        .toList(growable: false),
  };
}

/// A field offset is always relative to the decoded DATA section, excluding CMD.
class DataField {
  const DataField({
    required this.key,
    required this.label,
    required this.offset,
    required this.byteLength,
    required this.type,
    required this.byteOrder,
    required this.scale,
    required this.offsetValue,
    required this.unit,
    required this.bit,
    required this.enumValues,
    this.visibleInDataPanel = true,
    this.isArray = false,
  });

  final String key;
  final String label;
  final int offset;
  final int byteLength;
  final DataFieldType type;
  final ProtocolByteOrder byteOrder;
  final double scale;
  final double offsetValue;
  final String unit;
  final int? bit;
  final Map<String, String> enumValues;
  final bool visibleInDataPanel;

  /// Expands this field into repeated values at consecutive byte ranges.
  final bool isArray;

  factory DataField.fromJson(Map<String, dynamic> json) => DataField(
    key: json['key'] as String? ?? '',
    label: json['label'] as String? ?? '',
    offset: json['offset'] as int? ?? 0,
    byteLength: json['byteLength'] as int? ?? 1,
    type: _fieldTypeFromJson(json['type']),
    byteOrder: json['byteOrder'] == 'bigEndian'
        ? ProtocolByteOrder.bigEndian
        : ProtocolByteOrder.littleEndian,
    scale: (json['scale'] as num?)?.toDouble() ?? 1,
    offsetValue: (json['offsetValue'] as num?)?.toDouble() ?? 0,
    unit: json['unit'] as String? ?? '',
    bit: json['bit'] as int?,
    enumValues: (json['enumValues'] as Map? ?? const <String, dynamic>{}).map(
      (dynamic key, dynamic value) =>
          MapEntry(key.toString(), value.toString()),
    ),
    visibleInDataPanel: json['visibleInDataPanel'] as bool? ?? true,
    isArray: json['isArray'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
    'offset': offset,
    'byteLength': byteLength,
    'type': type.name,
    'byteOrder': byteOrder.name,
    'scale': scale,
    'offsetValue': offsetValue,
    'unit': unit,
    if (bit != null) 'bit': bit,
    if (enumValues.isNotEmpty) 'enumValues': enumValues,
    'visibleInDataPanel': visibleInDataPanel,
    if (isArray) 'isArray': true,
  };

  DataField copyWith({
    String? key,
    String? label,
    int? offset,
    int? byteLength,
    DataFieldType? type,
    ProtocolByteOrder? byteOrder,
    double? scale,
    double? offsetValue,
    String? unit,
    int? bit,
    bool clearBit = false,
    Map<String, String>? enumValues,
    bool? visibleInDataPanel,
    bool? isArray,
  }) => DataField(
    key: key ?? this.key,
    label: label ?? this.label,
    offset: offset ?? this.offset,
    byteLength: byteLength ?? this.byteLength,
    type: type ?? this.type,
    byteOrder: byteOrder ?? this.byteOrder,
    scale: scale ?? this.scale,
    offsetValue: offsetValue ?? this.offsetValue,
    unit: unit ?? this.unit,
    bit: clearBit ? null : (bit ?? this.bit),
    enumValues: enumValues ?? this.enumValues,
    visibleInDataPanel: visibleInDataPanel ?? this.visibleInDataPanel,
    isArray: isArray ?? this.isArray,
  );
}

DataFieldType _fieldTypeFromJson(Object? value) =>
    DataFieldType.values.firstWhere(
      (DataFieldType item) => item.name == value,
      orElse: () => DataFieldType.uint8,
    );
