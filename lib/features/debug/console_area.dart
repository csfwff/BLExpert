part of '../home/home_screen.dart';

class _ConsoleSendPreview {
  const _ConsoleSendPreview({
    this.payloadLength,
    this.finalFrame,
    this.error,
    this.scriptPending = false,
  });

  final int? payloadLength;
  final List<int>? finalFrame;
  final String? error;
  final bool scriptPending;
}

class _ConsoleLogView extends StatefulWidget {
  const _ConsoleLogView({
    required this.logs,
    required this.autoScroll,
    required this.selectedLog,
    required this.onLogSelected,
    required this.onJumpToLatest,
    required this.l10n,
  });

  final List<SessionLogRecord> logs;
  final bool autoScroll;
  final SessionLogRecord? selectedLog;
  final ValueChanged<SessionLogRecord> onLogSelected;
  final VoidCallback onJumpToLatest;
  final AppLocalizations l10n;

  @override
  State<_ConsoleLogView> createState() => _ConsoleLogViewState();
}

class _ConsoleLogViewState extends State<_ConsoleLogView> {
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToLatest = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final bool shouldShow =
        _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels >
        32;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  @override
  void didUpdateWidget(covariant _ConsoleLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  void _scrollToLatest() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        Container(
          color: dark
              ? const Color(0xFF0A111B)
              : Theme.of(context).colorScheme.surface,
          child: widget.logs.isEmpty
              ? Center(child: Text(widget.l10n.noMatchingLogs))
              : ListView.builder(
                  key: const ValueKey<String>('console-log-list'),
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.all(14),
                  itemCount: widget.logs.length,
                  itemBuilder: (_, index) {
                    final SessionLogRecord entry =
                        widget.logs[widget.logs.length - index - 1];
                    return _LogLine(
                      entry: entry,
                      l10n: widget.l10n,
                      selected: identical(entry, widget.selectedLog),
                      onTap: () => widget.onLogSelected(entry),
                    );
                  },
                ),
        ),
        if (_showJumpToLatest)
          Positioned(
            right: 16,
            bottom: 16,
            child: ToolIconButton(
              key: const ValueKey<String>('console-jump-latest'),
              tooltip: widget.l10n.backToLatest,
              variant: ToolButtonVariant.secondary,
              onPressed: () {
                widget.onJumpToLatest();
                _scrollToLatest();
              },
              icon: const Icon(Icons.vertical_align_bottom, size: 18),
            ),
          ),
      ],
    );
  }
}

class _ConsoleArea extends StatelessWidget {
  const _ConsoleArea({
    required this.logs,
    required this.discardedLogCount,
    required this.autoScroll,
    required this.onClear,
    required this.onAutoScrollChanged,
    required this.inputController,
    required this.searchController,
    required this.inputFocusNode,
    required this.hexMode,
    required this.onModeChanged,
    required this.onSend,
    required this.canSend,
    required this.sendDisabledReason,
    required this.sendPreview,
    required this.writeTarget,
    required this.l10n,
    required this.selectedLog,
    required this.onLogSelected,
    required this.logFilter,
    required this.onLogFilterChanged,
    required this.onSearchChanged,
    required this.onExport,
  });
  final List<SessionLogRecord> logs;
  final int discardedLogCount;
  final bool autoScroll;
  final VoidCallback onClear;
  final ValueChanged<bool> onAutoScrollChanged;
  final TextEditingController inputController;
  final TextEditingController searchController;
  final FocusNode inputFocusNode;
  final bool hexMode;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSend;
  final bool canSend;
  final String? sendDisabledReason;
  final _ConsoleSendPreview Function(String input, bool hexMode) sendPreview;
  final String? writeTarget;
  final AppLocalizations l10n;
  final SessionLogRecord? selectedLog;
  final ValueChanged<SessionLogRecord> onLogSelected;
  final _ConsoleLogFilter logFilter;
  final ValueChanged<_ConsoleLogFilter> onLogFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<List<SessionLogRecord>> onExport;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bool compactHeader = MediaQuery.sizeOf(context).width < 680;
    return Column(
      children: <Widget>[
        Container(
          height: 42,
          // Reserve space for the floating Inspector control at the top-right.
          padding: EdgeInsets.fromLTRB(12, 0, compactHeader ? 12 : 60, 0),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF101824) : colors.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.terminal_rounded, size: 18, color: colors.secondary),
              const SizedBox(width: 8),
              Text(
                l10n.console,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _ConsoleLogFilterBar(
                filter: logFilter,
                onChanged: onLogFilterChanged,
                l10n: l10n,
              ),
              const SizedBox(width: 2),
              if (!compactHeader) ...<Widget>[
                Flexible(
                  child: Text(
                    l10n.retainedLogs(logs.length, discardedLogCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  writeTarget == null
                      ? Icons.warning_amber_outlined
                      : Icons.output_outlined,
                  size: 15,
                  color: writeTarget == null ? colors.error : colors.tertiary,
                ),
                const SizedBox(width: 5),
                Text(
                  writeTarget == null
                      ? '未选择写入特征'
                      : '写入  ${_shortUuid(writeTarget!)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: writeTarget == null
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
              const Spacer(),
              Tooltip(
                message: l10n.autoScroll,
                child: ToolSwitch(
                  value: autoScroll,
                  onChanged: onAutoScrollChanged,
                  label: l10n.autoScroll,
                ),
              ),
              if (!compactHeader) ...<Widget>[
                Text(
                  l10n.autoScroll,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
              ],
              ToolIconButton(
                tooltip: l10n.exportLogs,
                onPressed: logs.isEmpty ? null : () => onExport(logs),
                icon: const Icon(Icons.download_outlined, size: 19),
              ),
              ToolIconButton(
                tooltip: l10n.clear,
                onPressed: onClear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 19),
              ),
            ],
          ),
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF101824) : colors.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: ToolTextField(
            key: const ValueKey<String>('console-search'),
            controller: searchController,
            label: l10n.searchLogs,
            hintText: l10n.searchLogs,
            showLabel: false,
            onChanged: onSearchChanged,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            prefix: const Icon(Icons.search, size: 17),
            suffix: searchController.text.isEmpty
                ? null
                : ToolIconButton(
                    tooltip: l10n.clear,
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close, size: 16),
                  ),
          ),
        ),
        Expanded(
          child: _ConsoleLogView(
            logs: logs,
            autoScroll: autoScroll,
            selectedLog: selectedLog,
            onLogSelected: onLogSelected,
            onJumpToLatest: () => onAutoScrollChanged(true),
            l10n: l10n,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: inputController,
          builder: (BuildContext context, TextEditingValue input, _) {
            final _ConsoleSendPreview preview = sendPreview(
              input.text,
              hexMode,
            );
            final String? inputReason =
                preview.error ??
                (input.text.trim().isEmpty ? l10n.emptyInput : null);
            final String? disabledReason = sendDisabledReason ?? inputReason;
            final bool effectiveCanSend = canSend && inputReason == null;
            return Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF101824) : colors.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: ToolTextField(
                          key: const ValueKey<String>('console-input'),
                          controller: inputController,
                          label: l10n.inputPlaceholder,
                          hintText: l10n.inputPlaceholder,
                          showLabel: false,
                          focusNode: inputFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => onSend(),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: ToolButton.primary(
                          key: const ValueKey<String>('console-send-button'),
                          onPressed: effectiveCanSend ? onSend : null,
                          leading: const Icon(Icons.send_outlined, size: 18),
                          child: Text(
                            l10n.sendData,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (disabledReason != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Semantics(
                      liveRegion: true,
                      container: true,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.info_outline,
                              size: 15,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                l10n.sendUnavailable(disabledReason),
                                key: const ValueKey<String>(
                                  'console-send-disabled-reason',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (preview.error == null &&
                      preview.payloadLength != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 3,
                        children: <Widget>[
                          Text(
                            l10n.payloadLength(preview.payloadLength!),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            preview.scriptPending
                                ? l10n.scriptPreviewUnavailable
                                : l10n.finalFramePreview(
                                    preview.finalFrame!.length,
                                    _toHex(preview.finalFrame!),
                                  ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      ToolSegmentedControl<bool>(
                        key: const ValueKey<String>('console-mode-toggle'),
                        options: <ToolSegmentOption<bool>>[
                          ToolSegmentOption(value: true, label: l10n.hexMode),
                          ToolSegmentOption(value: false, label: l10n.textMode),
                        ],
                        value: hexMode,
                        onChanged: onModeChanged,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.lineEnding,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        key: const ValueKey<String>('console-line-ending'),
                        height: 36,
                        width: 84,
                        child: ToolSelect<String>(
                          value: 'none',
                          options: <ToolSelectOption<String>>[
                            ToolSelectOption(value: 'none', label: l10n.none),
                            ToolSelectOption(value: 'lf', label: l10n.lf),
                            ToolSelectOption(value: 'crlf', label: l10n.crlf),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

String _serviceTitle(String serviceId, AppLocalizations l10n) {
  return switch (serviceId.toLowerCase()) {
    '00001800-0000-1000-8000-00805f9b34fb' =>
      '${l10n.genericAccess}  $serviceId',
    '00001801-0000-1000-8000-00805f9b34fb' =>
      '${l10n.genericAttribute}  $serviceId',
    _ => '${l10n.service} $serviceId',
  };
}

String? _characteristicTitle(String characteristicId, AppLocalizations l10n) {
  return switch (characteristicId.toLowerCase()) {
    '00002a00-0000-1000-8000-00805f9b34fb' => l10n.deviceName,
    '00002a05-0000-1000-8000-00805f9b34fb' => l10n.serviceChanged,
    _ => null,
  };
}
