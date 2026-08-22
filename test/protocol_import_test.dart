import 'dart:convert';

import 'package:blexpert/models/command_definition.dart';
import 'package:blexpert/models/data_mapping.dart';
import 'package:blexpert/models/device_profile.dart';
import 'package:blexpert/models/protocol_import/candidate_item.dart';
import 'package:blexpert/models/protocol_import/candidate_workspace.dart';
import 'package:blexpert/models/protocol_import/import_evidence.dart';
import 'package:blexpert/models/protocol_import/protocol_import_job.dart';
import 'package:blexpert/models/protocol_profile.dart';
import 'package:blexpert/models/script_config.dart';
import 'package:blexpert/services/protocol_import/candidate_workspace_codec.dart';
import 'package:blexpert/services/protocol_import/protocol_candidate_validator.dart';
import 'package:blexpert/services/protocol_import/workspace_draft_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProtocolImportJob validJob({
    CandidateReviewStatus status = CandidateReviewStatus.accepted,
    CandidateRiskLevel commandRisk = CandidateRiskLevel.normal,
    bool includeScript = false,
  }) {
    CandidateItem<T> item<T>(
      String id,
      T value, {
      CandidateRiskLevel risk = CandidateRiskLevel.normal,
    }) => CandidateItem<T>(
      id: id,
      value: value,
      evidenceRefs: const <String>['evidence-1'],
      confidence: CandidateConfidence.high,
      assumptions: const <String>[],
      riskLevel: risk,
      reviewStatus: status,
    );
    return ProtocolImportJob(
      id: 'job-1',
      schemaVersion: ProtocolImportJob.currentSchemaVersion,
      source: ProtocolImportSource(
        name: 'fixture.json',
        hash: 'sha256:fixture',
        importedAt: DateTime.utc(2026, 8, 22),
      ),
      evidence: const <ImportEvidence>[
        ImportEvidence(
          id: 'evidence-1',
          excerpt: '命令 01 查询状态。',
          location: '第 1 节',
          sourceHash: 'sha256:fixture',
        ),
      ],
      questions: const <ImportQuestion>[],
      candidateWorkspace: CandidateWorkspace(
        metadata: item(
          'metadata-1',
          const CandidateWorkspaceMetadata(
            name: '导入草案',
            deviceModel: 'Meter-A',
            description: '人工构造的 P0 候选。',
            tags: <String>['P0'],
          ),
        ),
        devices: const <CandidateItem<DeviceProfile>>[],
        protocols: <CandidateItem<ProtocolDefinition>>[
          item(
            'protocol-1',
            const ProtocolDefinition(
              name: 'Standard',
              description: '',
              sendSegments: <ProtocolSegment>[
                ProtocolSegment(
                  id: 'header',
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
              ],
              receiveSegments: <ProtocolSegment>[],
            ),
          ),
        ],
        commands: <CandidateItem<CommandDefinition>>[
          item(
            'command-1',
            const CommandDefinition(
              id: 'status',
              name: '查询状态',
              group: '查询',
              payload: '01',
              format: CommandPayloadFormat.hex,
              notes: '',
              enabled: true,
              isQuickAccess: true,
            ),
            risk: commandRisk,
          ),
        ],
        responseMappings: const <CandidateItem<ResponseMapping>>[],
        scripts: includeScript
            ? <CandidateItem<ScriptConfig>>[
                item(
                  'script-1',
                  const ScriptConfig(
                    enabled: true,
                    beforeSendScript:
                        'function beforeSend(context) { return context.hex; }',
                    afterReceiveScript: '',
                    language: 'javascript',
                  ),
                  risk: CandidateRiskLevel.warning,
                ),
              ]
            : const <CandidateItem<ScriptConfig>>[],
      ),
      status: ProtocolImportJobStatus.created,
    );
  }

  test('candidate codec round-trips strict P0 envelope', () {
    final CandidateWorkspaceCodec codec = CandidateWorkspaceCodec();
    final ProtocolImportJob restored = codec.decode(codec.encode(validJob()));

    expect(restored.id, 'job-1');
    expect(restored.candidateWorkspace.protocols.single.value.name, 'Standard');
    expect(restored.candidateWorkspace.commands.single.evidenceRefs, <String>[
      'evidence-1',
    ]);
  });

  test('candidate codec rejects unknown schema and unknown enums', () {
    final CandidateWorkspaceCodec codec = CandidateWorkspaceCodec();
    final String validJson = codec.encode(validJob());

    expect(
      () => codec.decode(
        validJson.replaceFirst('"schemaVersion": 1', '"schemaVersion": 2'),
      ),
      throwsFormatException,
    );
    expect(
      () => codec.decode(
        validJson.replaceFirst(
          '"confidence": "high"',
          '"confidence": "certain"',
        ),
      ),
      throwsFormatException,
    );
  });

  test('validator reports multiple invalid candidate items together', () {
    final ProtocolImportJob invalid = validJob().copyWith(
      candidateWorkspace: validJob().candidateWorkspace.copyWith(
        protocols: <CandidateItem<ProtocolDefinition>>[
          CandidateItem<ProtocolDefinition>(
            id: 'protocol-1',
            value: const ProtocolDefinition(
              name: '',
              description: '',
              sendSegments: <ProtocolSegment>[
                ProtocolSegment(
                  id: '',
                  type: ProtocolSegmentType.fixedHex,
                  label: '',
                  byteLength: null,
                  byteOrder: null,
                  fixedHex: 'XYZ',
                  checksumAlgorithm: null,
                  calculationRange: null,
                ),
              ],
              receiveSegments: <ProtocolSegment>[],
            ),
            evidenceRefs: const <String>[],
            confidence: CandidateConfidence.low,
            assumptions: const <String>['猜测'],
            riskLevel: CandidateRiskLevel.normal,
            reviewStatus: CandidateReviewStatus.accepted,
          ),
        ],
      ),
    );

    final report = ProtocolCandidateValidator().validate(invalid);
    final codes = report.issues.map((item) => item.code).toSet();
    expect(
      codes,
      containsAll(<String>[
        'evidence.missing',
        'protocol.nameMissing',
        'protocol.segmentIdInvalid',
        'protocol.fixedHexInvalid',
        'protocol.sendInvalid',
      ]),
    );
  });

  test('dangerous candidate is blocked until independently accepted', () {
    final WorkspaceDraftManager manager = WorkspaceDraftManager();
    final pending = validJob(
      status: CandidateReviewStatus.pending,
      commandRisk: CandidateRiskLevel.dangerous,
    );

    expect(manager.validate(pending).status, ProtocolImportJobStatus.blocked);
  });

  test(
    'draft manager creates a separate safe workspace and persists it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final WorkspaceDraftManager manager = WorkspaceDraftManager();
      final CandidateWorkspaceCodec codec = CandidateWorkspaceCodec();
      final ProtocolImportJob job = manager.importCandidateJson(
        codec.encode(validJob(includeScript: true)),
      );
      expect(job.status, ProtocolImportJobStatus.readyToApply);

      final draft = manager.createDraft(job.id);
      expect(draft.workspace.id, isNot('workspace-default'));
      expect(draft.workspace.allowedCommandIds, isEmpty);
      expect(draft.workspace.commands.single.isQuickAccess, isFalse);
      expect(draft.workspace.scriptConfig.enabled, isFalse);
      expect(
        draft.workspace.scriptConfig.trustState,
        ScriptTrustState.importedUntrusted,
      );
      expect(draft.workspace.scriptConfig.source, 'AI import draft');

      await manager.save();
      final WorkspaceDraftManager restored = WorkspaceDraftManager();
      await restored.load();
      expect(restored.drafts.single.workspace.id, draft.workspace.id);
      expect(restored.jobs.single.status, ProtocolImportJobStatus.applied);
    },
  );

  test('editing candidate JSON replaces the job and revalidates it', () {
    final WorkspaceDraftManager manager = WorkspaceDraftManager();
    final CandidateWorkspaceCodec codec = CandidateWorkspaceCodec();
    manager.importCandidateJson(codec.encode(validJob()));
    final Map<String, dynamic> edited = Map<String, dynamic>.from(
      validJob().toJson(),
    );
    final Map<String, dynamic> candidate = Map<String, dynamic>.from(
      edited['candidateWorkspace'] as Map,
    );
    final Map<String, dynamic> metadata = Map<String, dynamic>.from(
      candidate['metadata'] as Map,
    );
    metadata['value'] = <String, dynamic>{
      ...Map<String, dynamic>.from(metadata['value'] as Map),
      'name': '修订后的草案',
    };
    candidate['metadata'] = metadata;
    edited['candidateWorkspace'] = candidate;

    final ProtocolImportJob result = manager.replaceCandidateJson(
      'job-1',
      const JsonEncoder().convert(edited),
    );
    expect(result.candidateWorkspace.metadata.value.name, '修订后的草案');
    expect(result.validationReport, isNotNull);
    expect(manager.jobs.single.validationReport, isNotNull);
  });

  test(
    'unfinished review jobs persist separately from live workspaces',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CandidateWorkspaceCodec codec = CandidateWorkspaceCodec();
      final WorkspaceDraftManager manager = WorkspaceDraftManager();
      manager.importCandidateJson(codec.encode(validJob()));
      await manager.save();

      final WorkspaceDraftManager restored = WorkspaceDraftManager();
      await restored.load();
      expect(restored.drafts, isEmpty);
      expect(restored.jobs.single.id, 'job-1');
      expect(restored.jobs.single.status, ProtocolImportJobStatus.readyToApply);
    },
  );
}
