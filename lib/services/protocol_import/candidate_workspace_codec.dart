import 'dart:convert';

import '../../models/command_definition.dart';
import '../../models/bluetooth_write_mode.dart';
import '../../models/data_mapping.dart';
import '../../models/device_profile.dart';
import '../../models/protocol_import/candidate_item.dart';
import '../../models/protocol_import/candidate_workspace.dart';
import '../../models/protocol_import/import_evidence.dart';
import '../../models/protocol_import/protocol_import_job.dart';
import '../../models/protocol_import/validation_report.dart';
import '../../models/protocol_profile.dart';
import '../../models/script_config.dart';

/// Strict boundary for untrusted candidate JSON. Runtime workspace factories are
/// deliberately permissive for legacy data, so they must only be called after
/// this codec has checked the candidate envelope and enum values.
class CandidateWorkspaceCodec {
  ProtocolImportJob decode(String jsonText) {
    final Object? decoded;
    try {
      decoded = json.decode(jsonText);
    } on FormatException {
      throw const FormatException('候选草案不是有效 JSON。');
    }
    return fromJson(_map(decoded, r'$'));
  }

  String encode(ProtocolImportJob job) =>
      const JsonEncoder.withIndent('  ').convert(job.toJson());

  ProtocolImportJob fromJson(Map<String, dynamic> json) {
    final int schemaVersion = _integer(
      json['schemaVersion'],
      r'$.schemaVersion',
    );
    if (schemaVersion != ProtocolImportJob.currentSchemaVersion) {
      throw FormatException('不支持的候选草案版本：$schemaVersion。');
    }
    final ProtocolImportSource source = _source(
      _map(json['source'], r'$.source'),
    );
    return ProtocolImportJob(
      id: _nonEmptyString(json['id'], r'$.id'),
      schemaVersion: schemaVersion,
      source: source,
      evidence: _list(json['evidence'], r'$.evidence').indexed
          .map(
            ((int, Object?) entry) =>
                _evidence(_map(entry.$2, '\$.evidence[${entry.$1}]')),
          )
          .toList(growable: false),
      questions: _list(json['questions'], r'$.questions').indexed
          .map(
            ((int, Object?) entry) =>
                _question(_map(entry.$2, '\$.questions[${entry.$1}]')),
          )
          .toList(growable: false),
      candidateWorkspace: _candidateWorkspace(
        _map(json['candidateWorkspace'], r'$.candidateWorkspace'),
      ),
      status: _enum(
        json['status'],
        ProtocolImportJobStatus.values,
        r'$.status',
      ),
      validationReport: json['validationReport'] == null
          ? null
          : _report(_map(json['validationReport'], r'$.validationReport')),
    );
  }

  ProtocolImportSource _source(Map<String, dynamic> json) =>
      ProtocolImportSource(
        name: _nonEmptyString(json['name'], r'$.source.name'),
        hash: _nonEmptyString(json['hash'], r'$.source.hash'),
        importedAt: _date(json['importedAt'], r'$.source.importedAt'),
      );

  ImportEvidence _evidence(Map<String, dynamic> json) => ImportEvidence(
    id: _nonEmptyString(json['id'], r'$.evidence.id'),
    excerpt: _nonEmptyString(json['excerpt'], r'$.evidence.excerpt'),
    location: _nonEmptyString(json['location'], r'$.evidence.location'),
    sourceHash: _nonEmptyString(json['sourceHash'], r'$.evidence.sourceHash'),
  );

  ImportQuestion _question(Map<String, dynamic> json) => ImportQuestion(
    id: _nonEmptyString(json['id'], r'$.questions.id'),
    question: _nonEmptyString(json['question'], r'$.questions.question'),
    severity: _enum(
      json['severity'],
      ImportQuestionSeverity.values,
      r'$.questions.severity',
    ),
    candidateIds: _stringList(
      json['candidateIds'],
      r'$.questions.candidateIds',
    ),
    isAnswered: _boolean(json['isAnswered'], r'$.questions.isAnswered'),
  );

  CandidateWorkspace _candidateWorkspace(Map<String, dynamic> json) {
    return CandidateWorkspace(
      metadata: _item(
        _map(json['metadata'], r'$.candidateWorkspace.metadata'),
        r'$.candidateWorkspace.metadata',
        (Map<String, dynamic> value) => CandidateWorkspaceMetadata(
          name: _string(
            value['name'],
            r'$.candidateWorkspace.metadata.value.name',
          ),
          deviceModel: _string(
            value['deviceModel'],
            r'$.candidateWorkspace.metadata.value.deviceModel',
          ),
          description: _string(
            value['description'],
            r'$.candidateWorkspace.metadata.value.description',
          ),
          tags: _stringList(
            value['tags'],
            r'$.candidateWorkspace.metadata.value.tags',
          ),
        ),
      ),
      devices: _items(json['devices'], r'$.candidateWorkspace.devices', (
        Map<String, dynamic> value,
      ) {
        _validateDeviceValue(value);
        return DeviceProfile.fromJson(value);
      }),
      protocols: _items(json['protocols'], r'$.candidateWorkspace.protocols', (
        Map<String, dynamic> value,
      ) {
        _validateProtocolValue(value);
        return ProtocolDefinition.fromJson(value);
      }),
      commands: _items(json['commands'], r'$.candidateWorkspace.commands', (
        Map<String, dynamic> value,
      ) {
        _validateCommandValue(value);
        return CommandDefinition.fromJson(value);
      }),
      responseMappings: _items(
        json['responseMappings'],
        r'$.candidateWorkspace.responseMappings',
        (Map<String, dynamic> value) {
          _validateMappingValue(value);
          return ResponseMapping.fromJson(value);
        },
      ),
      scripts: _items(json['scripts'], r'$.candidateWorkspace.scripts', (
        Map<String, dynamic> value,
      ) {
        _validateScriptValue(value);
        return ScriptConfig.fromJson(value);
      }),
    );
  }

  List<CandidateItem<T>> _items<T>(
    Object? raw,
    String path,
    T Function(Map<String, dynamic> value) valueFromJson,
  ) {
    return _list(raw, path).indexed
        .map(
          ((int, Object?) entry) => _item(
            _map(entry.$2, '$path[${entry.$1}]'),
            '$path[${entry.$1}]',
            valueFromJson,
          ),
        )
        .toList(growable: false);
  }

  CandidateItem<T> _item<T>(
    Map<String, dynamic> json,
    String path,
    T Function(Map<String, dynamic> value) valueFromJson,
  ) {
    return CandidateItem<T>(
      id: _nonEmptyString(json['id'], '$path.id'),
      value: valueFromJson(_map(json['value'], '$path.value')),
      evidenceRefs: _stringList(json['evidenceRefs'], '$path.evidenceRefs'),
      confidence: _enum(
        json['confidence'],
        CandidateConfidence.values,
        '$path.confidence',
      ),
      assumptions: _stringList(json['assumptions'], '$path.assumptions'),
      riskLevel: _enum(
        json['riskLevel'],
        CandidateRiskLevel.values,
        '$path.riskLevel',
      ),
      reviewStatus: _enum(
        json['reviewStatus'],
        CandidateReviewStatus.values,
        '$path.reviewStatus',
      ),
    );
  }

  void _validateDeviceValue(Map<String, dynamic> value) {
    _requiredString(value, 'id', '设备');
    _requiredString(value, 'name', '设备');
    if (value['writeMode'] != null) {
      _enum(value['writeMode'], BluetoothWriteMode.values, 'device.writeMode');
    }
  }

  void _validateProtocolValue(Map<String, dynamic> value) {
    _requiredString(value, 'name', '协议');
    for (final String key in <String>['sendSegments', 'receiveSegments']) {
      for (final Object? rawSegment in _list(value[key], 'protocol.$key')) {
        final Map<String, dynamic> segment = _map(rawSegment, 'protocol.$key');
        _requiredString(segment, 'id', '协议段');
        _enum(
          segment['type'],
          ProtocolSegmentType.values,
          'protocol.segment.type',
        );
        if (segment['byteOrder'] != null) {
          _enum(
            segment['byteOrder'],
            ProtocolByteOrder.values,
            'protocol.segment.byteOrder',
          );
        }
        if (segment['checksumAlgorithm'] != null) {
          _enum(
            segment['checksumAlgorithm'],
            ProtocolChecksumAlgorithm.values,
            'protocol.segment.checksumAlgorithm',
          );
        }
        if (segment['calculationRange'] != null) {
          _enum(
            segment['calculationRange'],
            ProtocolCalculationRange.values,
            'protocol.segment.calculationRange',
          );
        }
      }
    }
  }

  void _validateCommandValue(Map<String, dynamic> value) {
    _requiredString(value, 'id', '命令');
    _requiredString(value, 'name', '命令');
    _enum(value['format'], CommandPayloadFormat.values, 'command.format');
    if (value['parameters'] != null) {
      for (final Object? rawParameter in _list(
        value['parameters'],
        'command.parameters',
      )) {
        final Map<String, dynamic> parameter = _map(
          rawParameter,
          'command.parameter',
        );
        _requiredString(parameter, 'key', '命令参数');
        _enum(
          parameter['type'],
          CommandParameterType.values,
          'command.parameter.type',
        );
      }
    }
  }

  void _validateMappingValue(Map<String, dynamic> value) {
    _requiredString(value, 'id', '响应映射');
    _requiredString(value, 'name', '响应映射');
    _requiredString(value, 'commandHex', '响应映射');
    for (final Object? rawField in _list(value['fields'], 'mapping.fields')) {
      final Map<String, dynamic> field = _map(rawField, 'mapping.field');
      _requiredString(field, 'key', '响应字段');
      _enum(field['type'], DataFieldType.values, 'mapping.field.type');
      _enum(
        field['byteOrder'],
        ProtocolByteOrder.values,
        'mapping.field.byteOrder',
      );
      _integer(field['offset'], 'mapping.field.offset');
      _integer(field['byteLength'], 'mapping.field.byteLength');
    }
  }

  void _validateScriptValue(Map<String, dynamic> value) {
    _boolean(value['enabled'], 'script.enabled');
    _requiredString(value, 'language', '脚本');
  }

  void _requiredString(Map<String, dynamic> value, String key, String label) {
    if (_nonEmptyString(value[key], '$label.$key').isEmpty) {
      throw FormatException('$label.$key 不能为空。');
    }
  }

  ValidationReport _report(Map<String, dynamic> json) => ValidationReport(
    issues: _list(json['issues'], r'$.validationReport.issues').indexed
        .map(((int, Object?) entry) {
          final Map<String, dynamic> issue = _map(
            entry.$2,
            '\$.validationReport.issues[${entry.$1}]',
          );
          return ValidationIssue(
            code: _nonEmptyString(
              issue['code'],
              r'$.validationReport.issues.code',
            ),
            severity: _enum(
              issue['severity'],
              ValidationIssueSeverity.values,
              r'$.validationReport.issues.severity',
            ),
            path: _nonEmptyString(
              issue['path'],
              r'$.validationReport.issues.path',
            ),
            message: _nonEmptyString(
              issue['message'],
              r'$.validationReport.issues.message',
            ),
            candidateId: issue['candidateId'] == null
                ? null
                : _nonEmptyString(
                    issue['candidateId'],
                    r'$.validationReport.issues.candidateId',
                  ),
          );
        })
        .toList(growable: false),
    validatedAt: _date(json['validatedAt'], r'$.validationReport.validatedAt'),
  );

  Map<String, dynamic> _map(Object? value, String path) {
    if (value is! Map) throw FormatException('$path 必须是对象。');
    return Map<String, dynamic>.from(value);
  }

  List<Object?> _list(Object? value, String path) {
    if (value is! List) throw FormatException('$path 必须是数组。');
    return List<Object?>.from(value);
  }

  String _string(Object? value, String path) {
    if (value is! String) throw FormatException('$path 必须是字符串。');
    return value;
  }

  String _nonEmptyString(Object? value, String path) {
    final String result = _string(value, path).trim();
    if (result.isEmpty) throw FormatException('$path 不能为空。');
    return result;
  }

  int _integer(Object? value, String path) {
    if (value is! int) throw FormatException('$path 必须是整数。');
    return value;
  }

  bool _boolean(Object? value, String path) {
    if (value is! bool) throw FormatException('$path 必须是布尔值。');
    return value;
  }

  List<String> _stringList(Object? value, String path) {
    return _list(value, path).indexed
        .map(((int, Object?) entry) => _string(entry.$2, '$path[${entry.$1}]'))
        .toList(growable: false);
  }

  DateTime _date(Object? value, String path) {
    final DateTime? parsed = DateTime.tryParse(_string(value, path));
    if (parsed == null) throw FormatException('$path 必须是 ISO-8601 时间。');
    return parsed;
  }

  T _enum<T extends Enum>(Object? value, List<T> values, String path) {
    final String name = _string(value, path);
    for (final T item in values) {
      if (item.name == name) return item;
    }
    throw FormatException('$path 包含未知枚举值：$name。');
  }
}
