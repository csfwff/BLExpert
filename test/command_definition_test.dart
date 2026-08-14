import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/models/command_definition.dart';
import 'package:blexpert/models/protocol_profile.dart';
import 'package:blexpert/models/workspace.dart';

void main() {
  test('command definitions round-trip through workspace JSON', () {
    final Workspace workspace = Workspace.empty().copyWith(
      protocol: ProtocolDefinition(
        name: 'Main Protocol',
        description: 'Header, length and crc.',
        sendSegments: const <ProtocolSegment>[
          ProtocolSegment(
            id: 'fixed-header',
            type: ProtocolSegmentType.fixedHex,
            label: 'Header',
            byteLength: null,
            byteOrder: null,
            fixedHex: 'AA 55',
            checksumAlgorithm: null,
            calculationRange: null,
          ),
          ProtocolSegment(
            id: 'payload',
            type: ProtocolSegmentType.payload,
            label: 'Payload',
            byteLength: null,
            byteOrder: null,
            fixedHex: '',
            checksumAlgorithm: null,
            calculationRange: null,
          ),
          ProtocolSegment(
            id: 'checksum',
            type: ProtocolSegmentType.checksum,
            label: 'Checksum',
            byteLength: null,
            byteOrder: ProtocolByteOrder.littleEndian,
            fixedHex: '',
            checksumAlgorithm: ProtocolChecksumAlgorithm.crc16Modbus,
            calculationRange: ProtocolCalculationRange.frameExcludingSelf,
          ),
        ],
        receiveSegments: const <ProtocolSegment>[
          ProtocolSegment(
            id: 'rx-payload',
            type: ProtocolSegmentType.payload,
            label: 'Payload',
            byteLength: null,
            byteOrder: null,
            fixedHex: '',
            checksumAlgorithm: null,
            calculationRange: null,
          ),
        ],
      ),
      commands: <CommandDefinition>[
        const CommandDefinition(
          id: 'status',
          name: 'Status',
          group: 'Query',
          payload: 'AA 55 01',
          format: CommandPayloadFormat.hex,
          notes: 'Read device status.',
          enabled: true,
          isQuickAccess: true,
        ),
      ],
    );

    final Workspace restored = Workspace.fromJson(workspace.toJson());
    expect(restored.commands, hasLength(1));
    expect(restored.protocol.sendSegments, hasLength(3));
    expect(restored.commands.single.name, 'Status');
    expect(restored.commands.single.group, 'Query');
    expect(restored.commands.single.format, CommandPayloadFormat.hex);
    expect(restored.commands.single.isQuickAccess, isTrue);
    expect(restored.protocol.sendSegments.first.fixedHex, 'AA 55');
  });

  test('workspace accepts legacy JSON without command definitions', () {
    final Workspace workspace = Workspace.fromJson(<String, dynamic>{
      'id': 'legacy',
      'name': 'Legacy',
    });

    expect(workspace.commands, isEmpty);
    expect(workspace.protocol.sendSegments, isEmpty);
    expect(workspace.protocol.receiveSegments, isEmpty);
  });
}
