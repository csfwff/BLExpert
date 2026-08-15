import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/models/protocol_profile.dart';
import 'package:blexpert/services/packet_decoder.dart';
import 'package:blexpert/services/packet_encoder.dart';

ProtocolSegment _segment(
  ProtocolSegmentType type, {
  String fixedHex = '',
  int? byteLength,
  ProtocolByteOrder? byteOrder,
  ProtocolChecksumAlgorithm? algorithm,
  ProtocolCalculationRange? range,
}) => ProtocolSegment(
  id: '${type.name}-$fixedHex',
  type: type,
  label: type.name,
  byteLength: byteLength,
  byteOrder: byteOrder,
  fixedHex: fixedHex,
  checksumAlgorithm: algorithm,
  calculationRange: range,
);

void main() {
  final List<ProtocolSegment> segments = <ProtocolSegment>[
    _segment(ProtocolSegmentType.fixedHex, fixedHex: 'AA 55'),
    _segment(
      ProtocolSegmentType.length,
      byteLength: 1,
      byteOrder: ProtocolByteOrder.bigEndian,
      range: ProtocolCalculationRange.payloadOnly,
    ),
    _segment(ProtocolSegmentType.payload),
    _segment(
      ProtocolSegmentType.checksum,
      byteOrder: ProtocolByteOrder.bigEndian,
      algorithm: ProtocolChecksumAlgorithm.crc8,
      range: ProtocolCalculationRange.frameExcludingSelf,
    ),
    _segment(ProtocolSegmentType.fixedHex, fixedHex: '0D'),
  ];
  final ProtocolDefinition protocol = ProtocolDefinition(
    name: 'stream',
    description: '',
    sendSegments: segments,
    receiveSegments: segments,
  );

  test('restores a frame split across notification chunks', () {
    final PacketEncoder encoder = PacketEncoder();
    final PacketDecoder decoder = PacketDecoder();
    final List<int> frame = encoder.encode(protocol, <int>[0x10, 1, 2]).frame;

    expect(
      decoder.add('device/a', frame.sublist(0, 3), protocol).single.status,
      PacketDecodeStatus.waiting,
    );
    final List<PacketDecodeEvent> events = decoder.add(
      'device/a',
      frame.sublist(3),
      protocol,
    );
    expect(events.single.status, PacketDecodeStatus.frame);
    expect(events.single.payload, <int>[0x10, 1, 2]);
  });

  test('extracts multiple frames from one notification', () {
    final PacketEncoder encoder = PacketEncoder();
    final PacketDecoder decoder = PacketDecoder();
    final List<int> first = encoder.encode(protocol, <int>[1]).frame;
    final List<int> second = encoder.encode(protocol, <int>[2, 3]).frame;

    final List<PacketDecodeEvent> events = decoder.add('device/a', <int>[
      ...first,
      ...second,
    ], protocol);
    expect(
      events.where((event) => event.status == PacketDecodeStatus.frame),
      hasLength(2),
    );
  });

  test('recovers after noise and an invalid CRC frame', () {
    final PacketEncoder encoder = PacketEncoder();
    final PacketDecoder decoder = PacketDecoder();
    final List<int> invalid = List<int>.from(
      encoder.encode(protocol, <int>[1]).frame,
    );
    invalid[invalid.length - 2] ^= 0xFF;
    final List<int> valid = encoder.encode(protocol, <int>[2]).frame;

    final List<PacketDecodeEvent> events = decoder.add('device/a', <int>[
      0,
      9,
      ...invalid,
      ...valid,
    ], protocol);
    expect(
      events.any((event) => event.status == PacketDecodeStatus.invalid),
      isTrue,
    );
    expect(
      events
          .where((event) => event.status == PacketDecodeStatus.frame)
          .single
          .payload,
      <int>[2],
    );
  });

  test('keeps independent buffers per source', () {
    final PacketEncoder encoder = PacketEncoder();
    final PacketDecoder decoder = PacketDecoder();
    final List<int> first = encoder.encode(protocol, <int>[1]).frame;
    final List<int> second = encoder.encode(protocol, <int>[2]).frame;
    decoder.add('a', first.sublist(0, 3), protocol);
    decoder.add('b', second.sublist(0, 4), protocol);
    expect(decoder.add('a', first.sublist(3), protocol).single.payload, <int>[
      1,
    ]);
    expect(decoder.add('b', second.sublist(4), protocol).single.payload, <int>[
      2,
    ]);
  });
}
