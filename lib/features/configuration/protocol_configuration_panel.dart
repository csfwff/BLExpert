part of '../home/home_screen.dart';

enum _ProtocolMode { standard, script }

class _ProtocolConfigurationPanel extends StatefulWidget {
  const _ProtocolConfigurationPanel({
    required this.protocol,
    required this.scriptConfig,
    required this.onProtocolChanged,
    required this.onScriptConfigChanged,
    required this.runtimeAvailable,
    required this.l10n,
  });

  final ProtocolDefinition protocol;
  final ScriptConfig scriptConfig;
  final ValueChanged<ProtocolDefinition> onProtocolChanged;
  final ValueChanged<ScriptConfig> onScriptConfigChanged;
  final bool runtimeAvailable;
  final AppLocalizations l10n;

  @override
  State<_ProtocolConfigurationPanel> createState() =>
      _ProtocolConfigurationPanelState();
}

class _ProtocolConfigurationPanelState
    extends State<_ProtocolConfigurationPanel> {
  late final TextEditingController _protocolNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _beforeSendController;
  late final TextEditingController _afterReceiveController;
  late _ProtocolMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.scriptConfig.enabled
        ? _ProtocolMode.script
        : _ProtocolMode.standard;
    _protocolNameController = TextEditingController(text: widget.protocol.name);
    _descriptionController = TextEditingController(
      text: widget.protocol.description,
    );
    _beforeSendController = TextEditingController(
      text: widget.scriptConfig.beforeSendScript,
    );
    _afterReceiveController = TextEditingController(
      text: widget.scriptConfig.afterReceiveScript,
    );
  }

  @override
  void didUpdateWidget(covariant _ProtocolConfigurationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.protocol != widget.protocol) {
      _protocolNameController.text = widget.protocol.name;
      _descriptionController.text = widget.protocol.description;
    }
    if (oldWidget.scriptConfig != widget.scriptConfig) {
      _beforeSendController.text = widget.scriptConfig.beforeSendScript;
      _afterReceiveController.text = widget.scriptConfig.afterReceiveScript;
    }
  }

  @override
  void dispose() {
    _protocolNameController.dispose();
    _descriptionController.dispose();
    _beforeSendController.dispose();
    _afterReceiveController.dispose();
    super.dispose();
  }

  void _updateProtocol({
    List<ProtocolSegment>? sendSegments,
    List<ProtocolSegment>? receiveSegments,
  }) {
    widget.onProtocolChanged(
      widget.protocol.copyWith(
        name: _protocolNameController.text.trim(),
        description: _descriptionController.text.trim(),
        sendSegments: sendSegments,
        receiveSegments: receiveSegments,
      ),
    );
  }

  void _updateScript({bool? enabled}) {
    widget.onScriptConfigChanged(
      widget.scriptConfig.copyWith(
        enabled: enabled,
        beforeSendScript: _beforeSendController.text,
        afterReceiveScript: _afterReceiveController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Text(
          l10n.protocolProfiles,
          style: AppTheme.textStylesOf(
            context,
          ).titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ToolTextField(
          controller: _protocolNameController,
          label: l10n.protocolName,
          onChanged: (_) => _updateProtocol(),
        ),
        ToolTextField(
          controller: _descriptionController,
          label: l10n.description,
          onChanged: (_) => _updateProtocol(),
          minLines: 1,
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        ToolSegmentedControl<_ProtocolMode>(
          options: <ToolSegmentOption<_ProtocolMode>>[
            ToolSegmentOption(
              value: _ProtocolMode.standard,
              icon: const Icon(AppIcons.accountTree),
              label: l10n.standardProtocol,
            ),
            ToolSegmentOption(
              value: _ProtocolMode.script,
              icon: const Icon(AppIcons.codeOutlined),
              label: l10n.scriptProtocolMode,
            ),
          ],
          value: _mode,
          onChanged: (_ProtocolMode mode) {
            setState(() => _mode = mode);
            _updateScript(
              enabled: mode == _ProtocolMode.script && widget.runtimeAvailable,
            );
          },
        ),
        const SizedBox(height: 12),
        _ProtocolModeNote(mode: _mode, l10n: l10n),
        const SizedBox(height: 18),
        if (_mode == _ProtocolMode.standard)
          _StandardProtocolEditor(
            protocol: widget.protocol,
            onProtocolChanged: _updateProtocol,
            l10n: l10n,
          )
        else
          _ScriptProtocolEditor(
            config: widget.scriptConfig,
            beforeSendController: _beforeSendController,
            afterReceiveController: _afterReceiveController,
            runtimeAvailable: widget.runtimeAvailable,
            onChanged: _updateScript,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _ProtocolModeNote extends StatelessWidget {
  const _ProtocolModeNote({required this.mode, required this.l10n});

  final _ProtocolMode mode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool standard = mode == _ProtocolMode.standard;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: standard
            ? AppTheme.colorsOf(context).secondary
            : AppTheme.colorsOf(context).accent,
      ),
      child: Text(
        standard ? l10n.standardProtocolHint : l10n.scriptProtocolHint,
        style: AppTheme.textStylesOf(context).bodySmall,
      ),
    );
  }
}

class _StandardProtocolEditor extends StatelessWidget {
  const _StandardProtocolEditor({
    required this.protocol,
    required this.onProtocolChanged,
    required this.l10n,
  });

  final ProtocolDefinition protocol;
  final void Function({
    List<ProtocolSegment>? sendSegments,
    List<ProtocolSegment>? receiveSegments,
  })
  onProtocolChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _InlineProtocolSegmentSection(
          title: l10n.sendFrame,
          segments: protocol.sendSegments,
          l10n: l10n,
          onChanged: (List<ProtocolSegment> value) =>
              onProtocolChanged(sendSegments: value),
        ),
        const shad.Divider(height: 30),
        _InlineProtocolSegmentSection(
          title: l10n.receiveFrame,
          segments: protocol.receiveSegments,
          l10n: l10n,
          onChanged: (List<ProtocolSegment> value) =>
              onProtocolChanged(receiveSegments: value),
        ),
      ],
    );
  }
}

class _ScriptProtocolEditor extends StatelessWidget {
  const _ScriptProtocolEditor({
    required this.config,
    required this.beforeSendController,
    required this.afterReceiveController,
    required this.runtimeAvailable,
    required this.onChanged,
    required this.l10n,
  });

  final ScriptConfig config;
  final TextEditingController beforeSendController;
  final TextEditingController afterReceiveController;
  final bool runtimeAvailable;
  final void Function({bool? enabled}) onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _WorkspaceField(
          label: l10n.scriptRuntime,
          value: runtimeAvailable
              ? l10n.scriptEngineReady
              : l10n.scriptEngineUnavailable,
        ),
        Text(
          l10n.scriptMethods,
          style: AppTheme.textStylesOf(context).titleSmall,
        ),
        const SizedBox(height: 8),
        _ScriptMethodContract(
          title: 'beforeSend(context)',
          details: l10n.beforeSendContract,
          signature: 'context.payloadHex -> { frameHex, logs? }',
        ),
        const SizedBox(height: 8),
        _ScriptMethodContract(
          title: 'afterReceive(context)',
          details: l10n.afterReceiveContract,
          signature:
              'context.frameHex -> { payloadHex, cmdHex?, dataHex?, valid?, logs? }',
        ),
        const SizedBox(height: 12),
        _ScriptBuiltinLibrary(l10n: l10n),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ToolButton.outline(
            onPressed: () {
              beforeSendController.text = _defaultBeforeSendScript;
              afterReceiveController.text = _defaultAfterReceiveScript;
              onChanged();
            },
            leading: const Icon(AppIcons.autoFix),
            child: Text(l10n.loadProtocolSample),
          ),
        ),
        ToolTextField(
          controller: beforeSendController,
          label: l10n.beforeSendScript,
          minLines: 16,
          maxLines: 28,
          onChanged: (_) => onChanged(),
          style: AppFonts.monoStyle.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 14),
        ToolTextField(
          controller: afterReceiveController,
          label: l10n.afterReceiveScript,
          minLines: 16,
          maxLines: 28,
          onChanged: (_) => onChanged(),
          style: AppFonts.monoStyle.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _ScriptMethodContract extends StatelessWidget {
  const _ScriptMethodContract({
    required this.title,
    required this.details,
    required this.signature,
  });

  final String title;
  final String details;
  final String signature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppFonts.monoStyle),
          const SizedBox(height: 3),
          Text(details, style: AppTheme.textStylesOf(context).bodySmall),
          const SizedBox(height: 5),
          Text(
            signature,
            style: AppTheme.textStylesOf(
              context,
            ).labelSmall.merge(AppFonts.monoStyle),
          ),
        ],
      ),
    );
  }
}

class _ScriptBuiltinLibrary extends StatelessWidget {
  const _ScriptBuiltinLibrary({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<String> functions = <String>[
      'hexToBytes(value) / bytesToHex(value)',
      'uintToHex(value, byteLength, littleEndian)',
      'xorBytes(value, key)',
      'sum8(value)',
      'crc8(value, polynomial?, initial?)',
      'crc16Modbus(value)',
      'crc16Ccitt(value, initial?)',
      'crc32(value)',
      'md5Hex(value) / md5Text(value)',
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.colorsOf(context).muted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.scriptBuiltins,
            style: AppTheme.textStylesOf(context).titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.scriptBuiltinsHint,
            style: AppTheme.textStylesOf(context).bodySmall,
          ),
          const SizedBox(height: 8),
          ...functions.map(
            (String function) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                function,
                style: AppTheme.textStylesOf(
                  context,
                ).labelSmall.merge(AppFonts.monoStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineProtocolSegmentSection extends StatelessWidget {
  const _InlineProtocolSegmentSection({
    required this.title,
    required this.segments,
    required this.l10n,
    required this.onChanged,
  });

  final String title;
  final List<ProtocolSegment> segments;
  final AppLocalizations l10n;
  final ValueChanged<List<ProtocolSegment>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: AppTheme.textStylesOf(context).titleSmall,
              ),
            ),
            ToolIconButton(
              tooltip: l10n.newProtocolSegment,
              icon: const Icon(AppIcons.add, size: 18),
              onPressed: () => shad
                  .showDropdown<void>(
                    context: context,
                    widthConstraint: shad.PopoverConstraint.flexible,
                    builder: (BuildContext context) => shad.DropdownMenu(
                      children: ProtocolSegmentType.values
                          .map(
                            (ProtocolSegmentType type) => shad.MenuButton(
                              onPressed: (_) => onChanged(<ProtocolSegment>[
                                ...segments,
                                _newProtocolSegment(type),
                              ]),
                              child: Text(_segmentTypeLabel(type, l10n)),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  )
                  .future,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (segments.isEmpty)
          Text(
            l10n.noProtocolSegments,
            style: AppTheme.textStylesOf(context).bodySmall,
          )
        else
          ...List<Widget>.generate(segments.length, (int index) {
            final ProtocolSegment segment = segments[index];
            return _InlineProtocolSegmentTile(
              segment: segment,
              canMoveUp: index > 0,
              canMoveDown: index < segments.length - 1,
              l10n: l10n,
              onMoveUp: () {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments);
                final ProtocolSegment item = updated.removeAt(index);
                updated.insert(index - 1, item);
                onChanged(updated);
              },
              onMoveDown: () {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments);
                final ProtocolSegment item = updated.removeAt(index);
                updated.insert(index + 1, item);
                onChanged(updated);
              },
              onDelete: () {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments)..removeAt(index);
                onChanged(updated);
              },
              onChanged: (ProtocolSegment updatedSegment) {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments);
                updated[index] = updatedSegment;
                onChanged(updated);
              },
            );
          }),
      ],
    );
  }
}

class _InlineProtocolSegmentTile extends StatelessWidget {
  const _InlineProtocolSegmentTile({
    required this.segment,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.l10n,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onChanged,
  });

  final ProtocolSegment segment;
  final bool canMoveUp;
  final bool canMoveDown;
  final AppLocalizations l10n;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<ProtocolSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_segmentTypeLabel(segment.type, l10n)),
                const SizedBox(height: 6),
                ToolTextField(
                  initialValue: segment.label,
                  label: l10n.segmentLabel,
                  onChanged: (String value) =>
                      onChanged(segment.copyWith(label: value)),
                ),
                if (segment.type == ProtocolSegmentType.fixedHex)
                  ToolTextField(
                    initialValue: segment.fixedHex,
                    label: l10n.fixedHexSegment,
                    onChanged: (String value) =>
                        onChanged(segment.copyWith(fixedHex: value)),
                  ),
                if (segment.type == ProtocolSegmentType.length ||
                    segment.type == ProtocolSegmentType.sequence)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ToolTextField(
                          initialValue: '${segment.byteLength ?? 1}',
                          label: l10n.fieldByteLength,
                          keyboardType: TextInputType.number,
                          onChanged: (String value) => onChanged(
                            segment.copyWith(
                              byteLength: int.tryParse(value) ?? 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ToolSelect<ProtocolByteOrder>(
                          value:
                              segment.byteOrder ??
                              ProtocolByteOrder.littleEndian,
                          label: l10n.byteOrder,
                          options: ProtocolByteOrder.values
                              .map(
                                (ProtocolByteOrder item) =>
                                    ToolSelectOption<ProtocolByteOrder>(
                                      value: item,
                                      label: _byteOrderLabel(item, l10n),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (ProtocolByteOrder value) =>
                              onChanged(segment.copyWith(byteOrder: value)),
                        ),
                      ),
                    ],
                  ),
                if (segment.type == ProtocolSegmentType.length ||
                    segment.type == ProtocolSegmentType.checksum)
                  ToolSelect<ProtocolCalculationRange>(
                    value:
                        segment.calculationRange ??
                        ProtocolCalculationRange.payloadOnly,
                    label: l10n.calculationRange,
                    options: ProtocolCalculationRange.values
                        .map(
                          (ProtocolCalculationRange item) =>
                              ToolSelectOption<ProtocolCalculationRange>(
                                value: item,
                                label: _calculationRangeLabel(item, l10n),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (ProtocolCalculationRange value) =>
                        onChanged(segment.copyWith(calculationRange: value)),
                  ),
                if (segment.type == ProtocolSegmentType.checksum) ...<Widget>[
                  ToolSelect<ProtocolChecksumAlgorithm>(
                    value:
                        segment.checksumAlgorithm ??
                        ProtocolChecksumAlgorithm.crc16Modbus,
                    label: l10n.checksumAlgorithm,
                    options: ProtocolChecksumAlgorithm.values
                        .map(
                          (ProtocolChecksumAlgorithm item) =>
                              ToolSelectOption<ProtocolChecksumAlgorithm>(
                                value: item,
                                label: _checksumLabel(item, l10n),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (ProtocolChecksumAlgorithm value) =>
                        onChanged(segment.copyWith(checksumAlgorithm: value)),
                  ),
                  ToolSelect<ProtocolByteOrder>(
                    value: segment.byteOrder ?? ProtocolByteOrder.littleEndian,
                    label: l10n.byteOrder,
                    options: ProtocolByteOrder.values
                        .map(
                          (ProtocolByteOrder item) =>
                              ToolSelectOption<ProtocolByteOrder>(
                                value: item,
                                label: _byteOrderLabel(item, l10n),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (ProtocolByteOrder value) =>
                        onChanged(segment.copyWith(byteOrder: value)),
                  ),
                ],
              ],
            ),
          ),
          ToolIconButton(
            tooltip: l10n.moveUp,
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(AppIcons.arrowUp, size: 18),
          ),
          ToolIconButton(
            tooltip: l10n.moveDown,
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(AppIcons.arrowDown, size: 18),
          ),
          ToolIconButton(
            tooltip: l10n.deleteProtocolSegment,
            onPressed: onDelete,
            icon: const Icon(AppIcons.deleteOutline, size: 18),
          ),
        ],
      ),
    );
  }
}

String _checksumLabel(
  ProtocolChecksumAlgorithm algorithm,
  AppLocalizations l10n,
) => switch (algorithm) {
  ProtocolChecksumAlgorithm.xor => 'XOR',
  ProtocolChecksumAlgorithm.sum8 => 'SUM8',
  ProtocolChecksumAlgorithm.crc8 => 'CRC8',
  ProtocolChecksumAlgorithm.crc16Modbus => 'CRC16-MODBUS',
  ProtocolChecksumAlgorithm.crc16Ccitt => 'CRC16-CCITT',
  ProtocolChecksumAlgorithm.crc32 => 'CRC32',
};

String _byteOrderLabel(ProtocolByteOrder order, AppLocalizations l10n) =>
    order == ProtocolByteOrder.littleEndian ? 'Little-endian' : 'Big-endian';

String _calculationRangeLabel(
  ProtocolCalculationRange range,
  AppLocalizations l10n,
) => range == ProtocolCalculationRange.payloadOnly
    ? l10n.payloadRange
    : l10n.frameExcludingChecksum;

String _segmentTypeLabel(ProtocolSegmentType type, AppLocalizations l10n) =>
    switch (type) {
      ProtocolSegmentType.fixedHex => l10n.fixedHexSegment,
      ProtocolSegmentType.payload => l10n.payloadSegment,
      ProtocolSegmentType.length => l10n.lengthField,
      ProtocolSegmentType.sequence => l10n.sequenceField,
      ProtocolSegmentType.checksum => l10n.checksumField,
    };

ProtocolSegment _newProtocolSegment(ProtocolSegmentType type) {
  final String id = 'segment-${DateTime.now().microsecondsSinceEpoch}';
  return ProtocolSegment(
    id: id,
    type: type,
    label: '',
    byteLength:
        type == ProtocolSegmentType.length ||
            type == ProtocolSegmentType.sequence
        ? 1
        : null,
    byteOrder:
        type == ProtocolSegmentType.length ||
            type == ProtocolSegmentType.sequence ||
            type == ProtocolSegmentType.checksum
        ? ProtocolByteOrder.littleEndian
        : null,
    fixedHex: type == ProtocolSegmentType.fixedHex ? '00' : '',
    checksumAlgorithm: type == ProtocolSegmentType.checksum
        ? ProtocolChecksumAlgorithm.crc16Modbus
        : null,
    calculationRange:
        type == ProtocolSegmentType.length ||
            type == ProtocolSegmentType.checksum
        ? ProtocolCalculationRange.payloadOnly
        : null,
  );
}
