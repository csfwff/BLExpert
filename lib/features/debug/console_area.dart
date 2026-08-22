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

final RegExp _hexDigitPattern = RegExp(r'[0-9a-fA-F]');

String _formatHexBytes(String value) {
  final String compact = value
      .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
      .toUpperCase();
  final StringBuffer formatted = StringBuffer();
  for (int index = 0; index < compact.length; index++) {
    if (index > 0 && index.isEven) formatted.write(' ');
    formatted.write(compact[index]);
  }
  return formatted.toString();
}

int _hexDigitsBefore(String text, int offset) {
  final int safeOffset = offset.clamp(0, text.length);
  return _hexDigitPattern.allMatches(text.substring(0, safeOffset)).length;
}

int _formattedOffsetForHexDigits(String formatted, int hexDigits) {
  if (hexDigits <= 0) return 0;
  int seen = 0;
  for (int index = 0; index < formatted.length; index++) {
    if (_hexDigitPattern.hasMatch(formatted[index])) {
      seen++;
      if (seen == hexDigits) return index + 1;
    }
  }
  return formatted.length;
}

TextEditingValue _normalizeHexEditingValue(TextEditingValue value) {
  final String formatted = _formatHexBytes(value.text);
  final int baseDigits = _hexDigitsBefore(
    value.text,
    value.selection.baseOffset,
  );
  final int extentDigits = _hexDigitsBefore(
    value.text,
    value.selection.extentOffset,
  );
  return value.copyWith(
    text: formatted,
    selection: TextSelection(
      baseOffset: _formattedOffsetForHexDigits(formatted, baseDigits),
      extentOffset: _formattedOffsetForHexDigits(formatted, extentDigits),
      affinity: value.selection.affinity,
      isDirectional: value.selection.isDirectional,
    ),
    composing: TextRange.empty,
  );
}

class _HexByteInputFormatter extends TextInputFormatter {
  const _HexByteInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _normalizeHexEditingValue(newValue);
  }
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
      // Incoming frames can arrive several times per second. Animating every
      // append queues overlapping scroll animations and makes resizing the
      // surrounding workspace feel sticky.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  void _scrollToLatest({bool animate = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    final double target = _scrollController.position.maxScrollExtent;
    if ((target - _scrollController.position.pixels).abs() < 0.5) return;
    if (!animate) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
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
    final bool dark = AppTheme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      key: const ValueKey<String>('console-log-layout'),
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < _LogLine.compactBreakpoint;
        return Stack(
          children: <Widget>[
            Container(
              color: dark
                  ? const Color(0xFF0A111B)
                  : AppTheme.colorsOf(context).card,
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
                          compact: compact,
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
                    _scrollToLatest(animate: true);
                  },
                  icon: const Icon(AppIcons.verticalAlignBottom, size: 18),
                ),
              ),
          ],
        );
      },
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
    required this.directSend,
    required this.onDirectSendChanged,
    required this.onSend,
    required this.canSend,
    required this.sendDisabledReason,
    required this.sendPreview,
    required this.writeTarget,
    required this.characteristicsOpen,
    required this.onCharacteristicsVisibilityChanged,
    required this.inspectorOpen,
    required this.onInspectorVisibilityChanged,
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
  final bool directSend;
  final ValueChanged<bool> onDirectSendChanged;
  final VoidCallback onSend;
  final bool canSend;
  final String? sendDisabledReason;
  final _ConsoleSendPreview Function(
    String input,
    bool hexMode,
    bool directSend,
  )
  sendPreview;
  final String? writeTarget;
  final bool characteristicsOpen;
  final ValueChanged<bool> onCharacteristicsVisibilityChanged;
  final bool inspectorOpen;
  final ValueChanged<bool> onInspectorVisibilityChanged;
  final AppLocalizations l10n;
  final SessionLogRecord? selectedLog;
  final ValueChanged<SessionLogRecord> onLogSelected;
  final _ConsoleLogFilter logFilter;
  final ValueChanged<_ConsoleLogFilter> onLogFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<List<SessionLogRecord>> onExport;

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final dark = AppTheme.of(context).brightness == Brightness.dark;
    final bool multiPane = _DebugWorkspaceLayoutScope.multiPaneOf(context);
    return Column(
      children: <Widget>[
        LayoutBuilder(
          key: const ValueKey<String>('console-header-layout'),
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactHeader =
                constraints.maxWidth < _LogLine.compactBreakpoint;
            return Container(
              key: const ValueKey<String>('console-header'),
              height: 42,
              padding: EdgeInsets.fromLTRB(12, 0, compactHeader ? 12 : 8, 0),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF101824) : colors.card,
                border: Border(
                  bottom: BorderSide(color: AppTheme.colorsOf(context).border),
                ),
              ),
              child: Row(
                children: <Widget>[
                  if (multiPane && !compactHeader) ...<Widget>[
                    ToolIconButton(
                      key: const ValueKey<String>(
                        'console-characteristics-toggle',
                      ),
                      tooltip: characteristicsOpen ? '收起特征面板' : '展开特征面板',
                      onPressed: () => onCharacteristicsVisibilityChanged(
                        !characteristicsOpen,
                      ),
                      icon: Icon(
                        characteristicsOpen
                            ? AppIcons.chevronsLeft
                            : AppIcons.chevronsRight,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    AppIcons.terminalRounded,
                    size: 18,
                    color: colors.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.console,
                    style: AppTheme.textStylesOf(
                      context,
                    ).titleSmall.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  _ConsoleLogFilterBar(
                    filter: logFilter,
                    onChanged: onLogFilterChanged,
                    l10n: l10n,
                  ),
                  const SizedBox(width: 2),
                  if (!compactHeader)
                    Expanded(
                      child: Text(
                        l10n.retainedLogs(logs.length, discardedLogCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.textStylesOf(context).labelSmall,
                      ),
                    )
                  else
                    const Spacer(),
                  Row(
                    key: const ValueKey<String>('console-header-actions'),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ToolTooltip(
                        message: l10n.autoScroll,
                        showVisual: compactHeader,
                        child: ToolSwitch(
                          value: autoScroll,
                          onChanged: onAutoScrollChanged,
                          label: l10n.autoScroll,
                        ),
                      ),
                      if (!compactHeader) ...<Widget>[
                        Text(
                          l10n.autoScroll,
                          style: AppTheme.textStylesOf(context).bodySmall,
                        ),
                        const SizedBox(width: 4),
                      ],
                      ToolIconButton(
                        tooltip: l10n.exportLogs,
                        onPressed: logs.isEmpty ? null : () => onExport(logs),
                        icon: const Icon(AppIcons.downloadOutlined, size: 19),
                      ),
                      ToolIconButton(
                        tooltip: l10n.clear,
                        onPressed: onClear,
                        icon: const Icon(AppIcons.deleteSweep, size: 19),
                      ),
                      if (multiPane && !compactHeader) ...<Widget>[
                        const SizedBox(width: 4),
                        ToolIconButton(
                          key: const ValueKey<String>(
                            'console-inspector-toggle',
                          ),
                          tooltip: inspectorOpen ? '收起上下文面板' : '展开上下文面板',
                          onPressed: () =>
                              onInspectorVisibilityChanged(!inspectorOpen),
                          icon: Icon(
                            inspectorOpen
                                ? AppIcons.chevronsRight
                                : AppIcons.chevronsLeft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF101824) : colors.card,
            border: Border(
              bottom: BorderSide(color: AppTheme.colorsOf(context).border),
            ),
          ),
          child: ToolTextField(
            key: const ValueKey<String>('console-search'),
            controller: searchController,
            label: l10n.searchLogs,
            hintText: l10n.searchLogs,
            showLabel: false,
            onChanged: onSearchChanged,
            style: AppTheme.of(context).typography.xSmall,
            prefix: const Icon(AppIcons.search, size: 17),
            suffix: searchController.text.isEmpty
                ? null
                : ToolIconButton(
                    tooltip: l10n.clear,
                    touchSize: 24,
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(AppIcons.close, size: 16),
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
              directSend,
            );
            final String? inputReason =
                preview.error ??
                (input.text.trim().isEmpty ? l10n.emptyInput : null);
            final String? disabledReason = sendDisabledReason ?? inputReason;
            final bool effectiveCanSend = canSend && inputReason == null;
            final TextStyle compactControlText = TextStyle(
              fontSize: AppTheme.of(context).typography.xSmall.fontSize ?? 12,
            );
            return Container(
              key: const ValueKey<String>('console-send-area'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF101824) : colors.card,
                border: Border(
                  top: BorderSide(color: AppTheme.colorsOf(context).border),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    key: const ValueKey<String>('console-send-input-row'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 36),
                          child: ToolTextField(
                            key: const ValueKey<String>('console-input'),
                            controller: inputController,
                            label: l10n.inputPlaceholder,
                            hintText: l10n.inputPlaceholder,
                            showLabel: false,
                            focusNode: inputFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            inputFormatters: hexMode
                                ? const <TextInputFormatter>[
                                    _HexByteInputFormatter(),
                                  ]
                                : null,
                            onSubmitted: (_) => onSend(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            style: const TextStyle(
                              fontFamily: AppFonts.mono,
                              package: AppFonts.shadcnPackage,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: ToolButton.primary(
                          key: const ValueKey<String>('console-send-button'),
                          compact: true,
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          preservePrimaryColorWhenDisabled: true,
                          onPressed: effectiveCanSend ? onSend : null,
                          leading: const Icon(AppIcons.sendOutlined, size: 18),
                          child: Text(
                            l10n.sendData,
                            style: compactControlText,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final Widget sendControls = Row(
                            key: const ValueKey<String>(
                              'console-send-controls',
                            ),
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ToolSegmentedControl<bool>(
                                key: const ValueKey<String>(
                                  'console-mode-toggle',
                                ),
                                options: <ToolSegmentOption<bool>>[
                                  ToolSegmentOption(
                                    value: true,
                                    label: l10n.hexMode,
                                  ),
                                  ToolSegmentOption(
                                    value: false,
                                    label: l10n.textMode,
                                  ),
                                ],
                                value: hexMode,
                                onChanged: onModeChanged,
                                textStyle: compactControlText,
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(l10n.lineEnding, style: compactControlText),
                              const SizedBox(width: 4),
                              SizedBox(
                                key: const ValueKey<String>(
                                  'console-line-ending',
                                ),
                                height: 32,
                                width: 96,
                                child: ToolSelect<String>(
                                  value: 'none',
                                  options: <ToolSelectOption<String>>[
                                    ToolSelectOption(
                                      value: 'none',
                                      label: l10n.none,
                                    ),
                                    ToolSelectOption(
                                      value: 'lf',
                                      label: l10n.lf,
                                    ),
                                    ToolSelectOption(
                                      value: 'crlf',
                                      label: l10n.crlf,
                                    ),
                                  ],
                                  onChanged: (_) {},
                                  textStyle: compactControlText,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  itemPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  itemHeight: 28,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ToolTooltip(
                                message: l10n.directSendHint,
                                child: Row(
                                  key: const ValueKey<String>(
                                    'console-direct-send-toggle',
                                  ),
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    ToolSwitch(
                                      value: directSend,
                                      onChanged: onDirectSendChanged,
                                      label: l10n.directSend,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      l10n.directSend,
                                      style: compactControlText,
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                          final Widget sendMeta = _ConsoleSendMeta(
                            disabledReason: disabledReason,
                            preview: preview,
                            l10n: l10n,
                          );
                          final Widget targetStatus = _ConsoleWriteTargetStatus(
                            writeTarget: writeTarget,
                          );
                          if (constraints.maxWidth < 480) {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                sendControls,
                                if (disabledReason != null ||
                                    (preview.error == null &&
                                        preview.payloadLength != null))
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    child: sendMeta,
                                  ),
                                targetStatus,
                              ],
                            );
                          }
                          return Row(
                            children: <Widget>[
                              sendControls,
                              const SizedBox(width: 12),
                              Expanded(child: sendMeta),
                              const SizedBox(width: 12),
                              targetStatus,
                            ],
                          );
                        },
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

class _ConsoleSendMeta extends StatelessWidget {
  const _ConsoleSendMeta({
    required this.disabledReason,
    required this.preview,
    required this.l10n,
  });

  final String? disabledReason;
  final _ConsoleSendPreview preview;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final bool hasPreview =
        preview.error == null && preview.payloadLength != null;
    if (disabledReason == null && !hasPreview) {
      return const SizedBox(height: 32);
    }
    final TextStyle sansSmall = AppTheme.textStylesOf(
      context,
    ).bodySmall.copyWith(fontFamily: AppFonts.sans, package: null);
    final TextStyle sansLabel = AppTheme.textStylesOf(
      context,
    ).labelSmall.copyWith(fontFamily: AppFonts.sans, package: null);
    final TextStyle monoLabel = AppTheme.textStylesOf(context).labelSmall
        .copyWith(
          fontFamily: AppFonts.mono,
          package: AppFonts.shadcnPackage,
          color: colors.mutedForeground,
        );
    final List<Widget> children = <Widget>[];
    if (disabledReason != null) {
      children.add(
        Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                AppIcons.infoOutline,
                size: 15,
                color: colors.mutedForeground,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.sendUnavailable(disabledReason!),
                key: const ValueKey<String>('console-send-disabled-reason'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: sansSmall,
              ),
            ],
          ),
        ),
      );
    }
    if (hasPreview) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 12));
      children.add(
        Text(
          l10n.payloadLength(preview.payloadLength!),
          maxLines: 1,
          softWrap: false,
          style: sansLabel,
        ),
      );
      children.add(const SizedBox(width: 12));
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              preview.scriptPending
                  ? l10n.scriptPreviewUnavailable
                  : l10n.finalFrameLabel(preview.finalFrame!.length),
              maxLines: 1,
              softWrap: false,
              style: sansLabel,
            ),
            if (!preview.scriptPending)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _toHex(preview.finalFrame!),
                  maxLines: 1,
                  softWrap: false,
                  style: monoLabel,
                ),
              ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 32,
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _ConsoleWriteTargetStatus extends StatelessWidget {
  const _ConsoleWriteTargetStatus({required this.writeTarget});

  final String? writeTarget;

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final bool selected = writeTarget != null;
    final String label = selected
        ? '写入  ${_shortUuid(writeTarget!)}'
        : '未选择写入特征';
    return Semantics(
      label: label,
      child: Row(
        key: const ValueKey<String>('console-write-target-status'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              selected ? AppIcons.outputOutlined : AppIcons.warningAmber,
              size: 15,
              color: selected ? colors.chart2 : colors.destructive,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: AppTheme.textStylesOf(context).labelSmall.copyWith(
              fontFamily: AppFonts.mono,
              package: AppFonts.shadcnPackage,
              color: selected ? null : colors.destructive,
            ),
          ),
        ],
      ),
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
