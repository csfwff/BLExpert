part of '../home/home_screen.dart';

class _ProtocolTextImportRequest {
  const _ProtocolTextImportRequest({
    required this.connection,
    required this.apiKey,
    required this.document,
  });

  final ModelConnection connection;
  final String apiKey;
  final ProtocolTextDocument document;
}

extension on _HomeScreenState {
  Future<void> _importProtocolText() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final _ProtocolTextImportRequest? request =
        await _showProtocolTextImportDialog(l10n);
    if (request == null || !mounted) return;
    try {
      await _saveModelConnection(request.connection, request.apiKey);
      if (!mounted) return;
      final ProtocolAiImportService service = ProtocolAiImportService(
        _modelCredentialStore,
        OpenAiCompatibleAdapter(),
      );
      final String candidateJson = await service.createCandidateJson(
        connection: request.connection,
        document: request.document,
      );
      if (!mounted) return;
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
      if (mounted) _showBluetoothError(error);
    }
  }

  Future<_ProtocolTextImportRequest?> _showProtocolTextImportDialog(
    AppLocalizations l10n,
  ) async {
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
    String? error;
    try {
      return await showToolDialog<_ProtocolTextImportRequest>(
        context: context,
        builder: (BuildContext context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
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
                  constraints: const BoxConstraints(maxHeight: 620),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      Text(l10n.protocolTextImportHint),
                      const SizedBox(height: 12),
                      ToolTextField(
                        controller: connectionName,
                        label: l10n.modelConnection,
                        helperText: '仅保存名称、服务地址与模型名；密钥不会写入工作区或导入草案。',
                        onChanged: (_) => setDialogState(() => error = null),
                      ),
                      const SizedBox(height: 8),
                      ToolTextField(
                        controller: baseUrl,
                        label: 'Base URL',
                        hintText: 'https://api.openai.com/v1',
                        onChanged: (_) => setDialogState(() => error = null),
                      ),
                      const SizedBox(height: 8),
                      ToolTextField(
                        controller: model,
                        label: 'Model',
                        hintText: 'gpt-4.1-mini',
                        onChanged: (_) => setDialogState(() => error = null),
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
                        onChanged: (_) => setDialogState(() => error = null),
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
                        onChanged: (_) => setDialogState(() => error = null),
                      ),
                      if (error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: AppTheme.colorsOf(context).destructive,
                            ),
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
                  child: Text(l10n.cancel),
                ),
                ToolButton.primary(
                  key: const ValueKey<String>('protocol-text-generate-button'),
                  onPressed: !ready
                      ? null
                      : () {
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
                          Navigator.pop(
                            context,
                            _ProtocolTextImportRequest(
                              connection: connection,
                              apiKey: apiKey.text,
                              document: ProtocolTextDocument(
                                name: documentName.text,
                                text: sourceText.text,
                                format:
                                    documentName.text
                                        .trim()
                                        .toLowerCase()
                                        .endsWith('.md')
                                    ? ProtocolDocumentFormat.markdown
                                    : ProtocolDocumentFormat.plainText,
                              ),
                            ),
                          );
                        },
                  child: Text(l10n.generateCandidate),
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
    }
  }
}
