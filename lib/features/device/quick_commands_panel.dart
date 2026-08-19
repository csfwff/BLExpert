part of '../home/home_screen.dart';

class _QuickCommandsPanel extends StatelessWidget {
  const _QuickCommandsPanel({
    required this.canSend,
    required this.onSend,
    required this.commands,
    required this.l10n,
  });

  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>) onSend;
  final List<CommandDefinition> commands;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<CommandDefinition> quickCommands = commands
        .where(
          (CommandDefinition command) =>
              command.enabled && command.isQuickAccess,
        )
        .toList(growable: false);
    final Map<String, List<CommandDefinition>> byGroup =
        <String, List<CommandDefinition>>{};
    for (final CommandDefinition command in quickCommands) {
      byGroup
          .putIfAbsent(command.group.isEmpty ? '-' : command.group, () {
            return <CommandDefinition>[];
          })
          .add(command);
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.quickCommands,
                style: AppTheme.textStylesOf(
                  context,
                ).titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (quickCommands.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text(l10n.noQuickCommands)),
          )
        else
          ...byGroup.entries.expand(
            (MapEntry<String, List<CommandDefinition>> entry) => <Widget>[
              if (entry.key != '-') ...<Widget>[
                const shad.Divider(height: 24),
                Text(
                  entry.key,
                  style: AppTheme.textStylesOf(context).labelLarge,
                ),
                const SizedBox(height: 6),
              ],
              ...entry.value.map(
                (CommandDefinition command) => _CommandTile(
                  command: command,
                  canSend: canSend,
                  onSend: onSend,
                  l10n: l10n,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CommandTile extends StatefulWidget {
  const _CommandTile({
    required this.command,
    required this.canSend,
    required this.onSend,
    required this.l10n,
  });

  final CommandDefinition command;
  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>) onSend;
  final AppLocalizations l10n;

  @override
  State<_CommandTile> createState() => _CommandTileState();
}

class _CommandTileState extends State<_CommandTile> {
  late final Map<String, TextEditingController> _controllers;
  late final ScrollController _frameScrollController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _frameScrollController = ScrollController();
    _controllers = <String, TextEditingController>{
      for (final CommandParameter parameter in widget.command.parameters)
        parameter.key: TextEditingController(text: parameter.defaultValue),
    };
  }

  @override
  void didUpdateWidget(covariant _CommandTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command.id == widget.command.id &&
        oldWidget.command.parameters == widget.command.parameters) {
      return;
    }
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    _controllers
      ..clear()
      ..addEntries(
        widget.command.parameters.map(
          (CommandParameter parameter) =>
              MapEntry<String, TextEditingController>(
                parameter.key,
                TextEditingController(text: parameter.defaultValue),
              ),
        ),
      );
    _validationError = null;
  }

  @override
  void dispose() {
    _frameScrollController.dispose();
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final Map<String, String> values = <String, String>{
      for (final MapEntry<String, TextEditingController> entry
          in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    try {
      CommandPayloadEncoder.encode(widget.command, values);
      setState(() => _validationError = null);
      await widget.onSend(widget.command, values);
    } on FormatException catch (error) {
      if (mounted) setState(() => _validationError = error.message);
    } catch (error) {
      if (mounted) setState(() => _validationError = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final CommandDefinition command = widget.command;
    final bool sendEnabled = widget.canSend && command.enabled;
    final bool hasParameters = command.parameters.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Semantics(
        label: '${command.name}：${command.payload}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: shad.Scrollbar(
                    controller: _frameScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _frameScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildFrameCells(
                          command,
                          showParameterLabels: hasParameters,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ToolIconButton(
                  tooltip: '${widget.l10n.sendCommand} ${command.name}',
                  variant: ToolButtonVariant.primary,
                  onPressed: sendEnabled ? _send : null,
                  icon: const Icon(AppIcons.sendOutlined, size: 18),
                ),
              ],
            ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _validationError!,
                  style: TextStyle(
                    color: AppTheme.colorsOf(context).destructive,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFrameCells(
    CommandDefinition command, {
    required bool showParameterLabels,
  }) {
    if (command.format == CommandPayloadFormat.text) {
      return <Widget>[
        _RawFrameCell(
          value: command.payload,
          showParameterLabelSpace: showParameterLabels,
        ),
      ];
    }
    final Map<String, CommandParameter> parameters = <String, CommandParameter>{
      for (final CommandParameter parameter in command.parameters)
        parameter.key: parameter,
    };
    final RegExp placeholder = RegExp(
      r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}',
    );
    final List<Widget> cells = <Widget>[];
    int position = 0;
    for (final RegExpMatch match in placeholder.allMatches(command.payload)) {
      cells.addAll(
        _fixedHexCells(
          command.payload.substring(position, match.start),
          showParameterLabelSpace: showParameterLabels,
        ),
      );
      final CommandParameter? parameter = parameters[match.group(1)!];
      if (parameter != null) cells.add(_buildParameterInput(parameter));
      position = match.end;
    }
    cells.addAll(
      _fixedHexCells(
        command.payload.substring(position),
        showParameterLabelSpace: showParameterLabels,
      ),
    );
    return cells.isEmpty
        ? <Widget>[
            _RawFrameCell(
              value: command.payload,
              showParameterLabelSpace: showParameterLabels,
            ),
          ]
        : cells;
  }

  List<Widget> _fixedHexCells(
    String source, {
    required bool showParameterLabelSpace,
  }) {
    final String compact = source.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    return <Widget>[
      for (int index = 0; index + 1 < compact.length; index += 2)
        _FixedFrameCell(
          value: compact.substring(index, index + 2).toUpperCase(),
          showParameterLabelSpace: showParameterLabelSpace,
        ),
    ];
  }

  Widget _buildParameterInput(CommandParameter parameter) {
    final String label = parameter.label.isEmpty
        ? parameter.key
        : parameter.label;
    final bool isChoice =
        parameter.type == CommandParameterType.enumValue &&
        parameter.options.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: isChoice ? 76 : _parameterInputWidth(parameter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ToolTooltip(
              message: label,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.textStylesOf(context).labelSmall,
              ),
            ),
            const SizedBox(height: 2),
            if (isChoice)
              ToolSelect<String>(
                value:
                    parameter.options.any(
                      (CommandParameterOption option) =>
                          option.value == _controllers[parameter.key]!.text,
                    )
                    ? _controllers[parameter.key]!.text
                    : parameter.options.first.value,
                options: parameter.options
                    .map(
                      (CommandParameterOption option) =>
                          ToolSelectOption<String>(
                            value: option.value,
                            label: option.label,
                          ),
                    )
                    .toList(growable: false),
                onChanged: (String value) =>
                    _controllers[parameter.key]!.text = value,
              )
            else
              ToolTextField(
                controller: _controllers[parameter.key],
                label: label,
                showLabel: false,
                keyboardType: _usesNumericKeyboard(parameter.type)
                    ? TextInputType.number
                    : TextInputType.text,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
          ],
        ),
      ),
    );
  }

  double _parameterInputWidth(CommandParameter parameter) =>
      switch (parameter.type) {
        CommandParameterType.uint32 || CommandParameterType.int32 => 62,
        CommandParameterType.uint16 || CommandParameterType.int16 => 52,
        CommandParameterType.ascii || CommandParameterType.utf8 => 88,
        CommandParameterType.hex => 52,
        _ => 38,
      };
}

class _FixedFrameCell extends StatelessWidget {
  const _FixedFrameCell({
    required this.value,
    required this.showParameterLabelSpace,
  });

  final String value;
  final bool showParameterLabelSpace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showParameterLabelSpace) ...<Widget>[
              const SizedBox(height: 16),
              const SizedBox(height: 2),
            ],
            SizedBox(
              height: 38,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.textStylesOf(context).bodySmall.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawFrameCell extends StatelessWidget {
  const _RawFrameCell({
    required this.value,
    required this.showParameterLabelSpace,
  });

  final String value;
  final bool showParameterLabelSpace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showParameterLabelSpace) ...<Widget>[
          const SizedBox(height: 16),
          const SizedBox(height: 2),
        ],
        SizedBox(
          height: 38,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.textStylesOf(context).bodySmall.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _usesNumericKeyboard(CommandParameterType type) => switch (type) {
  CommandParameterType.uint8 ||
  CommandParameterType.int8 ||
  CommandParameterType.uint16 ||
  CommandParameterType.int16 ||
  CommandParameterType.uint32 ||
  CommandParameterType.int32 => true,
  _ => false,
};
