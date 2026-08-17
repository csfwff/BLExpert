import 'dart:convert';

import 'device_profile.dart';
import 'command_definition.dart';
import 'data_mapping.dart';
import 'protocol_profile.dart';
import 'script_config.dart';

/// 一类蓝牙设备的完整调试工作区。
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.deviceModel,
    required this.description,
    required this.tags,
    required this.devices,
    required this.protocol,
    required this.scriptConfig,
    required this.commands,
    required this.responseMappings,
    required this.createdAt,
    required this.updatedAt,
    this.allowedCommandIds = const <String>[],
  });

  final String id;
  final String name;
  final String deviceModel;
  final String description;
  final List<String> tags;
  final List<DeviceProfile> devices;
  final ProtocolDefinition protocol;
  final ScriptConfig scriptConfig;
  final List<CommandDefinition> commands;

  /// Empty means the workspace does not restrict reusable command sends.
  final List<String> allowedCommandIds;
  final List<ResponseMapping> responseMappings;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Workspace.empty() {
    final DateTime now = DateTime.now();
    return Workspace(
      id: 'workspace-default',
      name: '默认工作区',
      deviceModel: '未知设备',
      description: 'BLExpert 初始调试工作区。',
      tags: const <String>['入门', '蓝牙'],
      devices: const <DeviceProfile>[],
      protocol: ProtocolDefinition.empty(),
      scriptConfig: ScriptConfig.empty(),
      commands: const <CommandDefinition>[],
      responseMappings: const <ResponseMapping>[],
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      deviceModel: json['deviceModel'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      devices: (json['devices'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic item) =>
                DeviceProfile.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      protocol: _protocolFromJson(json),
      scriptConfig: ScriptConfig.fromJson(
        Map<String, dynamic>.from(
          json['scriptConfig'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      commands: (json['commands'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (Map item) =>
                CommandDefinition.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      allowedCommandIds:
          (json['allowedCommandIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .where((String id) => id.trim().isNotEmpty)
              .toSet()
              .toList(growable: false),
      responseMappings:
          (json['responseMappings'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (Map item) =>
                    ResponseMapping.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'deviceModel': deviceModel,
      'description': description,
      'tags': tags,
      'devices': devices
          .map((DeviceProfile item) => item.toJson())
          .toList(growable: false),
      'protocol': protocol.toJson(),
      'scriptConfig': scriptConfig.toJson(),
      'commands': commands
          .map((CommandDefinition item) => item.toJson())
          .toList(growable: false),
      'allowedCommandIds': allowedCommandIds,
      'responseMappings': responseMappings
          .map((ResponseMapping item) => item.toJson())
          .toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Workspace copyWith({
    String? id,
    String? name,
    String? deviceModel,
    String? description,
    List<String>? tags,
    List<DeviceProfile>? devices,
    ProtocolDefinition? protocol,
    ScriptConfig? scriptConfig,
    List<CommandDefinition>? commands,
    List<String>? allowedCommandIds,
    List<ResponseMapping>? responseMappings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceModel: deviceModel ?? this.deviceModel,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      devices: devices ?? this.devices,
      protocol: protocol ?? this.protocol,
      scriptConfig: scriptConfig ?? this.scriptConfig,
      commands: commands ?? this.commands,
      allowedCommandIds: allowedCommandIds ?? this.allowedCommandIds,
      responseMappings: responseMappings ?? this.responseMappings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get commandWhitelistEnabled => allowedCommandIds.isNotEmpty;

  bool allowsConfiguredCommand(String commandId) =>
      !commandWhitelistEnabled || allowedCommandIds.contains(commandId);
}

ProtocolDefinition _protocolFromJson(Map<String, dynamic> json) {
  if (json['protocol'] case final Map protocolMap) {
    return ProtocolDefinition.fromJson(Map<String, dynamic>.from(protocolMap));
  }

  final List<dynamic> legacyProfiles =
      json['protocolProfiles'] as List<dynamic>? ?? const <dynamic>[];
  if (legacyProfiles.isNotEmpty && legacyProfiles.first is Map) {
    return ProtocolDefinition.fromJson(
      Map<String, dynamic>.from(legacyProfiles.first as Map),
    );
  }

  return ProtocolDefinition.empty();
}
