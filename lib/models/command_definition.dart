enum CommandPayloadFormat { hex, text }

/// Describes the value a user may supply when sending a command template.
///
/// The command payload remains business data only. Framing, sequence numbers,
/// checksums and encryption continue to belong to the protocol layer.
enum CommandParameterType {
  uint8,
  int8,
  uint16,
  int16,
  uint32,
  int32,
  hex,
  ascii,
  utf8,
  boolean,
  enumValue,
  currentYear,
  currentMonth,
  currentDay,
  currentHour,
  currentMinute,
  currentSecond,
}

class CommandParameterOption {
  const CommandParameterOption({required this.label, required this.value});

  final String label;
  final String value;

  factory CommandParameterOption.fromJson(Map<String, dynamic> json) =>
      CommandParameterOption(
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'value': value,
  };
}

class CommandParameter {
  const CommandParameter({
    required this.key,
    required this.label,
    required this.type,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.options,
  });

  /// Identifier referenced by a payload placeholder, for example `{{level}}`.
  final String key;
  final String label;
  final CommandParameterType type;
  final String defaultValue;
  final int? min;
  final int? max;
  final List<CommandParameterOption> options;

  factory CommandParameter.fromJson(Map<String, dynamic> json) {
    return CommandParameter(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: _parameterTypeFromJson(json['type']),
      defaultValue: json['defaultValue'] as String? ?? '',
      min: json['min'] as int?,
      max: json['max'] as int?,
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (Map item) => CommandParameterOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
    'type': type.name,
    'defaultValue': defaultValue,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (options.isNotEmpty)
      'options': options
          .map((CommandParameterOption item) => item.toJson())
          .toList(growable: false),
  };

  CommandParameter copyWith({
    String? key,
    String? label,
    CommandParameterType? type,
    String? defaultValue,
    int? min,
    bool clearMin = false,
    int? max,
    bool clearMax = false,
    List<CommandParameterOption>? options,
  }) => CommandParameter(
    key: key ?? this.key,
    label: label ?? this.label,
    type: type ?? this.type,
    defaultValue: defaultValue ?? this.defaultValue,
    min: clearMin ? null : (min ?? this.min),
    max: clearMax ? null : (max ?? this.max),
    options: options ?? this.options,
  );
}

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
    this.requiresConfirmation = false,
    this.parameters = const <CommandParameter>[],
  });

  final String id;
  final String name;
  final String group;
  final String payload;
  final CommandPayloadFormat format;
  final String notes;
  final bool enabled;
  final bool isQuickAccess;
  final bool requiresConfirmation;
  final List<CommandParameter> parameters;

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
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
      parameters: (json['parameters'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (Map item) =>
                CommandParameter.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
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
    'requiresConfirmation': requiresConfirmation,
    if (parameters.isNotEmpty)
      'parameters': parameters
          .map((CommandParameter item) => item.toJson())
          .toList(growable: false),
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
    bool? requiresConfirmation,
    List<CommandParameter>? parameters,
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
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      parameters: parameters ?? this.parameters,
    );
  }
}

CommandParameterType _parameterTypeFromJson(Object? value) {
  return CommandParameterType.values.firstWhere(
    (CommandParameterType item) => item.name == value,
    orElse: () => CommandParameterType.uint8,
  );
}
