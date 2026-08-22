import '../../models/command_definition.dart';
import '../../models/data_mapping.dart';
import '../../models/device_profile.dart';
import '../../models/protocol_import/candidate_item.dart';
import '../../models/protocol_import/protocol_import_job.dart';
import '../../models/protocol_import/validation_report.dart';
import '../../models/protocol_profile.dart';
import '../command_payload_encoder.dart';
import '../packet_encoder.dart';

/// Runs all P0 checks locally. It deliberately gathers issues rather than
/// throwing on the first invalid proposal so review can be completed in one
/// pass without any BLE or network capability.
class ProtocolCandidateValidator {
  ValidationReport validate(ProtocolImportJob job) {
    final List<ValidationIssue> issues = <ValidationIssue>[];
    final Set<String> evidenceIds = job.evidence.map((item) => item.id).toSet();
    final Set<String> itemIds = <String>{};
    for (final CandidateItem<Object> item in job.candidateWorkspace.allItems) {
      _unique(item.id, itemIds, issues, 'candidate');
      if (item.evidenceRefs.isEmpty) {
        _issue(
          issues,
          'evidence.missing',
          ValidationIssueSeverity.error,
          'candidate.${item.id}.evidenceRefs',
          '候选项必须至少引用一条证据。',
          item.id,
        );
      }
      for (final String evidenceRef in item.evidenceRefs) {
        if (!evidenceIds.contains(evidenceRef)) {
          _issue(
            issues,
            'evidence.unknownRef',
            ValidationIssueSeverity.error,
            'candidate.${item.id}.evidenceRefs',
            '引用的证据不存在：$evidenceRef。',
            item.id,
          );
        }
      }
      if (item.confidence == CandidateConfidence.low ||
          item.assumptions.isNotEmpty) {
        _issue(
          issues,
          'candidate.requiresReview',
          ValidationIssueSeverity.warning,
          'candidate.${item.id}',
          '低置信度或包含假设的候选需要单独审查。',
          item.id,
        );
      }
      if (item.riskLevel != CandidateRiskLevel.normal) {
        _issue(
          issues,
          'candidate.riskReview',
          ValidationIssueSeverity.warning,
          'candidate.${item.id}',
          '带风险标记的候选需要单独确认。',
          item.id,
        );
      }
    }
    if (job.candidateWorkspace.metadata.reviewStatus !=
        CandidateReviewStatus.accepted) {
      _issue(
        issues,
        'review.metadataPending',
        ValidationIssueSeverity.error,
        'metadata.reviewStatus',
        '工作区元信息必须明确接受后才能生成草案。',
        job.candidateWorkspace.metadata.id,
      );
    }
    for (final CandidateItem<ProtocolDefinition> item
        in job.candidateWorkspace.protocols) {
      _validateProtocol(item, issues);
    }
    for (final CandidateItem<DeviceProfile> item
        in job.candidateWorkspace.devices) {
      _validateDevice(item, issues);
    }
    for (final CandidateItem<CommandDefinition> item
        in job.candidateWorkspace.commands) {
      _validateCommand(item, issues);
    }
    for (final CandidateItem<ResponseMapping> item
        in job.candidateWorkspace.responseMappings) {
      _validateMapping(item, issues);
    }
    for (final item in job.candidateWorkspace.scripts) {
      _issue(
        issues,
        'script.untrustedByDefault',
        ValidationIssueSeverity.warning,
        'scripts.${item.id}',
        '脚本候选只会作为禁用、未信任的草案保存。',
        item.id,
      );
    }
    for (final CandidateItem<Object> item in job.candidateWorkspace.allItems) {
      if (item.riskLevel == CandidateRiskLevel.dangerous &&
          item.reviewStatus != CandidateReviewStatus.accepted) {
        _issue(
          issues,
          'review.dangerousPending',
          ValidationIssueSeverity.error,
          'candidate.${item.id}.reviewStatus',
          '危险候选尚未单独接受。',
          item.id,
        );
      }
    }
    for (final question in job.questions) {
      _unique(question.id, itemIds, issues, 'question');
      if (!question.isAnswered && question.severity.name == 'blocking') {
        _issue(
          issues,
          'question.unanswered',
          ValidationIssueSeverity.error,
          'questions.${question.id}',
          '存在未回答的阻塞问题。',
        );
      }
      for (final String candidateId in question.candidateIds) {
        if (!itemIds.contains(candidateId)) {
          _issue(
            issues,
            'question.unknownCandidate',
            ValidationIssueSeverity.error,
            'questions.${question.id}.candidateIds',
            '问题引用的候选不存在：$candidateId。',
          );
        }
      }
    }
    return ValidationReport(
      issues: List<ValidationIssue>.unmodifiable(issues),
      validatedAt: DateTime.now().toUtc(),
    );
  }

  void _validateDevice(
    CandidateItem<DeviceProfile> item,
    List<ValidationIssue> issues,
  ) {
    final DeviceProfile device = item.value;
    if (device.id.trim().isEmpty || device.name.trim().isEmpty) {
      _issue(
        issues,
        'device.identityMissing',
        ValidationIssueSeverity.error,
        'devices.${item.id}',
        '设备 ID 和名称不能为空。',
        item.id,
      );
    }
    for (final (String, String?) entry in <(String, String?)>[
      ('serviceUuid', device.serviceUuid),
      ('writeCharacteristicUuid', device.writeCharacteristicUuid),
      ('subscribeCharacteristicUuid', device.subscribeCharacteristicUuid),
    ]) {
      final String? value = entry.$2;
      if (value != null && value.trim().isNotEmpty && !_isUuid(value)) {
        _issue(
          issues,
          'device.uuidInvalid',
          ValidationIssueSeverity.error,
          'devices.${item.id}.${entry.$1}',
          '${entry.$1} 不是有效 UUID。',
          item.id,
        );
      }
    }
    if (device.writeCharacteristicUuid == null ||
        device.writeCharacteristicUuid!.trim().isEmpty) {
      _issue(
        issues,
        'device.writeTargetMissing',
        ValidationIssueSeverity.warning,
        'devices.${item.id}.writeCharacteristicUuid',
        '尚未提供写入特征 UUID。',
        item.id,
      );
    }
  }

  void _validateProtocol(
    CandidateItem<ProtocolDefinition> item,
    List<ValidationIssue> issues,
  ) {
    final ProtocolDefinition protocol = item.value;
    if (protocol.name.trim().isEmpty) {
      _issue(
        issues,
        'protocol.nameMissing',
        ValidationIssueSeverity.error,
        'protocols.${item.id}.name',
        '协议名称不能为空。',
        item.id,
      );
    }
    _validateSegmentIds(protocol.sendSegments, item.id, 'sendSegments', issues);
    _validateSegmentIds(
      protocol.receiveSegments,
      item.id,
      'receiveSegments',
      issues,
    );
    if (protocol.sendSegments.isNotEmpty) {
      try {
        PacketEncoder().preview(protocol, const <int>[0]);
      } on FormatException catch (error) {
        _issue(
          issues,
          'protocol.sendInvalid',
          ValidationIssueSeverity.error,
          'protocols.${item.id}.sendSegments',
          error.message,
          item.id,
        );
      }
    }
    if (protocol.receiveSegments.isEmpty) {
      _issue(
        issues,
        'protocol.receiveMissing',
        ValidationIssueSeverity.warning,
        'protocols.${item.id}.receiveSegments',
        '未提供接收帧定义。',
        item.id,
      );
    }
  }

  void _validateSegmentIds(
    List<ProtocolSegment> segments,
    String candidateId,
    String section,
    List<ValidationIssue> issues,
  ) {
    final Set<String> ids = <String>{};
    for (final ProtocolSegment segment in segments) {
      if (segment.id.trim().isEmpty || !ids.add(segment.id)) {
        _issue(
          issues,
          'protocol.segmentIdInvalid',
          ValidationIssueSeverity.error,
          'protocols.$candidateId.$section',
          '协议段 ID 不能为空且必须唯一。',
          candidateId,
        );
      }
      if (segment.type == ProtocolSegmentType.fixedHex) {
        try {
          PacketEncoder.parseHex(segment.fixedHex);
        } on FormatException catch (error) {
          _issue(
            issues,
            'protocol.fixedHexInvalid',
            ValidationIssueSeverity.error,
            'protocols.$candidateId.$section.${segment.id}',
            error.message,
            candidateId,
          );
        }
      }
    }
  }

  void _validateCommand(
    CandidateItem<CommandDefinition> item,
    List<ValidationIssue> issues,
  ) {
    final CommandDefinition command = item.value;
    if (command.id.trim().isEmpty || command.name.trim().isEmpty) {
      _issue(
        issues,
        'command.identityMissing',
        ValidationIssueSeverity.error,
        'commands.${item.id}',
        '命令 ID 和名称不能为空。',
        item.id,
      );
    }
    final Set<String> parameterIds = <String>{};
    for (final parameter in command.parameters) {
      if (parameter.key.trim().isEmpty || !parameterIds.add(parameter.key)) {
        _issue(
          issues,
          'command.parameterIdInvalid',
          ValidationIssueSeverity.error,
          'commands.${item.id}.parameters',
          '参数 key 不能为空且必须唯一。',
          item.id,
        );
      }
      if (parameter.min != null &&
          parameter.max != null &&
          parameter.min! > parameter.max!) {
        _issue(
          issues,
          'command.parameterRangeInvalid',
          ValidationIssueSeverity.error,
          'commands.${item.id}.parameters.${parameter.key}',
          '参数最小值不能大于最大值。',
          item.id,
        );
      }
    }
    try {
      CommandPayloadEncoder.encode(command, const <String, String>{});
    } on FormatException catch (error) {
      _issue(
        issues,
        'command.payloadInvalid',
        ValidationIssueSeverity.error,
        'commands.${item.id}.payload',
        error.message,
        item.id,
      );
    }
    final bool dangerous = RegExp(
      r'\b(reset|erase|factory|boot|upgrade|flash|auth)\b|重置|复位|擦除|恢复出厂|升级|刷写|认证',
      caseSensitive: false,
    ).hasMatch('${command.name} ${command.notes}');
    if (dangerous) {
      _issue(
        issues,
        'command.potentiallyDangerous',
        ValidationIssueSeverity.warning,
        'commands.${item.id}',
        '命令名称或说明命中高风险关键词。',
        item.id,
      );
    }
  }

  bool _isUuid(String value) => RegExp(
    r'^(?:[0-9a-fA-F]{4}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
  ).hasMatch(value.trim());

  void _validateMapping(
    CandidateItem<ResponseMapping> item,
    List<ValidationIssue> issues,
  ) {
    final ResponseMapping mapping = item.value;
    if (mapping.id.trim().isEmpty || mapping.name.trim().isEmpty) {
      _issue(
        issues,
        'mapping.identityMissing',
        ValidationIssueSeverity.error,
        'responseMappings.${item.id}',
        '响应映射 ID 和名称不能为空。',
        item.id,
      );
    }
    try {
      if (PacketEncoder.parseHex(mapping.commandHex).length != 1) {
        throw const FormatException('响应 CMD 必须恰好一个字节。');
      }
    } on FormatException catch (error) {
      _issue(
        issues,
        'mapping.commandInvalid',
        ValidationIssueSeverity.error,
        'responseMappings.${item.id}.commandHex',
        error.message,
        item.id,
      );
    }
    final Set<String> keys = <String>{};
    final List<(int, int)> occupied = <(int, int)>[];
    for (final DataField field in mapping.fields) {
      if (field.key.trim().isEmpty || !keys.add(field.key)) {
        _issue(
          issues,
          'mapping.fieldKeyInvalid',
          ValidationIssueSeverity.error,
          'responseMappings.${item.id}.fields',
          '字段 key 不能为空且必须唯一。',
          item.id,
        );
      }
      if (field.offset < 0 || field.byteLength < 1) {
        _issue(
          issues,
          'mapping.fieldRangeInvalid',
          ValidationIssueSeverity.error,
          'responseMappings.${item.id}.fields.${field.key}',
          '字段偏移和长度无效。',
          item.id,
        );
        continue;
      }
      final (int, int) range = (field.offset, field.offset + field.byteLength);
      if (occupied.any((item) => range.$1 < item.$2 && item.$1 < range.$2)) {
        _issue(
          issues,
          'mapping.fieldOverlap',
          ValidationIssueSeverity.warning,
          'responseMappings.${item.id}.fields.${field.key}',
          '字段字节范围与其他字段重叠。',
          item.id,
        );
      }
      occupied.add(range);
    }
  }

  void _unique(
    String id,
    Set<String> ids,
    List<ValidationIssue> issues,
    String kind,
  ) {
    if (id.trim().isEmpty || !ids.add(id)) {
      _issue(
        issues,
        '$kind.duplicateId',
        ValidationIssueSeverity.error,
        '$kind.$id',
        '$kind ID 不能为空且必须全局唯一。',
      );
    }
  }

  void _issue(
    List<ValidationIssue> issues,
    String code,
    ValidationIssueSeverity severity,
    String path,
    String message, [
    String? candidateId,
  ]) => issues.add(
    ValidationIssue(
      code: code,
      severity: severity,
      path: path,
      message: message,
      candidateId: candidateId,
    ),
  );
}
