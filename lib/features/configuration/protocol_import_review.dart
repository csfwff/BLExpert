part of '../home/home_screen.dart';

extension on _HomeScreenState {
  Future<void> _importProtocolCandidate() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<ProtocolImportJob> unfinishedJobs = _workspaceDraftManager.jobs
        .where(
          (ProtocolImportJob item) =>
              item.status != ProtocolImportJobStatus.applied,
        )
        .toList(growable: false);
    final TextEditingController controller = TextEditingController();
    ProtocolImportJob? preview;
    String? validationError;
    final _ProtocolCandidateImportDecision?
    decision = await showToolDialog<_ProtocolCandidateImportDecision>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            ToolAlertDialog(
              icon: AppIcons.autoFix,
              title: l10n.protocolCandidateImport,
              content: SizedBox(
                width: 680,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(l10n.protocolCandidateP0Notice),
                    const SizedBox(height: 12),
                    ToolTextField(
                      key: const ValueKey<String>(
                        'protocol-candidate-json-field',
                      ),
                      controller: controller,
                      label: l10n.protocolCandidateJson,
                      minLines: 8,
                      maxLines: 14,
                      style: AppFonts.monoStyle,
                      onChanged: (_) => setDialogState(() {
                        preview = null;
                        validationError = null;
                      }),
                    ),
                    if (unfinishedJobs.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        l10n.resumeCandidateReview,
                        style: AppTheme.textStylesOf(context).labelLarge,
                      ),
                      const SizedBox(height: 6),
                      for (final ProtocolImportJob job in unfinishedJobs)
                        ToolButton.outline(
                          onPressed: () => Navigator.pop(
                            context,
                            _ProtocolCandidateImportDecision.resume(job.id),
                          ),
                          compact: true,
                          height: 32,
                          child: Text(
                            job.candidateWorkspace.metadata.value.name,
                          ),
                        ),
                    ],
                    if (validationError != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: AppTheme.colorsOf(context).destructive,
                        ),
                      ),
                    ],
                    if (preview != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        '校验完成：${preview!.validationReport!.issues.length} 项问题，当前状态 ${_jobStatusLabel(preview!.status, l10n)}。',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.candidateRequiresReview,
                        style: AppTheme.textStylesOf(context).bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                ToolButton.ghost(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ToolButton.outline(
                  key: const ValueKey<String>(
                    'protocol-candidate-check-button',
                  ),
                  onPressed: controller.text.trim().isEmpty
                      ? null
                      : () {
                          try {
                            final decoded = CandidateWorkspaceCodec().decode(
                              controller.text,
                            );
                            setDialogState(() {
                              preview = _workspaceDraftManager.validate(
                                decoded,
                              );
                              validationError = null;
                            });
                          } on FormatException catch (error) {
                            setDialogState(() {
                              preview = null;
                              validationError = error.message;
                            });
                          }
                        },
                  child: Text(l10n.checkCandidate),
                ),
                ToolButton.primary(
                  key: const ValueKey<String>(
                    'protocol-candidate-review-button',
                  ),
                  onPressed: preview == null
                      ? null
                      : () => Navigator.pop(
                          context,
                          _ProtocolCandidateImportDecision.import(
                            controller.text,
                          ),
                        ),
                  child: Text(l10n.enterReview),
                ),
              ],
            ),
      ),
    );
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        controller.dispose,
      ),
    );
    if (decision == null || !mounted) {
      return;
    }
    try {
      final ProtocolImportJob job;
      if (decision.jobId != null) {
        job = _workspaceDraftManager.jobs.firstWhere(
          (ProtocolImportJob item) => item.id == decision.jobId,
        );
      } else {
        job = _workspaceDraftManager.importCandidateJson(decision.jsonText!);
        _persistWorkspaceDrafts();
      }
      final String? completedJobId = await _reviewProtocolCandidate(job);
      if (completedJobId == null || !mounted) {
        return;
      }
      final draft = _workspaceDraftManager.createDraft(completedJobId);
      _persistWorkspaceDrafts();
      _activateImportedDraftWorkspace(draft.workspace);
      showToolToast(context, l10n.candidateDraftCreated);
    } on FormatException catch (error) {
      if (mounted) {
        _showBluetoothError(error);
      }
    } on StateError catch (error) {
      if (mounted) {
        _showBluetoothError(error);
      }
    }
  }

  Future<String?> _reviewProtocolCandidate(ProtocolImportJob initialJob) {
    ProtocolImportJob current = initialJob;
    return showToolDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final AppLocalizations l10n = AppLocalizations.of(context)!;
          final issues =
              current.validationReport?.issues ?? const <ValidationIssue>[];
          final items = current.candidateWorkspace.allItems.toList();
          return ToolAlertDialog(
            icon: AppIcons.autoFix,
            title: l10n.reviewProtocolCandidate,
            content: SizedBox(
              width: 720,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 540),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    Text(
                      '状态：${_jobStatusLabel(current.status, l10n)}。${l10n.candidateCurrentWorkspaceSafe}',
                    ),
                    const SizedBox(height: 12),
                    for (final CandidateItem<Object> item in items)
                      _ProtocolCandidateReviewTile(
                        item: item,
                        issueCount: issues
                            .where((issue) => issue.candidateId == item.id)
                            .length,
                        onAccepted: () => setDialogState(() {
                          current = _workspaceDraftManager.updateReview(
                            current.id,
                            item.id,
                            CandidateReviewStatus.accepted,
                          );
                          _persistWorkspaceDrafts();
                        }),
                        onRejected: () => setDialogState(() {
                          current = _workspaceDraftManager.updateReview(
                            current.id,
                            item.id,
                            CandidateReviewStatus.rejected,
                          );
                          _persistWorkspaceDrafts();
                        }),
                      ),
                    if (issues.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        '校验结果（${issues.length}）',
                        style: AppTheme.textStylesOf(context).labelLarge,
                      ),
                      const SizedBox(height: 4),
                      for (final issue in issues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '[${issue.severity.name}] ${issue.message}',
                            style: AppTheme.textStylesOf(context).bodySmall,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              ToolButton.ghost(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.reviewLater),
              ),
              ToolButton.outline(
                onPressed: () => setDialogState(() {
                  current = _workspaceDraftManager.validate(current);
                  _persistWorkspaceDrafts();
                }),
                child: Text(l10n.revalidate),
              ),
              ToolButton.outline(
                onPressed: () async {
                  final ProtocolImportJob? edited =
                      await _editProtocolCandidateJson(current);
                  if (edited != null) {
                    setDialogState(() => current = edited);
                  }
                },
                child: Text(l10n.editCandidateJson),
              ),
              ToolButton.primary(
                key: const ValueKey<String>('protocol-candidate-create-draft'),
                onPressed:
                    current.status == ProtocolImportJobStatus.readyToApply
                    ? () => Navigator.pop(context, current.id)
                    : null,
                child: Text(l10n.createDraftWorkspace),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<ProtocolImportJob?> _editProtocolCandidateJson(
    ProtocolImportJob job,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController(
      text: CandidateWorkspaceCodec().encode(job),
    );
    final ProtocolImportJob? result = await showToolDialog<ProtocolImportJob>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          String? error;
          return ToolAlertDialog(
            icon: AppIcons.autoFix,
            title: l10n.editCandidateJson,
            content: SizedBox(
              width: 680,
              child: ToolTextField(
                controller: controller,
                label: l10n.protocolCandidateJson,
                minLines: 10,
                maxLines: 16,
                style: AppFonts.monoStyle,
                onChanged: (_) => setDialogState(() => error = null),
                errorText: error,
              ),
            ),
            actions: <Widget>[
              ToolButton.ghost(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ToolButton.primary(
                onPressed: () {
                  try {
                    final ProtocolImportJob updated = _workspaceDraftManager
                        .replaceCandidateJson(job.id, controller.text);
                    _persistWorkspaceDrafts();
                    Navigator.pop(context, updated);
                  } on FormatException catch (exception) {
                    setDialogState(() => error = exception.message);
                  }
                },
                child: Text(l10n.updateCandidate),
              ),
            ],
          );
        },
      ),
    );
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        controller.dispose,
      ),
    );
    return result;
  }

  String _jobStatusLabel(
    ProtocolImportJobStatus status,
    AppLocalizations l10n,
  ) => switch (status) {
    ProtocolImportJobStatus.created => l10n.candidateStatusCreated,
    ProtocolImportJobStatus.validated => l10n.candidateStatusCreated,
    ProtocolImportJobStatus.underReview => l10n.candidateStatusReview,
    ProtocolImportJobStatus.blocked => l10n.candidateStatusBlocked,
    ProtocolImportJobStatus.readyToApply => l10n.candidateStatusReady,
    ProtocolImportJobStatus.applied => l10n.candidateStatusApplied,
  };
}

class _ProtocolCandidateReviewTile extends StatelessWidget {
  const _ProtocolCandidateReviewTile({
    required this.item,
    required this.issueCount,
    required this.onAccepted,
    required this.onRejected,
  });

  final CandidateItem<Object> item;
  final int issueCount;
  final VoidCallback onAccepted;
  final VoidCallback onRejected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      key: ValueKey<String>('protocol-candidate-item-${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.colorsOf(context).border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${item.id} · ${item.value.runtimeType}'),
          const SizedBox(height: 3),
          Text(
            '置信度 ${item.confidence.name} · 风险 ${item.riskLevel.name} · $issueCount 项校验结果',
            style: AppTheme.textStylesOf(context).bodySmall,
          ),
          if (item.evidenceRefs.isNotEmpty)
            Text(
              l10n.candidateEvidence(item.evidenceRefs.join('、')),
              style: AppTheme.textStylesOf(context).bodySmall,
            ),
          if (item.assumptions.isNotEmpty)
            Text(
              l10n.candidateAssumptions(item.assumptions.join('；')),
              style: AppTheme.textStylesOf(context).bodySmall,
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(child: Text('审查：${item.reviewStatus.name}')),
              ToolButton.ghost(
                onPressed: onRejected,
                compact: true,
                height: 30,
                child: Text(l10n.candidateReject),
              ),
              const SizedBox(width: 6),
              ToolButton.primary(
                onPressed: onAccepted,
                compact: true,
                height: 30,
                child: Text(l10n.candidateAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
