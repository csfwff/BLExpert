import '../models/protocol_profile.dart';

/// Builds a complete frame from an ordered standard-protocol segment list.
/// This service is deliberately independent of Flutter and BLE.
class PacketEncoderResult {
  const PacketEncoderResult({required this.payload, required this.frame});

  final List<int> payload;
  final List<int> frame;
}

class PacketEncoder {
  int _sequence = 0;

  void resetSequence([int value = 0]) => _sequence = value & 0xFFFFFFFF;

  PacketEncoderResult encode(ProtocolDefinition protocol, List<int> payload) {
    return _encode(protocol, payload, advanceSequence: true);
  }

  /// Encodes the current payload without consuming the next sequence number.
  /// This is used by UI previews so opening/editing the send editor has no
  /// effect on the actual send sequence.
  PacketEncoderResult preview(ProtocolDefinition protocol, List<int> payload) {
    return _encode(protocol, payload, advanceSequence: false);
  }

  PacketEncoderResult _encode(
    ProtocolDefinition protocol,
    List<int> payload, {
    required bool advanceSequence,
  }) {
    if (protocol.sendSegments.isEmpty) {
      throw const FormatException('Standard protocol has no send segments.');
    }
    final List<ProtocolSegment> segments = protocol.sendSegments;
    if (segments
            .where(
              (ProtocolSegment item) =>
                  item.type == ProtocolSegmentType.payload,
            )
            .length !=
        1) {
      throw const FormatException(
        'Standard protocol requires exactly one payload segment.',
      );
    }
    if (segments
            .where(
              (ProtocolSegment item) =>
                  item.type == ProtocolSegmentType.checksum,
            )
            .length >
        1) {
      throw const FormatException(
        'Standard protocol supports at most one checksum segment.',
      );
    }
    final List<List<int>> parts = <List<int>>[];
    final List<int> payloadBytes = List<int>.from(payload, growable: false);
    int? sequenceValue;
    for (final ProtocolSegment segment in segments) {
      switch (segment.type) {
        case ProtocolSegmentType.fixedHex:
          parts.add(parseHex(segment.fixedHex));
        case ProtocolSegmentType.payload:
          parts.add(payloadBytes);
        case ProtocolSegmentType.length:
          _validateNumericSegment(segment, 'Length');
          parts.add(List<int>.filled(segment.byteLength!, 0));
        case ProtocolSegmentType.sequence:
          _validateNumericSegment(segment, 'Sequence');
          sequenceValue ??= _sequence;
          if (advanceSequence) _sequence++;
          final int sequenceMask = segment.byteLength == 4
              ? 0xFFFFFFFF
              : (1 << (segment.byteLength! * 8)) - 1;
          parts.add(
            _integerBytes(
              sequenceValue & sequenceMask,
              segment.byteLength!,
              segment.byteOrder!,
            ),
          );
        case ProtocolSegmentType.checksum:
          if (segment.checksumAlgorithm == null ||
              segment.byteOrder == null ||
              segment.calculationRange == null) {
            throw const FormatException(
              'Checksum segment is not fully configured.',
            );
          }
          parts.add(
            List<int>.filled(_checksumLength(segment.checksumAlgorithm!), 0),
          );
      }
    }

    final List<int> frame = <int>[for (final List<int> part in parts) ...part];
    int offset = 0;
    for (int index = 0; index < segments.length; index++) {
      final ProtocolSegment segment = segments[index];
      final int length = parts[index].length;
      if (segment.type == ProtocolSegmentType.length) {
        final int value = _range(
          segment.calculationRange!,
          frame,
          segments,
          parts,
          index,
        );
        parts[index] = _integerBytes(
          value,
          segment.byteLength!,
          segment.byteOrder!,
        );
        _replace(frame, offset, parts[index]);
      }
      offset += length;
    }
    offset = 0;
    for (int index = 0; index < segments.length; index++) {
      final ProtocolSegment segment = segments[index];
      if (segment.type == ProtocolSegmentType.checksum) {
        final List<int> input = _rangeBytes(
          segment.calculationRange!,
          frame,
          segments,
          parts,
          index,
        );
        final int value = _checksum(segment.checksumAlgorithm!, input);
        parts[index] = _integerBytes(
          value,
          _checksumLength(segment.checksumAlgorithm!),
          segment.byteOrder!,
        );
        _replace(frame, offset, parts[index]);
      }
      offset += parts[index].length;
    }
    if (advanceSequence) _sequence &= 0xFFFFFFFF;
    return PacketEncoderResult(
      payload: payloadBytes,
      frame: List<int>.unmodifiable(frame),
    );
  }

  static void _validateNumericSegment(ProtocolSegment segment, String name) {
    final int? length = segment.byteLength;
    if (length == null ||
        length < 1 ||
        length > 4 ||
        segment.byteOrder == null ||
        (name == 'Length' && segment.calculationRange == null)) {
      throw FormatException('$name segment is not fully configured.');
    }
  }

  static List<int> parseHex(String value) {
    final String compact = value.replaceAll(RegExp(r'[\s:_-]'), '');
    if (compact.isEmpty ||
        compact.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(compact)) {
      throw const FormatException('Invalid HEX value.');
    }
    return <int>[
      for (int i = 0; i < compact.length; i += 2)
        int.parse(compact.substring(i, i + 2), radix: 16),
    ];
  }

  static List<int> _integerBytes(
    int value,
    int length,
    ProtocolByteOrder order,
  ) {
    final int max = length == 4 ? 0xFFFFFFFF : (1 << (length * 8)) - 1;
    if (value < 0 || value > max) {
      throw FormatException('Value $value does not fit in $length bytes.');
    }
    final List<int> bytes = <int>[
      for (int i = length - 1; i >= 0; i--) (value >> (i * 8)) & 0xFF,
    ];
    return order == ProtocolByteOrder.littleEndian
        ? bytes.reversed.toList(growable: false)
        : bytes;
  }

  static int _range(
    ProtocolCalculationRange range,
    List<int> frame,
    List<ProtocolSegment> segments,
    List<List<int>> parts,
    int self,
  ) => _rangeBytes(range, frame, segments, parts, self).length;

  static List<int> _rangeBytes(
    ProtocolCalculationRange range,
    List<int> frame,
    List<ProtocolSegment> segments,
    List<List<int>> parts,
    int self,
  ) {
    if (range == ProtocolCalculationRange.payloadOnly) {
      return <int>[
        for (int i = 0; i < segments.length; i++)
          if (segments[i].type == ProtocolSegmentType.payload) ...parts[i],
      ];
    }
    final int start = parts
        .take(self)
        .fold(0, (int sum, List<int> part) => sum + part.length);
    final int end = start + parts[self].length;
    return <int>[...frame.sublist(0, start), ...frame.sublist(end)];
  }

  static void _replace(List<int> target, int offset, List<int> value) {
    for (int i = 0; i < value.length; i++) {
      target[offset + i] = value[i];
    }
  }

  static int _checksumLength(ProtocolChecksumAlgorithm algorithm) =>
      switch (algorithm) {
        ProtocolChecksumAlgorithm.xor ||
        ProtocolChecksumAlgorithm.sum8 ||
        ProtocolChecksumAlgorithm.crc8 => 1,
        ProtocolChecksumAlgorithm.crc16Modbus ||
        ProtocolChecksumAlgorithm.crc16Ccitt => 2,
        ProtocolChecksumAlgorithm.crc32 => 4,
      };

  static int _checksum(ProtocolChecksumAlgorithm algorithm, List<int> bytes) {
    switch (algorithm) {
      case ProtocolChecksumAlgorithm.xor:
        return bytes.fold(0, (int value, int byte) => value ^ byte);
      case ProtocolChecksumAlgorithm.sum8:
        return bytes.fold(0, (int value, int byte) => (value + byte) & 0xFF);
      case ProtocolChecksumAlgorithm.crc8:
        int crc = 0;
        for (final int byte in bytes) {
          crc ^= byte;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 0x80) != 0
                ? ((crc << 1) ^ 0x07) & 0xFF
                : (crc << 1) & 0xFF;
          }
        }
        return crc;
      case ProtocolChecksumAlgorithm.crc16Modbus:
        int crc = 0xFFFF;
        for (final int byte in bytes) {
          crc ^= byte;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1;
          }
        }
        return crc & 0xFFFF;
      case ProtocolChecksumAlgorithm.crc16Ccitt:
        int crc = 0xFFFF;
        for (final int byte in bytes) {
          crc ^= byte << 8;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 0x8000) != 0
                ? ((crc << 1) ^ 0x1021) & 0xFFFF
                : (crc << 1) & 0xFFFF;
          }
        }
        return crc;
      case ProtocolChecksumAlgorithm.crc32:
        int crc = 0xFFFFFFFF;
        for (final int byte in bytes) {
          crc ^= byte;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
          }
        }
        return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
    }
  }
}
