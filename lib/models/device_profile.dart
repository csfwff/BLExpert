import 'script_config.dart';

/// Describes a single Bluetooth device profile inside a workspace.
class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.notes,
    required this.commands,
    required this.scriptConfig,
  });

  final String id;
  final String name;
  final String protocol;
  final String notes;
  final List<String> commands;
  final ScriptConfig scriptConfig;

  factory DeviceProfile.fromJson(Map<String, dynamic> json) {
    return DeviceProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      protocol: json['protocol'] as String? ?? 'BLE',
      notes: json['notes'] as String? ?? '',
      commands: (json['commands'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      scriptConfig: ScriptConfig.fromJson(
        Map<String, dynamic>.from(
          json['scriptConfig'] as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'protocol': protocol,
      'notes': notes,
      'commands': commands,
      'scriptConfig': scriptConfig.toJson(),
    };
  }

  DeviceProfile copyWith({
    String? id,
    String? name,
    String? protocol,
    String? notes,
    List<String>? commands,
    ScriptConfig? scriptConfig,
  }) {
    return DeviceProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      notes: notes ?? this.notes,
      commands: commands ?? this.commands,
      scriptConfig: scriptConfig ?? this.scriptConfig,
    );
  }
}

