import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/models/protocol_profile.dart';
import 'package:blexpert/services/packet_encoder.dart';

ProtocolSegment _segment(
  ProtocolSegmentType type, {
  String fixedHex = '',
  int? byteLength,
  ProtocolByteOrder? byteOrder,
  ProtocolChecksumAlgorithm? algorithm,
  ProtocolCalculationRange? range,
}) => ProtocolSegment(
  id: type.name,
  type: type,
  label: type.name,
  byteLength: byteLength,
  byteOrder: byteOrder,
  fixedHex: fixedHex,
  checksumAlgorithm: algorithm,
  calculationRange: range,
);

void main() {
  test('encodes header, payload length, sequence, CRC and footer', () {
    final PacketEncoder encoder = PacketEncoder();
    final ProtocolDefinition protocol = ProtocolDefinition(
      name: 'test',
      description: '',
      sendSegments: <ProtocolSegment>[
        _segment(ProtocolSegmentType.fixedHex, fixedHex: 'AA 55'),
        _segment(
          ProtocolSegmentType.length,
          byteLength: 1,
          byteOrder: ProtocolByteOrder.bigEndian,
          range: ProtocolCalculationRange.payloadOnly,
        ),
        _segment(
          ProtocolSegmentType.sequence,
          byteLength: 1,
          byteOrder: ProtocolByteOrder.bigEndian,
        ),
        _segment(ProtocolSegmentType.payload),
        _segment(
          ProtocolSegmentType.checksum,
          byteOrder: ProtocolByteOrder.bigEndian,
          algorithm: ProtocolChecksumAlgorithm.crc8,
          range: ProtocolCalculationRange.frameExcludingSelf,
        ),
        _segment(ProtocolSegmentType.fixedHex, fixedHex: '0D'),
      ],
      receiveSegments: const <ProtocolSegment>[],
    );

    expect(encoder.encode(protocol, <int>[1, 2, 3]).frame, <int>[
      0xAA,
      0x55,
      3,
      0,
      1,
      2,
      3,
      0xF4,
      0x0D,
    ]);
    expect(encoder.encode(protocol, <int>[9]).frame, <int>[
      0xAA,
      0x55,
      1,
      1,
      9,
      0x3E,
      0x0D,
    ]);
  });

  test('rejects unsupported or incomplete standard protocol', () {
    final PacketEncoder encoder = PacketEncoder();
    final ProtocolDefinition protocol = ProtocolDefinition(
      name: '',
      description: '',
      sendSegments: <ProtocolSegment>[
        _segment(ProtocolSegmentType.fixedHex, fixedHex: 'GG'),
        _segment(ProtocolSegmentType.payload),
      ],
      receiveSegments: const <ProtocolSegment>[],
    );
    expect(() => encoder.encode(protocol, <int>[1]), throwsFormatException);
  });

  test('parseHex accepts separators and rejects odd values', () {
    expect(PacketEncoder.parseHex('AA:55-01'), <int>[0xAA, 0x55, 1]);
    expect(() => PacketEncoder.parseHex('ABC'), throwsFormatException);
  });

  test('sequence wraps at the configured field width', () {
    final PacketEncoder encoder = PacketEncoder()..resetSequence(255);
    final ProtocolDefinition protocol = ProtocolDefinition(
      name: '',
      description: '',
      sendSegments: <ProtocolSegment>[
        _segment(
          ProtocolSegmentType.sequence,
          byteLength: 1,
          byteOrder: ProtocolByteOrder.bigEndian,
        ),
        _segment(ProtocolSegmentType.payload),
      ],
      receiveSegments: const <ProtocolSegment>[],
    );

    expect(encoder.encode(protocol, <int>[1]).frame, <int>[255, 1]);
    expect(encoder.encode(protocol, <int>[1]).frame, <int>[0, 1]);
  });
}
