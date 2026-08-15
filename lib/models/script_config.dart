import 'dart:convert';

enum ScriptTrustState { local, importedUntrusted, trustedByUser }

/// Describes how a workspace should transform packets before sending or after
/// receiving them.
class ScriptConfig {
  const ScriptConfig({
    required this.enabled,
    required this.beforeSendScript,
    required this.afterReceiveScript,
    required this.language,
    this.trustState = ScriptTrustState.local,
    this.source = 'local',
  });

  final bool enabled;
  final String beforeSendScript;
  final String afterReceiveScript;
  final String language;
  final ScriptTrustState trustState;
  final String source;

  factory ScriptConfig.empty() {
    return const ScriptConfig(
      enabled: false,
      beforeSendScript: '',
      afterReceiveScript: '',
      language: 'javascript',
      trustState: ScriptTrustState.local,
      source: 'local',
    );
  }

  factory ScriptConfig.fromJson(Map<String, dynamic> json) {
    return ScriptConfig(
      enabled: json['enabled'] as bool? ?? false,
      beforeSendScript: json['beforeSendScript'] as String? ?? '',
      afterReceiveScript: json['afterReceiveScript'] as String? ?? '',
      language: json['language'] as String? ?? 'javascript',
      trustState: ScriptTrustState.values.firstWhere(
        (ScriptTrustState item) => item.name == json['trustState'],
        orElse: () => ScriptTrustState.local,
      ),
      source: json['source'] as String? ?? 'local',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'beforeSendScript': beforeSendScript,
      'afterReceiveScript': afterReceiveScript,
      'language': language,
      'trustState': trustState.name,
      'source': source,
    };
  }

  ScriptConfig copyWith({
    bool? enabled,
    String? beforeSendScript,
    String? afterReceiveScript,
    String? language,
    ScriptTrustState? trustState,
    String? source,
  }) {
    return ScriptConfig(
      enabled: enabled ?? this.enabled,
      beforeSendScript: beforeSendScript ?? this.beforeSendScript,
      afterReceiveScript: afterReceiveScript ?? this.afterReceiveScript,
      language: language ?? this.language,
      trustState: trustState ?? this.trustState,
      source: source ?? this.source,
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
