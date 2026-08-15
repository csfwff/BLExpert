import 'dart:convert';

import '../models/data_mapping.dart';
import '../models/protocol_profile.dart';

class ParsedDataValue {
  const ParsedDataValue({
    required this.key,
    required this.label,
    required this.value,
    required this.displayValue,
    required this.unit,
  });

  final String key;
  final String label;
  final Object value;
  final String displayValue;
  final String unit;
}

class ParsedResponse {
  const ParsedResponse({
    required this.mapping,
    required this.commandHex,
    required this.dataHex,
    required this.values,
    required this.timestamp,
  });

  final ResponseMapping mapping;
  final String commandHex;
  final String dataHex;
  final List<ParsedDataValue> values;
  final DateTime timestamp;
}

/// Converts decoded DATA bytes to strongly described values without touching
/// Bluetooth or protocol framing concerns.
class DataMapper {
  static ParsedResponse? tryParse({
    required Iterable<ResponseMapping> mappings,
    required String commandHex,
    required String dataHex,
    DateTime? timestamp,
  }) {
    final String command = _compactHex(commandHex);
    final ResponseMapping? mapping = mappings
        .cast<ResponseMapping?>()
        .firstWhere(
          (ResponseMapping? item) => _compactHex(item!.commandHex) == command,
          orElse: () => null,
        );
    if (mapping == null) return null;
    final List<int> data = _parseHex(dataHex);
    return ParsedResponse(
      mapping: mapping,
      commandHex: command.toUpperCase(),
      dataHex: _toHex(data),
      timestamp: timestamp ?? DateTime.now(),
      values: mapping.fields
          .map((DataField field) => _parseField(field, data))
          .toList(growable: false),
    );
  }

  static ParsedDataValue _parseField(DataField field, List<int> data) {
    if (field.offset < 0 ||
        field.byteLength < 1 ||
        field.offset + field.byteLength > data.length) {
      return ParsedDataValue(
        key: field.key,
        label: field.label,
        value: '',
        displayValue: 'Out of range',
        unit: field.unit,
      );
    }
    final List<int> bytes = data.sublist(
      field.offset,
      field.offset + field.byteLength,
    );
    final String hex = _toHex(bytes);
    Object value;
    switch (field.type) {
      case DataFieldType.hex:
        value = hex;
      case DataFieldType.ascii:
        value = ascii.decode(bytes, allowInvalid: true);
      case DataFieldType.utf8:
        value = utf8.decode(bytes, allowMalformed: true);
      case DataFieldType.boolean:
        value = _unsigned(bytes, field.byteOrder) != 0;
      case DataFieldType.bit:
        value =
            ((_unsigned(bytes, field.byteOrder) >> (field.bit ?? 0)) & 1) == 1;
      case DataFieldType.enumValue:
        final int raw = _unsigned(bytes, field.byteOrder);
        value = field.enumValues[raw.toString()] ?? raw;
      case DataFieldType.uint8:
      case DataFieldType.uint16:
      case DataFieldType.uint32:
        value = _scaled(_unsigned(bytes, field.byteOrder), field);
      case DataFieldType.int8:
      case DataFieldType.int16:
      case DataFieldType.int32:
        value = _scaled(_signed(bytes, field.byteOrder), field);
    }
    return ParsedDataValue(
      key: field.key,
      label: field.label.isEmpty ? field.key : field.label,
      value: value,
      displayValue: value is num ? _formatNumber(value) : value.toString(),
      unit: field.unit,
    );
  }

  static String _formatNumber(num value) {
    if (value is int || value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static num _scaled(int value, DataField field) =>
      value * field.scale + field.offsetValue;
  static int _unsigned(List<int> bytes, ProtocolByteOrder order) {
    final Iterable<int> source = order == ProtocolByteOrder.littleEndian
        ? bytes.reversed
        : bytes;
    return source.fold<int>(0, (int value, int byte) => (value << 8) | byte);
  }

  static int _signed(List<int> bytes, ProtocolByteOrder order) {
    final int value = _unsigned(bytes, order);
    final int bits = bytes.length * 8;
    return value & (1 << (bits - 1)) == 0 ? value : value - (1 << bits);
  }

  static List<int> _parseHex(String value) {
    final String compact = _compactHex(value);
    if (compact.isEmpty || compact.length.isOdd) return const <int>[];
    return <int>[
      for (int i = 0; i < compact.length; i += 2)
        int.parse(compact.substring(i, i + 2), radix: 16),
    ];
  }

  static String _compactHex(String value) =>
      value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();
  static String _toHex(List<int> bytes) => bytes
      .map((int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
