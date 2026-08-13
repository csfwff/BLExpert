import 'dart:convert';

/// Describes how a workspace should transform packets before sending or after
/// receiving them.
class ScriptConfig {
  const ScriptConfig({
    required this.enabled,
    required this.beforeSendScript,
    required this.afterReceiveScript,
    required this.language,
  });

  final bool enabled;
  final String beforeSendScript;
  final String afterReceiveScript;
  final String language;

  factory ScriptConfig.empty() {
    return const ScriptConfig(
      enabled: false,
      beforeSendScript: '',
      afterReceiveScript: '',
      language: 'javascript',
    );
  }

  factory ScriptConfig.fromJson(Map<String, dynamic> json) {
    return ScriptConfig(
      enabled: json['enabled'] as bool? ?? false,
      beforeSendScript: json['beforeSendScript'] as String? ?? '',
      afterReceiveScript: json['afterReceiveScript'] as String? ?? '',
      language: json['language'] as String? ?? 'javascript',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'beforeSendScript': beforeSendScript,
      'afterReceiveScript': afterReceiveScript,
      'language': language,
    };
  }

  ScriptConfig copyWith({
    bool? enabled,
    String? beforeSendScript,
    String? afterReceiveScript,
    String? language,
  }) {
    return ScriptConfig(
      enabled: enabled ?? this.enabled,
      beforeSendScript: beforeSendScript ?? this.beforeSendScript,
      afterReceiveScript: afterReceiveScript ?? this.afterReceiveScript,
      language: language ?? this.language,
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

