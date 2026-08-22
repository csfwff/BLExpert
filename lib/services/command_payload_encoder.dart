import 'dart:convert';

import '../models/command_definition.dart';
import '../models/protocol_profile.dart';

/// Expands a command's `{{parameter}}` placeholders into its business payload.
class CommandPayloadEncoder {
  static final RegExp _placeholder = RegExp(
    r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}',
  );

  static List<int> encode(
    CommandDefinition command,
    Map<String, String> suppliedValues,
  ) {
    if (command.format == CommandPayloadFormat.text) {
      if (command.parameters.isNotEmpty) {
        throw const FormatException(
          'Text commands do not support byte placeholders.',
        );
      }
      return utf8.encode(command.payload);
    }
    final Map<String, CommandParameter> parameters = <String, CommandParameter>{
      for (final CommandParameter parameter in command.parameters)
        parameter.key: parameter,
    };
    final Map<String, String> resolvedValues = resolveValues(
      command,
      suppliedValues,
    );
    final StringBuffer expanded = StringBuffer();
    int position = 0;
    for (final RegExpMatch match in _placeholder.allMatches(command.payload)) {
      expanded.write(command.payload.substring(position, match.start));
      final String key = match.group(1)!;
      final CommandParameter? parameter = parameters[key];
      if (parameter == null) {
        throw FormatException('Unknown parameter: $key');
      }
      final String value = resolvedValues[key] ?? parameter.defaultValue;
      expanded.write(
        _toHex(_encodeParameter(parameter, value, currentTime: DateTime.now())),
      );
      position = match.end;
    }
    expanded.write(command.payload.substring(position));
    return _parseHex(expanded.toString());
  }

  /// Resolves omitted parameter values before a command is encoded or logged.
  static Map<String, String> resolveValues(
    CommandDefinition command,
    Map<String, String> suppliedValues, {
    DateTime? currentTime,
  }) {
    final DateTime now = currentTime ?? DateTime.now();
    return <String, String>{
      for (final CommandParameter parameter in command.parameters)
        parameter.key: _resolveValue(
          parameter,
          suppliedValues[parameter.key] ?? parameter.defaultValue,
          now,
        ),
    };
  }

  static String _resolveValue(
    CommandParameter parameter,
    String value,
    DateTime currentTime,
  ) {
    if (value.trim().isNotEmpty) return value;
    return switch (parameter.type) {
      CommandParameterType.currentYear => (currentTime.year % 100).toString(),
      CommandParameterType.currentMonth => currentTime.month.toString(),
      CommandParameterType.currentDay => currentTime.day.toString(),
      CommandParameterType.currentHour => currentTime.hour.toString(),
      CommandParameterType.currentMinute => currentTime.minute.toString(),
      CommandParameterType.currentSecond => currentTime.second.toString(),
      _ => value,
    };
  }

  static List<int> _encodeParameter(
    CommandParameter parameter,
    String value, {
    required DateTime currentTime,
  }) {
    final bool isArray =
        parameter.isArray || parameter.type == CommandParameterType.uint8Array;
    if (isArray) {
      final CommandParameter scalarParameter = parameter.copyWith(
        type: parameter.type == CommandParameterType.uint8Array
            ? CommandParameterType.uint8
            : parameter.type,
        isArray: false,
      );
      return _encodeArray(scalarParameter, value, currentTime: currentTime);
    }
    return _encodeScalar(parameter, value, currentTime: currentTime);
  }

  static List<int> _encodeArray(
    CommandParameter parameter,
    String value, {
    required DateTime currentTime,
  }) {
    final String normalized = value
        .trim()
        .replaceFirst(RegExp(r'^[\[\(]'), '')
        .replaceFirst(RegExp(r'[\]\)]$'), '')
        .trim();
    if (normalized.isEmpty) {
      throw FormatException(
        '${parameter.label.isEmpty ? parameter.key : parameter.label} must contain at least one value.',
      );
    }
    final List<String> values = normalized
        .split(RegExp(r'[,;\s]+'))
        .where((String item) => item.trim().isNotEmpty)
        .toList(growable: false);
    return <int>[
      for (final String item in values)
        ..._encodeScalar(parameter, item, currentTime: currentTime),
    ];
  }

  static List<int> _encodeScalar(
    CommandParameter parameter,
    String value, {
    required DateTime currentTime,
  }) {
    switch (parameter.type) {
      case CommandParameterType.hex:
        return _parseHex(value);
      case CommandParameterType.ascii:
        return ascii.encode(value);
      case CommandParameterType.utf8:
        return utf8.encode(value);
      case CommandParameterType.boolean:
        return <int>[value.toLowerCase() == 'true' || value == '1' ? 1 : 0];
      case CommandParameterType.currentYear:
        return _encodeCurrentTimeValue(
          parameter,
          value,
          currentTime.year % 100,
        );
      case CommandParameterType.currentMonth:
        return _encodeCurrentTimeValue(parameter, value, currentTime.month);
      case CommandParameterType.currentDay:
        return _encodeCurrentTimeValue(parameter, value, currentTime.day);
      case CommandParameterType.currentHour:
        return _encodeCurrentTimeValue(parameter, value, currentTime.hour);
      case CommandParameterType.currentMinute:
        return _encodeCurrentTimeValue(parameter, value, currentTime.minute);
      case CommandParameterType.currentSecond:
        return _encodeCurrentTimeValue(parameter, value, currentTime.second);
      case CommandParameterType.enumValue:
        return _encodeInteger(
          _parseInteger(value),
          1,
          false,
          ProtocolByteOrder.bigEndian,
        );
      case CommandParameterType.uint8:
        return _encodeNumber(parameter, value, 1, false);
      case CommandParameterType.int8:
        return _encodeNumber(parameter, value, 1, true);
      case CommandParameterType.uint16:
        return _encodeNumber(parameter, value, 2, false);
      case CommandParameterType.int16:
        return _encodeNumber(parameter, value, 2, true);
      case CommandParameterType.uint32:
        return _encodeNumber(parameter, value, 4, false);
      case CommandParameterType.int32:
        return _encodeNumber(parameter, value, 4, true);
      case CommandParameterType.uint8Array:
        return _encodeArray(
          parameter.copyWith(type: CommandParameterType.uint8, isArray: false),
          value,
          currentTime: currentTime,
        );
    }
  }

  static List<int> _encodeCurrentTimeValue(
    CommandParameter parameter,
    String value,
    int currentValue,
  ) {
    if (value.trim().isEmpty) return <int>[currentValue];
    return _encodeNumber(parameter, value, 1, false);
  }

  static List<int> _encodeNumber(
    CommandParameter parameter,
    String value,
    int length,
    bool signed,
  ) {
    final int number = _parseInteger(value);
    final int lower = parameter.min ?? (signed ? -(1 << (length * 8 - 1)) : 0);
    final int upper =
        parameter.max ??
        (signed ? (1 << (length * 8 - 1)) - 1 : (1 << (length * 8)) - 1);
    if (number < lower || number > upper) {
      throw FormatException(
        '${parameter.label.isEmpty ? parameter.key : parameter.label} must be between $lower and $upper.',
      );
    }
    return _encodeInteger(number, length, signed, ProtocolByteOrder.bigEndian);
  }

  static List<int> _encodeInteger(
    int value,
    int length,
    bool signed,
    ProtocolByteOrder byteOrder,
  ) {
    final int bits = length * 8;
    int normalized = signed && value < 0 ? (1 << bits) + value : value;
    final List<int> bytes = <int>[
      for (int i = 0; i < length; i++)
        (normalized >> ((length - i - 1) * 8)) & 0xFF,
    ];
    return byteOrder == ProtocolByteOrder.littleEndian
        ? bytes.reversed.toList(growable: false)
        : bytes;
  }

  static int _parseInteger(String value) {
    final String text = value.trim();
    if (text.toLowerCase().startsWith('0x')) {
      return int.parse(text.substring(2), radix: 16);
    }
    return int.parse(text);
  }

  static List<int> _parseHex(String value) {
    final String compact = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (compact.isEmpty || compact.length.isOdd) {
      throw const FormatException('Invalid HEX payload.');
    }
    return <int>[
      for (int i = 0; i < compact.length; i += 2)
        int.parse(compact.substring(i, i + 2), radix: 16),
    ];
  }

  static String _toHex(List<int> bytes) => bytes
      .map((int value) => value.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}
