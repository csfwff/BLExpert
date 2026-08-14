enum CommandPayloadFormat { hex, text }

/// A reusable packet definition owned by a workspace.
class CommandDefinition {
  const CommandDefinition({
    required this.id,
    required this.name,
    required this.group,
    required this.payload,
    required this.format,
    required this.notes,
    required this.enabled,
    required this.isQuickAccess,
  });

  final String id;
  final String name;
  final String group;
  final String payload;
  final CommandPayloadFormat format;
  final String notes;
  final bool enabled;
  final bool isQuickAccess;

  factory CommandDefinition.fromJson(Map<String, dynamic> json) {
    return CommandDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      group: json['group'] as String? ?? '',
      payload: json['payload'] as String? ?? '',
      format: (json['format'] as String? ?? 'hex') == 'text'
          ? CommandPayloadFormat.text
          : CommandPayloadFormat.hex,
      notes: json['notes'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      isQuickAccess: json['isQuickAccess'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'group': group,
    'payload': payload,
    'format': format.name,
    'notes': notes,
    'enabled': enabled,
    'isQuickAccess': isQuickAccess,
  };

  CommandDefinition copyWith({
    String? id,
    String? name,
    String? group,
    String? payload,
    CommandPayloadFormat? format,
    String? notes,
    bool? enabled,
    bool? isQuickAccess,
  }) {
    return CommandDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      payload: payload ?? this.payload,
      format: format ?? this.format,
      notes: notes ?? this.notes,
      enabled: enabled ?? this.enabled,
      isQuickAccess: isQuickAccess ?? this.isQuickAccess,
    );
  }
}
