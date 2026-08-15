import '../models/protocol_profile.dart';
import 'packet_encoder.dart';

enum PacketDecodeStatus { frame, waiting, invalid, configurationError }

class PacketDecodeEvent {
  const PacketDecodeEvent({
    required this.status,
    this.frame = const <int>[],
    this.payload = const <int>[],
    this.message = '',
  });

  final PacketDecodeStatus status;
  final List<int> frame;
  final List<int> payload;
  final String message;
}

/// Incrementally restores frames from notification chunks.
class PacketDecoder {
  static const int maxFrameBytes = 4 * 1024;
  final Map<String, List<int>> _buffers = <String, List<int>>{};

  void reset([String? source]) {
    if (source == null) {
      _buffers.clear();
    } else {
      _buffers.remove(source);
    }
  }

  List<PacketDecodeEvent> add(
    String source,
    List<int> chunk,
    ProtocolDefinition protocol,
  ) {
    final List<int> buffer = _buffers.putIfAbsent(source, () => <int>[])
      ..addAll(chunk);
    final List<PacketDecodeEvent> events = <PacketDecodeEvent>[];
    while (buffer.isNotEmpty) {
      final _FrameShape shape;
      try {
        shape = _shape(protocol.receiveSegments);
      } on FormatException catch (error) {
        events.add(
          PacketDecodeEvent(
            status: PacketDecodeStatus.configurationError,
            message: error.message,
          ),
        );
        buffer.clear();
        break;
      }
      final int headerOffset = _findHeader(buffer, shape.header);
      if (headerOffset < 0) {
        final int keep = shape.header.length > 1 ? shape.header.length - 1 : 0;
        if (buffer.length > keep) buffer.removeRange(0, buffer.length - keep);
        events.add(const PacketDecodeEvent(status: PacketDecodeStatus.waiting));
        break;
      }
      if (headerOffset > 0) buffer.removeRange(0, headerOffset);
      final int? expectedLength = _expectedLength(buffer, shape);
      if (expectedLength != null && expectedLength > maxFrameBytes) {
        events.add(
          const PacketDecodeEvent(
            status: PacketDecodeStatus.invalid,
            message: 'Declared frame length exceeds the 4096-byte limit.',
          ),
        );
        buffer.removeAt(0);
        continue;
      }
      if (expectedLength == null || buffer.length < expectedLength) {
        if (buffer.length > maxFrameBytes) {
          events.add(
            const PacketDecodeEvent(
              status: PacketDecodeStatus.invalid,
              message: 'Receive buffer exceeds the 4096-byte limit.',
            ),
          );
          buffer.removeAt(0);
          continue;
        }
        events.add(const PacketDecodeEvent(status: PacketDecodeStatus.waiting));
        break;
      }
      final List<int> frame = List<int>.from(buffer.take(expectedLength));
      buffer.removeRange(0, expectedLength);
      final PacketDecodeEvent result = _validate(frame, shape);
      events.add(result);
      if (result.status == PacketDecodeStatus.invalid) {
        if (buffer.isNotEmpty) continue;
      }
    }
    return events;
  }

  static _FrameShape _shape(List<ProtocolSegment> segments) {
    if (segments.isEmpty) {
      throw const FormatException('No receive protocol configured.');
    }
    final int payloadCount = segments
        .where((item) => item.type == ProtocolSegmentType.payload)
        .length;
    if (payloadCount != 1) {
      throw const FormatException(
        'Receive protocol requires exactly one payload segment.',
      );
    }
    if (segments
            .where((item) => item.type == ProtocolSegmentType.length)
            .length >
        1) {
      throw const FormatException(
        'Receive protocol supports at most one length segment.',
      );
    }
    final ProtocolSegment? length = _first(
      segments,
      ProtocolSegmentType.length,
    );
    final ProtocolSegment? payload = _first(
      segments,
      ProtocolSegmentType.payload,
    );
    if (length == null && payload!.byteLength == null) {
      throw const FormatException(
        'Receive protocol requires a length or fixed payload size.',
      );
    }
    if (length != null &&
        (length.byteLength == null ||
            length.byteLength! < 1 ||
            length.byteLength! > 4 ||
            length.byteOrder == null ||
            length.calculationRange == null)) {
      throw const FormatException('Length segment is not fully configured.');
    }
    final List<int> header = segments.first.type == ProtocolSegmentType.fixedHex
        ? PacketEncoder.parseHex(segments.first.fixedHex)
        : const <int>[];
    return _FrameShape(
      segments: segments,
      header: header,
      length: length,
      payload: payload,
    );
  }

  static int _findHeader(List<int> bytes, List<int> header) {
    if (header.isEmpty) return 0;
    for (int i = 0; i <= bytes.length - header.length; i++) {
      bool match = true;
      for (int j = 0; j < header.length; j++) {
        if (bytes[i + j] != header[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static int? _expectedLength(List<int> bytes, _FrameShape shape) {
    final ProtocolSegment? length = shape.length;
    if (length == null) return _staticLength(shape.segments, shape.payload!);
    final int offset = _offsetBefore(shape.segments, length);
    if (bytes.length < offset + length.byteLength!) return null;
    final int value = _readInt(
      bytes.sublist(offset, offset + length.byteLength!),
      length.byteOrder!,
    );
    final int overhead = _staticLength(
      shape.segments,
      shape.payload!,
      includePayload: false,
    );
    return length.calculationRange == ProtocolCalculationRange.payloadOnly
        ? overhead + value
        : value + length.byteLength!;
  }

  static int _staticLength(
    List<ProtocolSegment> segments,
    ProtocolSegment payload, {
    bool includePayload = true,
  }) {
    int total = 0;
    for (final ProtocolSegment segment in segments) {
      if (segment.type == ProtocolSegmentType.payload) {
        if (includePayload && payload.byteLength != null) {
          total += payload.byteLength!;
        }
      } else if (segment.type == ProtocolSegmentType.fixedHex) {
        total += PacketEncoder.parseHex(segment.fixedHex).length;
      } else if (segment.type == ProtocolSegmentType.length ||
          segment.type == ProtocolSegmentType.sequence) {
        total +=
            segment.byteLength ??
            (throw const FormatException('Numeric segment is not configured.'));
      } else if (segment.type == ProtocolSegmentType.checksum) {
        total += segment.checksumAlgorithm == null
            ? (throw const FormatException(
                'Checksum segment is not configured.',
              ))
            : _checksumLength(segment.checksumAlgorithm!);
      }
    }
    return total;
  }

  static PacketDecodeEvent _validate(List<int> frame, _FrameShape shape) {
    int offset = 0;
    final int payloadLength =
        shape.payload!.byteLength ??
        frame.length -
            _staticLength(
              shape.segments,
              shape.payload!,
              includePayload: false,
            );
    final int payloadOffset = shape.segments
        .takeWhile((ProtocolSegment item) => item.id != shape.payload!.id)
        .fold(
          0,
          (int sum, ProtocolSegment item) =>
              sum + _segmentLength(item, payloadLength: payloadLength),
        );
    final List<int> payload = frame.sublist(
      payloadOffset,
      payloadOffset + payloadLength,
    );
    for (final ProtocolSegment segment in shape.segments) {
      final int length = _segmentLength(segment, payloadLength: payloadLength);
      if (offset + length > frame.length) {
        return const PacketDecodeEvent(
          status: PacketDecodeStatus.invalid,
          message: 'Frame is shorter than configured segments.',
        );
      }
      final List<int> part = frame.sublist(offset, offset + length);
      if (segment.type == ProtocolSegmentType.fixedHex &&
          part.join(',') !=
              PacketEncoder.parseHex(segment.fixedHex).join(',')) {
        return const PacketDecodeEvent(
          status: PacketDecodeStatus.invalid,
          message: 'Frame header/footer mismatch.',
        );
      }
      if (segment.type == ProtocolSegmentType.checksum) {
        final List<int> input =
            segment.calculationRange == ProtocolCalculationRange.payloadOnly
            ? payload
            : <int>[
                ...frame.sublist(0, offset),
                ...frame.sublist(offset + length),
              ];
        final int actual = _checksum(segment.checksumAlgorithm!, input);
        final int expected = _readInt(part, segment.byteOrder!);
        if (actual != expected) {
          return const PacketDecodeEvent(
            status: PacketDecodeStatus.invalid,
            message: 'Checksum validation failed.',
          );
        }
      }
      offset += length;
    }
    return PacketDecodeEvent(
      status: PacketDecodeStatus.frame,
      frame: frame,
      payload: payload,
    );
  }

  static int _segmentLength(ProtocolSegment segment, {int payloadLength = 0}) =>
      switch (segment.type) {
        ProtocolSegmentType.fixedHex => PacketEncoder.parseHex(
          segment.fixedHex,
        ).length,
        ProtocolSegmentType.payload => segment.byteLength ?? payloadLength,
        ProtocolSegmentType.length ||
        ProtocolSegmentType.sequence => segment.byteLength ?? 0,
        ProtocolSegmentType.checksum =>
          segment.checksumAlgorithm == null
              ? 0
              : _checksumLength(segment.checksumAlgorithm!),
      };

  static int _offsetBefore(
    List<ProtocolSegment> segments,
    ProtocolSegment target,
  ) => segments
      .takeWhile((item) => item.id != target.id)
      .fold(0, (int sum, ProtocolSegment item) => sum + _segmentLength(item));
  static ProtocolSegment? _first(
    List<ProtocolSegment> list,
    ProtocolSegmentType type,
  ) => list.cast<ProtocolSegment?>().firstWhere(
    (item) => item!.type == type,
    orElse: () => null,
  );
  static int _readInt(List<int> bytes, ProtocolByteOrder order) =>
      (order == ProtocolByteOrder.littleEndian ? bytes.reversed : bytes).fold(
        0,
        (int value, int item) => value << 8 | item,
      );
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
        return bytes.fold(0, (int value, int item) => value ^ item);
      case ProtocolChecksumAlgorithm.sum8:
        return bytes.fold(0, (int value, int item) => (value + item) & 0xFF);
      case ProtocolChecksumAlgorithm.crc8:
        int crc = 0;
        for (final int item in bytes) {
          crc ^= item;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 0x80) != 0
                ? ((crc << 1) ^ 7) & 0xFF
                : (crc << 1) & 0xFF;
          }
        }
        return crc;
      case ProtocolChecksumAlgorithm.crc16Modbus:
        int crc = 0xFFFF;
        for (final int item in bytes) {
          crc ^= item;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1;
          }
        }
        return crc & 0xFFFF;
      case ProtocolChecksumAlgorithm.crc16Ccitt:
        int crc = 0xFFFF;
        for (final int item in bytes) {
          crc ^= item << 8;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 0x8000) != 0
                ? ((crc << 1) ^ 0x1021) & 0xFFFF
                : (crc << 1) & 0xFFFF;
          }
        }
        return crc;
      case ProtocolChecksumAlgorithm.crc32:
        int crc = 0xFFFFFFFF;
        for (final int item in bytes) {
          crc ^= item;
          for (int i = 0; i < 8; i++) {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
          }
        }
        return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
    }
  }
}

class _FrameShape {
  const _FrameShape({
    required this.segments,
    required this.header,
    required this.length,
    required this.payload,
  });
  final List<ProtocolSegment> segments;
  final List<int> header;
  final ProtocolSegment? length;
  final ProtocolSegment? payload;
}
