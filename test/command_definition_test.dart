import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blexpert/models/command_definition.dart';
import 'package:blexpert/models/bluetooth_write_mode.dart';
import 'package:blexpert/models/data_mapping.dart';
import 'package:blexpert/models/device_profile.dart';
import 'package:blexpert/models/device_safety_policy.dart';
import 'package:blexpert/models/protocol_profile.dart';
import 'package:blexpert/models/script_config.dart';
import 'package:blexpert/models/workspace.dart';
import 'package:blexpert/services/workspace_manager.dart';
import 'package:blexpert/services/command_payload_encoder.dart';
import 'package:blexpert/services/data_mapper.dart';
import 'package:blexpert/utils/ascii_utils.dart';

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
          requiresConfirmation: true,
        ),
      ],
      allowedCommandIds: const <String>['status'],
    );

    final Workspace restored = Workspace.fromJson(workspace.toJson());
    expect(restored.commands, hasLength(1));
    expect(restored.protocol.sendSegments, hasLength(3));
    expect(restored.commands.single.name, 'Status');
    expect(restored.commands.single.group, 'Query');
    expect(restored.commands.single.format, CommandPayloadFormat.hex);
    expect(restored.commands.single.isQuickAccess, isTrue);
    expect(restored.commands.single.requiresConfirmation, isTrue);
    expect(restored.allowedCommandIds, <String>['status']);
    expect(restored.commandWhitelistEnabled, isTrue);
    expect(restored.allowsConfiguredCommand('status'), isTrue);
    expect(restored.allowsConfiguredCommand('other'), isFalse);
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
    expect(workspace.commandWhitelistEnabled, isFalse);
    expect(workspace.allowsConfiguredCommand('any-command'), isTrue);
  });

  test('script transformed-send confirmation defaults to enabled', () {
    final ScriptConfig config = ScriptConfig.fromJson(<String, dynamic>{
      'enabled': true,
      'beforeSendScript': 'function beforeSend() {}',
      'afterReceiveScript': '',
      'language': 'javascript',
    });

    expect(config.confirmTransformedSend, isTrue);
  });

  test('parameterized HEX command expands business payload placeholders', () {
    const CommandDefinition command = CommandDefinition(
      id: 'set-level',
      name: 'Set level',
      group: 'Control',
      payload: 'AA {{level}} {{enabled}}',
      format: CommandPayloadFormat.hex,
      notes: '',
      enabled: true,
      isQuickAccess: true,
      parameters: <CommandParameter>[
        CommandParameter(
          key: 'level',
          label: 'Level',
          type: CommandParameterType.uint8,
          defaultValue: '0',
          min: 0,
          max: 100,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'enabled',
          label: 'Enabled',
          type: CommandParameterType.boolean,
          defaultValue: 'true',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
      ],
    );

    expect(
      CommandPayloadEncoder.encode(command, <String, String>{
        'level': '75',
        'enabled': 'false',
      }),
      <int>[0xAA, 75, 0],
    );
  });

  test('uint8 array parameter expands an arbitrary number of byte values', () {
    const CommandDefinition command = CommandDefinition(
      id: 'soul',
      name: 'Soul',
      group: '7.6',
      payload: '00 {{sequence}} {{motor}} {{levels}}',
      format: CommandPayloadFormat.hex,
      notes: '',
      enabled: true,
      isQuickAccess: true,
      parameters: <CommandParameter>[
        CommandParameter(
          key: 'sequence',
          label: 'Sequence',
          type: CommandParameterType.uint8,
          defaultValue: '0xFF',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'motor',
          label: 'Motor',
          type: CommandParameterType.uint8,
          defaultValue: '1',
          min: 1,
          max: 2,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'levels',
          label: 'Levels',
          type: CommandParameterType.uint8Array,
          defaultValue: '10, 40, 80',
          min: 0,
          max: 100,
          options: <CommandParameterOption>[],
        ),
      ],
    );

    expect(
      CommandPayloadEncoder.encode(command, <String, String>{
        'sequence': '0xFF',
        'motor': '2',
        'levels': '[0, 25, 100, 80]',
      }),
      <int>[0x00, 0xFF, 0x02, 0, 25, 100, 80],
    );
  });

  test('uint8 array parameter validates every item and requires a value', () {
    const CommandDefinition command = CommandDefinition(
      id: 'soul-levels',
      name: 'Soul levels',
      group: '',
      payload: '{{levels}}',
      format: CommandPayloadFormat.hex,
      notes: '',
      enabled: true,
      isQuickAccess: false,
      parameters: <CommandParameter>[
        CommandParameter(
          key: 'levels',
          label: 'Intensity',
          type: CommandParameterType.uint8Array,
          defaultValue: '',
          min: 0,
          max: 100,
          options: <CommandParameterOption>[],
        ),
      ],
    );

    expect(
      () => CommandPayloadEncoder.encode(command, const <String, String>{}),
      throwsFormatException,
    );
    expect(
      () => CommandPayloadEncoder.encode(command, const <String, String>{
        'levels': '10, 101',
      }),
      throwsFormatException,
    );
  });

  test('array flag expands values using the selected scalar type', () {
    const CommandDefinition command = CommandDefinition(
      id: 'mixed-array',
      name: 'Mixed array',
      group: '',
      payload: '{{words}} {{states}}',
      format: CommandPayloadFormat.hex,
      notes: '',
      enabled: true,
      isQuickAccess: false,
      parameters: <CommandParameter>[
        CommandParameter(
          key: 'words',
          label: 'Words',
          type: CommandParameterType.uint16,
          isArray: true,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'states',
          label: 'States',
          type: CommandParameterType.boolean,
          isArray: true,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
      ],
    );

    expect(
      CommandPayloadEncoder.encode(command, const <String, String>{
        'words': '0x0102, 3',
        'states': 'true, false',
      }),
      <int>[0x01, 0x02, 0x00, 0x03, 0x01, 0x00],
    );
  });

  test('individual current time parameters encode one byte each', () {
    const CommandDefinition command = CommandDefinition(
      id: 'clock',
      name: 'Clock',
      group: '',
      payload: '{{year}} {{month}} {{day}} {{hour}} {{minute}} {{second}}',
      format: CommandPayloadFormat.hex,
      notes: '',
      enabled: true,
      isQuickAccess: false,
      parameters: <CommandParameter>[
        CommandParameter(
          key: 'year',
          label: 'Year',
          type: CommandParameterType.currentYear,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'month',
          label: 'Month',
          type: CommandParameterType.currentMonth,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'day',
          label: 'Day',
          type: CommandParameterType.currentDay,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'hour',
          label: 'Hour',
          type: CommandParameterType.currentHour,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'minute',
          label: 'Minute',
          type: CommandParameterType.currentMinute,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'second',
          label: 'Second',
          type: CommandParameterType.currentSecond,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
      ],
    );

    final DateTime before = DateTime.now();
    final List<int> bytes = CommandPayloadEncoder.encode(
      command,
      const <String, String>{
        'year': '',
        'month': '',
        'day': '',
        'hour': '',
        'minute': '',
        'second': '',
      },
    );
    final DateTime after = DateTime.now();
    expect(bytes, hasLength(6));
    expect(bytes[0], anyOf(before.year % 100, after.year % 100));
    expect(bytes[1], anyOf(before.month, after.month));
    expect(bytes[2], anyOf(before.day, after.day));
    expect(bytes[3], anyOf(before.hour, after.hour));
    expect(bytes[4], anyOf(before.minute, after.minute));
  });

  test('resolves empty current time parameters for command logs', () {
    const CommandDefinition command = CommandDefinition(
      id: 'clock-log',
      name: 'Clock log',
      group: '',
      payload: '{{year}} {{month}} {{day}} {{hour}} {{minute}} {{second}}',
      format: CommandPayloadFormat.hex,
      notes: '',
      enabled: true,
      isQuickAccess: true,
      parameters: <CommandParameter>[
        CommandParameter(
          key: 'year',
          label: 'Year',
          type: CommandParameterType.currentYear,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'month',
          label: 'Month',
          type: CommandParameterType.currentMonth,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'day',
          label: 'Day',
          type: CommandParameterType.currentDay,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'hour',
          label: 'Hour',
          type: CommandParameterType.currentHour,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'minute',
          label: 'Minute',
          type: CommandParameterType.currentMinute,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'second',
          label: 'Second',
          type: CommandParameterType.currentSecond,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
      ],
    );

    expect(
      CommandPayloadEncoder.resolveValues(command, const <String, String>{
        'year': '',
        'month': '',
        'day': '',
        'hour': '',
        'minute': '',
        'second': '',
      }, currentTime: DateTime(2026, 8, 21, 9, 7, 6)),
      <String, String>{
        'year': '26',
        'month': '8',
        'day': '21',
        'hour': '9',
        'minute': '7',
        'second': '6',
      },
    );
  });

  test('current time parameters use supplied values when present', () {
    const CommandDefinition command = CommandDefinition(
      id: 'clock-override',
      name: 'Clock override',
      group: '',
      payload: '{{year}} {{month}} {{day}} {{hour}} {{minute}} {{second}}',
      format: CommandPayloadFormat.hex,
      notes: '',
      enabled: true,
      isQuickAccess: true,
      parameters: <CommandParameter>[
        CommandParameter(
          key: 'year',
          label: 'Year',
          type: CommandParameterType.currentYear,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'month',
          label: 'Month',
          type: CommandParameterType.currentMonth,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'day',
          label: 'Day',
          type: CommandParameterType.currentDay,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'hour',
          label: 'Hour',
          type: CommandParameterType.currentHour,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'minute',
          label: 'Minute',
          type: CommandParameterType.currentMinute,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
        CommandParameter(
          key: 'second',
          label: 'Second',
          type: CommandParameterType.currentSecond,
          defaultValue: '',
          min: null,
          max: null,
          options: <CommandParameterOption>[],
        ),
      ],
    );

    expect(
      CommandPayloadEncoder.encode(command, const <String, String>{
        'year': '26',
        'month': '12',
        'day': '31',
        'hour': '23',
        'minute': '59',
        'second': '58',
      }),
      <int>[26, 12, 31, 23, 59, 58],
    );
  });

  test('data mapper parses CMD response fields from DATA offsets', () {
    const ResponseMapping mapping = ResponseMapping(
      id: 'status',
      name: 'Status response',
      commandHex: 'A1',
      fields: <DataField>[
        DataField(
          key: 'temperature',
          label: 'Temperature',
          offset: 0,
          byteLength: 2,
          type: DataFieldType.int16,
          byteOrder: ProtocolByteOrder.bigEndian,
          scale: 0.1,
          offsetValue: 0,
          unit: 'C',
          bit: null,
          enumValues: <String, String>{},
        ),
        DataField(
          key: 'charging',
          label: 'Charging',
          offset: 2,
          byteLength: 1,
          type: DataFieldType.bit,
          byteOrder: ProtocolByteOrder.littleEndian,
          scale: 1,
          offsetValue: 0,
          unit: '',
          bit: 1,
          enumValues: <String, String>{},
          visibleInDataPanel: false,
        ),
      ],
    );

    final ParsedResponse? result = DataMapper.tryParse(
      mappings: const <ResponseMapping>[mapping],
      commandHex: 'A1',
      dataHex: '00 EA 02',
    );

    expect(result, isNotNull);
    expect(result!.values[0].displayValue, '23.4');
    expect(result.values[0].unit, 'C');
    expect(result.values[1].value, isTrue);
    expect(mapping.fields[0].visibleInDataPanel, isTrue);
    expect(mapping.fields[1].visibleInDataPanel, isFalse);
  });

  test('data mapper reads an array field through the remaining DATA bytes', () {
    const ResponseMapping mapping = ResponseMapping(
      id: 'dynamic-response',
      name: 'Dynamic response',
      commandHex: 'A9',
      fields: <DataField>[
        DataField(
          key: 'values',
          label: 'Values',
          offset: 0,
          byteLength: 1,
          type: DataFieldType.uint8,
          byteOrder: ProtocolByteOrder.littleEndian,
          scale: 1,
          offsetValue: 0,
          unit: '',
          bit: null,
          enumValues: <String, String>{},
          isArray: true,
        ),
      ],
    );

    final ParsedResponse? result = DataMapper.tryParse(
      mappings: const <ResponseMapping>[mapping],
      commandHex: 'A9',
      dataHex: '03 00 7F',
    );

    expect(result, isNotNull);
    expect(result!.values.single.isArray, isTrue);
    expect(result.values.single.arrayValue, <Object?>[3, 0, 127]);
    expect(result.values.single.displayValue, '3 items');
  });

  test('data mapper applies element byte length to arrays', () {
    const ResponseMapping mapping = ResponseMapping(
      id: 'word-array',
      name: 'Word array',
      commandHex: 'AA',
      fields: <DataField>[
        DataField(
          key: 'words',
          label: 'Words',
          offset: 0,
          byteLength: 2,
          type: DataFieldType.uint16,
          byteOrder: ProtocolByteOrder.littleEndian,
          scale: 1,
          offsetValue: 0,
          unit: '',
          bit: null,
          enumValues: <String, String>{},
          isArray: true,
        ),
      ],
    );

    final ParsedResponse? result = DataMapper.tryParse(
      mappings: const <ResponseMapping>[mapping],
      commandHex: 'AA',
      dataHex: '34 12 78 56',
    );

    expect(result!.values.single.arrayValue, <Object?>[0x1234, 0x5678]);
  });

  test('data mapper rejects a partial final array element', () {
    const ResponseMapping mapping = ResponseMapping(
      id: 'partial-array',
      name: 'Partial array',
      commandHex: 'AB',
      fields: <DataField>[
        DataField(
          key: 'words',
          label: 'Words',
          offset: 0,
          byteLength: 2,
          type: DataFieldType.uint16,
          byteOrder: ProtocolByteOrder.littleEndian,
          scale: 1,
          offsetValue: 0,
          unit: '',
          bit: null,
          enumValues: <String, String>{},
          isArray: true,
        ),
      ],
    );

    final ParsedResponse? result = DataMapper.tryParse(
      mappings: const <ResponseMapping>[mapping],
      commandHex: 'AB',
      dataHex: '34 12 78',
    );

    expect(result!.values.single.arrayValue, isEmpty);
    expect(result.values.single.displayValue, 'Invalid array length');
  });

  test('workspace persists command parameters and response mappings', () {
    final Workspace workspace = Workspace.empty().copyWith(
      commands: const <CommandDefinition>[
        CommandDefinition(
          id: 'command',
          name: 'Command',
          group: '',
          payload: 'A0 {{mode}}',
          format: CommandPayloadFormat.hex,
          notes: '',
          enabled: true,
          isQuickAccess: false,
          parameters: <CommandParameter>[
            CommandParameter(
              key: 'mode',
              label: 'Mode',
              type: CommandParameterType.enumValue,
              defaultValue: '1',
              min: null,
              max: null,
              options: <CommandParameterOption>[
                CommandParameterOption(label: 'On', value: '1'),
              ],
            ),
          ],
        ),
      ],
      responseMappings: const <ResponseMapping>[
        ResponseMapping(
          id: 'response',
          name: 'Response',
          commandHex: 'A0',
          fields: <DataField>[
            DataField(
              key: 'hidden',
              label: 'Hidden',
              offset: 0,
              byteLength: 1,
              type: DataFieldType.uint8,
              byteOrder: ProtocolByteOrder.littleEndian,
              scale: 1,
              offsetValue: 0,
              unit: '',
              bit: null,
              enumValues: <String, String>{},
              visibleInDataPanel: false,
            ),
          ],
          asciiLogEnabled: true,
        ),
      ],
    );
    final Workspace restored = Workspace.fromJson(workspace.toJson());
    expect(
      restored.commands.single.parameters.single.options.single.label,
      'On',
    );
    expect(restored.responseMappings.single.commandHex, 'A0');
    expect(restored.responseMappings.single.asciiLogEnabled, isTrue);
    expect(
      restored.responseMappings.single.fields.single.visibleInDataPanel,
      isFalse,
    );
  });

  test('printable ASCII removes NUL and control bytes from padded data', () {
    expect(
      printableAscii(<int>[
        ...'02.01'.codeUnits,
        0,
        0,
        ...'M01'.codeUnits,
        0,
        0,
        ...'Infinix'.codeUnits,
        0,
        0x0A,
      ]),
      '02.01M01Infinix',
    );
  });

  test('workspace store persists protocol and script configuration', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final Workspace workspace = Workspace.empty().copyWith(
      protocol: ProtocolDefinition(
        name: 'Encrypted protocol',
        description: 'Uses a script for full-frame encryption.',
        sendSegments: const <ProtocolSegment>[
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
        ],
        receiveSegments: const <ProtocolSegment>[],
      ),
      scriptConfig: const ScriptConfig(
        enabled: true,
        beforeSendScript: 'function beforeSend(context) { return {}; }',
        afterReceiveScript: 'function afterReceive(context) { return {}; }',
        language: 'javascript',
        confirmTransformedSend: false,
      ),
    );
    final WorkspaceManager writer = WorkspaceManager();
    writer.upsertWorkspace(workspace);
    await writer.save();

    final WorkspaceManager reader = WorkspaceManager();
    await reader.load();

    expect(reader.activeWorkspace.protocol.name, 'Encrypted protocol');
    expect(reader.activeWorkspace.scriptConfig.enabled, isTrue);
    expect(reader.activeWorkspace.scriptConfig.confirmTransformedSend, isFalse);
    expect(
      reader.activeWorkspace.scriptConfig.beforeSendScript,
      contains('beforeSend'),
    );
  });

  test('external import disables scripts and marks them untrusted', () {
    final Workspace workspace = Workspace.empty().copyWith(
      scriptConfig: const ScriptConfig(
        enabled: true,
        beforeSendScript: 'function beforeSend() { return {}; }',
        afterReceiveScript: '',
        language: 'javascript',
      ),
    );
    final WorkspaceManager manager = WorkspaceManager();
    manager.importWorkspaces(
      '{"activeWorkspaceId":"${workspace.id}","workspaces":[${workspace.toPrettyJson()}]}',
    );

    expect(manager.activeWorkspace.scriptConfig.enabled, isFalse);
    expect(
      manager.activeWorkspace.scriptConfig.trustState,
      ScriptTrustState.importedUntrusted,
    );
    expect(manager.activeWorkspace.scriptConfig.source, 'imported JSON');
  });

  test(
    'created workspaces get unique IDs and deleting restores another active workspace',
    () {
      final WorkspaceManager manager = WorkspaceManager();

      final Workspace first = manager.createWorkspace(
        name: 'Meter A',
        deviceModel: 'M-100',
        description: 'Primary test device',
        tags: const <String>['meter', 'lab'],
      );
      final Workspace second = manager.createWorkspace(name: 'Meter B');

      expect(first.id, isNot('workspace-default'));
      expect(second.id, isNot(first.id));
      expect(manager.workspaces, hasLength(3));
      expect(manager.activeWorkspace.id, second.id);
      expect(first.deviceModel, 'M-100');
      expect(first.tags, <String>['meter', 'lab']);

      manager.removeWorkspace(second.id);

      expect(manager.workspaces, hasLength(2));
      expect(manager.activeWorkspace.id, 'workspace-default');
    },
  );

  test('import preview reports conflicts and scripts without mutating state', () {
    final Workspace current = Workspace.empty().copyWith(name: '当前工作区');
    final Workspace imported = Workspace.empty().copyWith(
      id: current.id,
      name: '待导入工作区',
      scriptConfig: const ScriptConfig(
        enabled: true,
        beforeSendScript: 'function beforeSend() { return {}; }',
        afterReceiveScript: '',
        language: 'javascript',
      ),
    );
    final WorkspaceManager manager = WorkspaceManager();
    manager.upsertWorkspace(current);
    manager.setActiveWorkspace(current.id);

    final WorkspaceImportPreview preview = manager.previewImport(
      '{"version":1,"activeWorkspaceId":"${imported.id}","workspaces":[${imported.toPrettyJson()}]}',
    );

    expect(preview.version, WorkspaceManager.currentFormatVersion);
    expect(preview.workspaces.single.name, '待导入工作区');
    expect(preview.activeWorkspaceId, imported.id);
    expect(preview.conflictingWorkspaceIds, <String>[current.id]);
    expect(preview.scriptedWorkspaceCount, 1);
    expect(manager.activeWorkspace.name, '当前工作区');
    expect(
      manager.activeWorkspace.scriptConfig.trustState,
      ScriptTrustState.local,
    );
  });

  test('import preview rejects unsupported versions and duplicate IDs', () {
    final WorkspaceManager manager = WorkspaceManager();

    expect(
      () => manager.previewImport(
        '{"version":3,"workspaces":[${Workspace.empty().toPrettyJson()}]}',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => manager.previewImport(
        '{"version":1,"workspaces":[${Workspace.empty().toPrettyJson()},${Workspace.empty().toPrettyJson()}]}',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('v1 workspace payload previews as migrated v2 and exports v2', () {
    final Workspace workspace = Workspace.empty().copyWith(id: 'legacy');
    final WorkspaceManager manager = WorkspaceManager();
    final WorkspaceImportPreview preview = manager.previewImport(
      '{"version":1,"activeWorkspaceId":"legacy","workspaces":[${workspace.toPrettyJson()}]}',
    );

    expect(preview.sourceVersion, 1);
    expect(preview.version, WorkspaceManager.currentFormatVersion);
    expect(preview.migrationApplied, isTrue);
    manager.importWorkspaces(
      '{"version":1,"activeWorkspaceId":"legacy","workspaces":[${workspace.toPrettyJson()}]}',
    );
    expect(jsonDecode(manager.exportWorkspaces())['version'], 2);
  });

  test('current workspace export is a single-workspace import package', () {
    final WorkspaceManager manager = WorkspaceManager();
    final Workspace selected = manager.createWorkspace(name: '当前工作区');

    final Map<String, dynamic> payload =
        jsonDecode(manager.exportCurrentWorkspace()) as Map<String, dynamic>;

    expect(payload['version'], WorkspaceManager.currentFormatVersion);
    expect(payload['activeWorkspaceId'], selected.id);
    expect(payload['workspaces'], hasLength(1));
    expect((payload['workspaces'] as List<dynamic>).single['id'], selected.id);
  });

  test('merge import supports keeping or replacing conflicting workspaces', () {
    final Workspace current = Workspace.empty().copyWith(
      id: 'current',
      name: '当前版本',
    );
    final Workspace incomingConflict = Workspace.empty().copyWith(
      id: 'current',
      name: '导入版本',
      scriptConfig: const ScriptConfig(
        enabled: true,
        beforeSendScript: 'function beforeSend() { return {}; }',
        afterReceiveScript: '',
        language: 'javascript',
      ),
    );
    final Workspace incomingNew = Workspace.empty().copyWith(
      id: 'new',
      name: '新增工作区',
    );
    final String payload =
        '{"version":2,"activeWorkspaceId":"new","workspaces":[${incomingConflict.toPrettyJson()},${incomingNew.toPrettyJson()}]}';

    final WorkspaceManager keepManager = WorkspaceManager();
    keepManager.upsertWorkspace(current);
    keepManager.importWorkspaces(
      payload,
      mode: WorkspaceImportMode.merge,
      conflictPolicy: WorkspaceConflictPolicy.keepExisting,
    );
    expect(
      keepManager.workspaces.map((Workspace item) => item.name),
      containsAll(<String>['当前版本', '新增工作区']),
    );
    expect(keepManager.workspaces, hasLength(3));

    final WorkspaceManager replaceManager = WorkspaceManager();
    replaceManager.upsertWorkspace(current);
    replaceManager.importWorkspaces(
      payload,
      mode: WorkspaceImportMode.merge,
      conflictPolicy: WorkspaceConflictPolicy.replaceExisting,
    );
    expect(
      replaceManager.workspaces.map((Workspace item) => item.name),
      contains('导入版本'),
    );
    expect(
      replaceManager.workspaces
          .firstWhere((Workspace item) => item.id == 'current')
          .scriptConfig
          .trustState,
      ScriptTrustState.importedUntrusted,
    );
  });

  test('device connection defaults round-trip through workspace JSON', () {
    final Workspace workspace = Workspace.empty().copyWith(
      devices: <DeviceProfile>[
        DeviceProfile(
          id: 'device-1',
          name: 'Meter',
          protocol: 'BLE',
          notes: '',
          commands: const <String>[],
          scriptConfig: ScriptConfig.empty(),
          serviceUuid: '180F',
          writeCharacteristicUuid: '2A19',
          writeMode: BluetoothWriteMode.withoutResponse,
          subscribeCharacteristicUuid: '2A1A',
          webServiceUuid: '180F',
          safetyPolicy: const DeviceSafetyPolicy(
            allowedWriteTargetKeys: <String>['180F/2A19'],
            maxFinalFrameBytes: 128,
            requireWriteWithResponse: true,
          ),
        ),
      ],
    );

    final DeviceProfile restored = Workspace.fromJson(
      workspace.toJson(),
    ).devices.single;
    expect(restored.serviceUuid, '180F');
    expect(restored.writeCharacteristicUuid, '2A19');
    expect(restored.writeMode, BluetoothWriteMode.withoutResponse);
    expect(restored.subscribeCharacteristicUuid, '2A1A');
    expect(restored.webServiceUuid, '180F');
    expect(restored.safetyPolicy.allowedWriteTargetKeys, <String>['180F/2A19']);
    expect(restored.safetyPolicy.maxFinalFrameBytes, 128);
    expect(restored.safetyPolicy.requireWriteWithResponse, isTrue);
  });
}
