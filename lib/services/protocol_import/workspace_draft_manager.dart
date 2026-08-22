import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/protocol_import/candidate_item.dart';
import '../../models/protocol_import/candidate_workspace.dart';
import '../../models/protocol_import/protocol_import_job.dart';
import '../../models/protocol_import/workspace_draft.dart';
import '../../models/workspace.dart';
import 'candidate_workspace_codec.dart';
import 'candidate_workspace_mapper.dart';
import 'protocol_candidate_validator.dart';

/// Stores P0 import jobs separately from the live workspace store. Applying a
/// draft returns a [Workspace] to the caller; this service never upserts it.
class WorkspaceDraftManager {
  WorkspaceDraftManager({
    this.preferences,
    CandidateWorkspaceCodec? codec,
    ProtocolCandidateValidator? validator,
    CandidateWorkspaceMapper? mapper,
  }) : _codec = codec ?? CandidateWorkspaceCodec(),
       _validator = validator ?? ProtocolCandidateValidator(),
       _mapper = mapper ?? CandidateWorkspaceMapper();

  static const String _storageKey = 'blexpert.protocol-import-drafts.v1';
  final CandidateWorkspaceCodec _codec;
  final ProtocolCandidateValidator _validator;
  final CandidateWorkspaceMapper _mapper;
  SharedPreferences? preferences;
  List<ProtocolImportJob> _jobs = <ProtocolImportJob>[];
  List<WorkspaceDraft> _drafts = <WorkspaceDraft>[];

  List<ProtocolImportJob> get jobs => List.unmodifiable(_jobs);
  List<WorkspaceDraft> get drafts => List.unmodifiable(_drafts);

  Future<void> load() async {
    preferences ??= await SharedPreferences.getInstance();
    final String? text = preferences!.getString(_storageKey);
    if (text == null || text.trim().isEmpty) {
      return;
    }
    final Object? decoded = json.decode(text);
    if (decoded is! Map) throw const FormatException('草案存储格式无效。');
    final Object? rawJobs = decoded['jobs'];
    final Object? rawDrafts = decoded['drafts'];
    if (rawJobs is! List || rawDrafts is! List) {
      throw const FormatException('草案存储缺少任务或工作区列表。');
    }
    _jobs = rawJobs
        .map((Object? item) => _codec.fromJson(_map(item, 'jobs')))
        .toList(growable: false);
    _drafts = rawDrafts
        .map((Object? item) {
          final Map<String, dynamic> json = _map(item, 'drafts');
          return WorkspaceDraft(
            id: _string(json['id'], 'drafts.id'),
            jobId: _string(json['jobId'], 'drafts.jobId'),
            createdAt: DateTime.parse(
              _string(json['createdAt'], 'drafts.createdAt'),
            ),
            workspace: Workspace.fromJson(
              _map(json['workspace'], 'drafts.workspace'),
            ),
          );
        })
        .toList(growable: false);
  }

  Future<void> save() async {
    preferences ??= await SharedPreferences.getInstance();
    final bool saved = await preferences!.setString(
      _storageKey,
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'version': 1,
        'jobs': _jobs.map((item) => item.toJson()).toList(),
        'drafts': _drafts.map((item) => item.toJson()).toList(),
      }),
    );
    if (!saved) throw StateError('无法保存协议导入草案。');
  }

  ProtocolImportJob importCandidateJson(String jsonText) {
    final ProtocolImportJob decoded = _codec.decode(jsonText);
    if (_jobs.any((item) => item.id == decoded.id)) {
      throw FormatException('候选草案任务 ID 已存在：${decoded.id}。');
    }
    final ProtocolImportJob validated = validate(decoded);
    _jobs = <ProtocolImportJob>[..._jobs, validated];
    return validated;
  }

  ProtocolImportJob validate(ProtocolImportJob job) {
    final report = _validator.validate(job);
    final bool blockingQuestion = job.questions.any(
      (item) => item.severity.name == 'blocking' && !item.isAnswered,
    );
    final bool pendingDangerous = job.candidateWorkspace.allItems.any(
      (item) =>
          item.riskLevel == CandidateRiskLevel.dangerous &&
          item.reviewStatus != CandidateReviewStatus.accepted,
    );
    final bool pendingNormal = job.candidateWorkspace.allItems.any(
      (item) =>
          item.reviewStatus == CandidateReviewStatus.pending ||
          item.reviewStatus == CandidateReviewStatus.edited,
    );
    final ProtocolImportJobStatus status = report.hasErrors || blockingQuestion
        ? ProtocolImportJobStatus.blocked
        : pendingDangerous || pendingNormal
        ? ProtocolImportJobStatus.underReview
        : ProtocolImportJobStatus.readyToApply;
    return job.copyWith(status: status, validationReport: report);
  }

  ProtocolImportJob updateReview(
    String jobId,
    String candidateId,
    CandidateReviewStatus reviewStatus,
  ) {
    final int index = _jobs.indexWhere((item) => item.id == jobId);
    if (index < 0) throw StateError('未找到导入任务：$jobId。');
    final ProtocolImportJob updated = _jobs[index].copyWith(
      candidateWorkspace: _reviewCandidate(
        _jobs[index].candidateWorkspace,
        candidateId,
        reviewStatus,
      ),
      clearValidationReport: true,
      status: ProtocolImportJobStatus.underReview,
    );
    final ProtocolImportJob validated = validate(updated);
    _jobs = <ProtocolImportJob>[..._jobs]..[index] = validated;
    return validated;
  }

  /// Replaces one review task with an edited full candidate JSON document.
  /// The task ID is stable so evidence links and persisted draft history remain
  /// traceable; every previous validation result is discarded and recomputed.
  ProtocolImportJob replaceCandidateJson(String jobId, String jsonText) {
    final int index = _jobs.indexWhere((item) => item.id == jobId);
    if (index < 0) throw StateError('未找到导入任务：$jobId。');
    final ProtocolImportJob edited = _codec.decode(jsonText);
    if (edited.id != jobId) {
      throw const FormatException('编辑候选必须保留原导入任务 ID。');
    }
    final ProtocolImportJob validated = validate(
      edited.copyWith(clearValidationReport: true),
    );
    _jobs = <ProtocolImportJob>[..._jobs]..[index] = validated;
    return validated;
  }

  WorkspaceDraft createDraft(String jobId) {
    final int index = _jobs.indexWhere((item) => item.id == jobId);
    if (index < 0) throw StateError('未找到导入任务：$jobId。');
    final ProtocolImportJob job = validate(_jobs[index]);
    if (job.status != ProtocolImportJobStatus.readyToApply) {
      throw StateError('候选草案尚未完成校验或审查。');
    }
    final DateTime now = DateTime.now().toUtc();
    final WorkspaceDraft draft = WorkspaceDraft(
      id: 'draft-${now.microsecondsSinceEpoch.toRadixString(36)}',
      jobId: job.id,
      createdAt: now,
      workspace: _mapper.mapToDraft(job),
    );
    _jobs = <ProtocolImportJob>[..._jobs]
      ..[index] = job.copyWith(status: ProtocolImportJobStatus.applied);
    _drafts = <WorkspaceDraft>[..._drafts, draft];
    return draft;
  }

  CandidateWorkspace _reviewCandidate(
    CandidateWorkspace workspace,
    String candidateId,
    CandidateReviewStatus status,
  ) {
    bool found = false;
    CandidateItem<T> update<T>(CandidateItem<T> item) {
      if (item.id != candidateId) return item;
      found = true;
      return item.copyWith(reviewStatus: status);
    }

    final CandidateWorkspace updated = workspace.copyWith(
      metadata: update(workspace.metadata),
      devices: workspace.devices.map(update).toList(growable: false),
      protocols: workspace.protocols.map(update).toList(growable: false),
      commands: workspace.commands.map(update).toList(growable: false),
      responseMappings: workspace.responseMappings
          .map(update)
          .toList(growable: false),
      scripts: workspace.scripts.map(update).toList(growable: false),
    );
    if (!found) {
      throw StateError('未找到候选项：$candidateId。');
    }
    return updated;
  }

  Map<String, dynamic> _map(Object? value, String path) {
    if (value is! Map) throw FormatException('$path 必须是对象。');
    return Map<String, dynamic>.from(value);
  }

  String _string(Object? value, String path) {
    if (value is! String || value.isEmpty) {
      throw FormatException('$path 必须是字符串。');
    }
    return value;
  }
}
