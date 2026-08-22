part of '../home/home_screen.dart';

extension on _HomeScreenState {
  Future<void> _importProtocolText() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? candidateJson = await _showProtocolTextImportDialog(l10n);
    if (candidateJson == null || !mounted) return;
    try {
      final ProtocolImportJob job = _workspaceDraftManager.importCandidateJson(
        candidateJson,
      );
      _persistWorkspaceDrafts();
      final String? completedJobId = await _reviewProtocolCandidate(job);
      if (completedJobId == null || !mounted) return;
      final draft = _workspaceDraftManager.createDraft(completedJobId);
      _persistWorkspaceDrafts();
      _activateImportedDraftWorkspace(draft.workspace);
      showToolToast(context, l10n.candidateDraftCreated);
    } on Object catch (error) {
      if (mounted) {
        showToolToast(
          context,
          l10n.protocolCandidateImportFailed(
            _protocolImportErrorMessage(error, l10n),
          ),
        );
      }
    }
  }

  Future<String?> _showProtocolTextImportDialog(AppLocalizations l10n) async {
    final ModelConnection? existing = _modelConnections.isEmpty
        ? null
        : _modelConnections.first;
    final DateTime now = DateTime.now().toUtc();
    final TextEditingController connectionName = TextEditingController(
      text: existing?.name ?? 'My OpenAI-compatible model',
    );
    final TextEditingController baseUrl = TextEditingController(
      text: existing?.baseUrl ?? 'https://api.openai.com/v1',
    );
    final TextEditingController model = TextEditingController(
      text: existing?.model ?? '',
    );
    final TextEditingController apiKey = TextEditingController();
    final TextEditingController documentName = TextEditingController(
      text: 'protocol.md',
    );
    final TextEditingController sourceText = TextEditingController();
    final ScrollController contentScrollController = ScrollController();
    String? error;
    bool isGenerating = false;
    try {
      return await showToolDialog<String>(
        context: context,
        builder: (BuildContext context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            void refreshDialogForInput() {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  setDialogState(() => error = null);
                }
              });
            }

            final double maxContentHeight =
                (MediaQuery.sizeOf(context).height - 220)
                    .clamp(240, 620)
                    .toDouble();
            final bool ready =
                connectionName.text.trim().isNotEmpty &&
                baseUrl.text.trim().isNotEmpty &&
                model.text.trim().isNotEmpty &&
                sourceText.text.trim().isNotEmpty;
            final bool existingKeyAllowed =
                existing != null && existing.id == _modelConnections.first.id;
            return ToolAlertDialog(
              icon: AppIcons.autoFix,
              title: l10n.protocolTextImport,
              content: SizedBox(
                width: 720,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxContentHeight),
                  child: ListView(
                    key: const ValueKey<String>('protocol-text-import-scroll'),
                    controller: contentScrollController,
                    shrinkWrap: true,
                    children: <Widget>[
                      Text(l10n.protocolTextImportHint),
                      const SizedBox(height: 12),
                      if (isGenerating || error != null) ...<Widget>[
                        Semantics(
                          liveRegion: true,
                          container: true,
                          child: Container(
                            key: const ValueKey<String>(
                              'protocol-import-status',
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isGenerating
                                  ? AppTheme.colorsOf(
                                      context,
                                    ).secondary.withValues(alpha: 0.56)
                                  : AppTheme.colorsOf(
                                      context,
                                    ).destructive.withValues(alpha: 0.12),
                              borderRadius: AppTheme.of(context).borderRadiusSm,
                              border: Border.all(
                                color: isGenerating
                                    ? AppTheme.colorsOf(context).border
                                    : AppTheme.colorsOf(context).destructive,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: isGenerating
                                      ? const ToolLoadingIcon()
                                      : Icon(
                                          AppIcons.warningAmber,
                                          size: 16,
                                          color: AppTheme.colorsOf(
                                            context,
                                          ).destructive,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isGenerating
                                        ? l10n.generatingCandidateHint
                                        : error!,
                                    style: TextStyle(
                                      color: isGenerating
                                          ? AppTheme.colorsOf(
                                              context,
                                            ).foreground
                                          : AppTheme.colorsOf(
                                              context,
                                            ).destructive,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ToolTextField(
                        controller: connectionName,
                        label: l10n.modelConnection,
                        helperText: '仅保存名称、服务地址与模型名；密钥不会写入工作区或导入草案。',
                        onChanged: (_) => refreshDialogForInput(),
                      ),
                      const SizedBox(height: 8),
                      ToolTextField(
                        controller: baseUrl,
                        label: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                        onChanged: (_) => refreshDialogForInput(),
                      ),
                      const SizedBox(height: 8),
                      ToolTextField(
                        key: const ValueKey<String>('protocol-import-model'),
                        controller: model,
                        label: 'Model',
                        hintText: 'gpt-4.1-mini',
                        onChanged: (_) => refreshDialogForInput(),
                      ),
                      const SizedBox(height: 8),
                      ToolTextField(
                        key: const ValueKey<String>('protocol-import-api-key'),
                        controller: apiKey,
                        label: l10n.apiKey,
                        obscureText: true,
                        helperText: existingKeyAllowed
                            ? '留空则使用此设备安全存储的已有 Key；Web 端仅保留到本次会话结束。'
                            : '保存在此设备的安全存储中；Web 端仅保留到本次会话结束。',
                        onChanged: (_) => refreshDialogForInput(),
                      ),
                      const shad.Divider(height: 24),
                      ToolTextField(
                        controller: documentName,
                        label: '来源名称',
                        hintText: 'protocol.md',
                      ),
                      const SizedBox(height: 8),
                      ToolTextField(
                        key: const ValueKey<String>(
                          'protocol-import-source-text',
                        ),
                        controller: sourceText,
                        label: l10n.protocolSourceText,
                        helperText:
                            '仅支持 TXT/Markdown。文档会发送给你选择的模型服务；请勿粘贴未获授权的敏感资料。',
                        minLines: 10,
                        maxLines: 16,
                        style: AppFonts.monoStyle,
                        onChanged: (_) => refreshDialogForInput(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                ToolButton.ghost(
                  onPressed: isGenerating ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ToolButton.primary(
                  key: const ValueKey<String>('protocol-text-generate-button'),
                  onPressed: !ready || isGenerating
                      ? null
                      : () async {
                          if (apiKey.text.trim().isEmpty &&
                              !existingKeyAllowed) {
                            setDialogState(() => error = '请提供 API Key。');
                            return;
                          }
                          final ModelConnection connection = ModelConnection(
                            id:
                                existing?.id ??
                                'model-${now.microsecondsSinceEpoch.toRadixString(36)}',
                            name: connectionName.text.trim(),
                            provider: ModelConnectionProvider.openAiCompatible,
                            baseUrl: baseUrl.text.trim(),
                            model: model.text.trim(),
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now,
                          );
                          final ProtocolTextDocument document =
                              ProtocolTextDocument(
                                name: documentName.text,
                                text: sourceText.text,
                                format:
                                    documentName.text
                                        .trim()
                                        .toLowerCase()
                                        .endsWith('.md')
                                    ? ProtocolDocumentFormat.markdown
                                    : ProtocolDocumentFormat.plainText,
                              );
                          setDialogState(() {
                            isGenerating = true;
                            error = null;
                          });
                          try {
                            await _saveModelConnection(connection, apiKey.text);
                            final ProtocolAiImportService service =
                                ProtocolAiImportService(
                                  _modelCredentialStore,
                                  OpenAiCompatibleAdapter(),
                                  onModelResponse:
                                      (
                                        ProtocolAiImportStage stage,
                                        Map<String, dynamic> response,
                                      ) => _addSystemLog(
                                        _formatProtocolModelResponse(
                                          stage,
                                          response,
                                        ),
                                      ),
                                );
                            final String candidateJson = await service
                                .createCandidateJson(
                                  connection: connection,
                                  document: document,
                                );
                            if (context.mounted) {
                              Navigator.pop(context, candidateJson);
                            }
                          } on Object catch (caughtError) {
                            if (context.mounted) {
                              _addSystemLog(
                                'AI 协议导入失败：${_protocolImportErrorMessage(caughtError, l10n)}',
                              );
                              setDialogState(() {
                                isGenerating = false;
                                error = _protocolImportErrorMessage(
                                  caughtError,
                                  l10n,
                                );
                              });
                              final Duration scrollDuration = AppMotion.resolve(
                                context,
                                AppMotion.standard,
                              );
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (contentScrollController.hasClients) {
                                  unawaited(
                                    contentScrollController.animateTo(
                                      0,
                                      duration: scrollDuration,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  );
                                }
                              });
                            }
                          }
                        },
                  leading: isGenerating ? const ToolLoadingIcon() : null,
                  child: Text(
                    isGenerating
                        ? l10n.generatingCandidate
                        : l10n.generateCandidate,
                  ),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      connectionName.dispose();
      baseUrl.dispose();
      model.dispose();
      apiKey.dispose();
      documentName.dispose();
      sourceText.dispose();
      contentScrollController.dispose();
    }
  }

  String _protocolImportErrorMessage(Object error, AppLocalizations l10n) {
    if (error is ModelProviderException) return error.message;
    if (error is FormatException) return error.message;
    return l10n.protocolImportFailed;
  }

  String _formatProtocolModelResponse(
    ProtocolAiImportStage stage,
    Map<String, dynamic> response,
  ) {
    final String stageName = switch (stage) {
      ProtocolAiImportStage.evidence => '证据提取',
      ProtocolAiImportStage.candidate => '候选生成',
    };
    return 'AI 协议导入 / $stageName模型返回（不含 API Key）：\n'
        '${const JsonEncoder.withIndent('  ').convert(response)}';
  }
}
