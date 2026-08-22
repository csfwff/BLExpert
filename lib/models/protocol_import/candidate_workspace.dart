import '../command_definition.dart';
import '../data_mapping.dart';
import '../device_profile.dart';
import '../protocol_profile.dart';
import '../script_config.dart';
import 'candidate_item.dart';

class CandidateWorkspaceMetadata {
  const CandidateWorkspaceMetadata({
    required this.name,
    required this.deviceModel,
    required this.description,
    required this.tags,
  });

  final String name;
  final String deviceModel;
  final String description;
  final List<String> tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'deviceModel': deviceModel,
    'description': description,
    'tags': tags,
  };
}

/// The non-runnable candidate counterpart to [Workspace].
class CandidateWorkspace {
  const CandidateWorkspace({
    required this.metadata,
    required this.devices,
    required this.protocols,
    required this.commands,
    required this.responseMappings,
    required this.scripts,
  });

  final CandidateItem<CandidateWorkspaceMetadata> metadata;
  final List<CandidateItem<DeviceProfile>> devices;
  final List<CandidateItem<ProtocolDefinition>> protocols;
  final List<CandidateItem<CommandDefinition>> commands;
  final List<CandidateItem<ResponseMapping>> responseMappings;
  final List<CandidateItem<ScriptConfig>> scripts;

  CandidateWorkspace copyWith({
    CandidateItem<CandidateWorkspaceMetadata>? metadata,
    List<CandidateItem<DeviceProfile>>? devices,
    List<CandidateItem<ProtocolDefinition>>? protocols,
    List<CandidateItem<CommandDefinition>>? commands,
    List<CandidateItem<ResponseMapping>>? responseMappings,
    List<CandidateItem<ScriptConfig>>? scripts,
  }) => CandidateWorkspace(
    metadata: metadata ?? this.metadata,
    devices: devices ?? this.devices,
    protocols: protocols ?? this.protocols,
    commands: commands ?? this.commands,
    responseMappings: responseMappings ?? this.responseMappings,
    scripts: scripts ?? this.scripts,
  );

  Iterable<CandidateItem<Object>> get allItems sync* {
    yield CandidateItem<Object>(
      id: metadata.id,
      value: metadata.value,
      evidenceRefs: metadata.evidenceRefs,
      confidence: metadata.confidence,
      assumptions: metadata.assumptions,
      riskLevel: metadata.riskLevel,
      reviewStatus: metadata.reviewStatus,
    );
    for (final CandidateItem<DeviceProfile> item in devices) {
      yield _asObject(item);
    }
    for (final CandidateItem<ProtocolDefinition> item in protocols) {
      yield _asObject(item);
    }
    for (final CandidateItem<CommandDefinition> item in commands) {
      yield _asObject(item);
    }
    for (final CandidateItem<ResponseMapping> item in responseMappings) {
      yield _asObject(item);
    }
    for (final CandidateItem<ScriptConfig> item in scripts) {
      yield _asObject(item);
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'metadata': metadata.toJson(
      (CandidateWorkspaceMetadata item) => item.toJson(),
    ),
    'devices': devices
        .map(
          (CandidateItem<DeviceProfile> item) =>
              item.toJson((DeviceProfile value) => value.toJson()),
        )
        .toList(),
    'protocols': protocols
        .map(
          (CandidateItem<ProtocolDefinition> item) =>
              item.toJson((ProtocolDefinition value) => value.toJson()),
        )
        .toList(),
    'commands': commands
        .map(
          (CandidateItem<CommandDefinition> item) =>
              item.toJson((CommandDefinition value) => value.toJson()),
        )
        .toList(),
    'responseMappings': responseMappings
        .map(
          (CandidateItem<ResponseMapping> item) =>
              item.toJson((ResponseMapping value) => value.toJson()),
        )
        .toList(),
    'scripts': scripts
        .map(
          (CandidateItem<ScriptConfig> item) =>
              item.toJson((ScriptConfig value) => value.toJson()),
        )
        .toList(),
  };

  static CandidateItem<Object> _asObject<T>(CandidateItem<T> item) =>
      CandidateItem<Object>(
        id: item.id,
        value: item.value as Object,
        evidenceRefs: item.evidenceRefs,
        confidence: item.confidence,
        assumptions: item.assumptions,
        riskLevel: item.riskLevel,
        reviewStatus: item.reviewStatus,
      );
}
