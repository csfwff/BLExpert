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
      key: const ValueKey<String>('quick-commands-panel'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: <Widget>[
        Padding(
          key: const ValueKey<String>('quick-commands-header'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.quickCommands,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (quickCommands.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
            child: Center(
              child: Text(
                l10n.noQuickCommands,
                style: AppTheme.textStylesOf(context).bodySmall,
              ),
            ),
          )
        else
          ...byGroup.entries.expand(
            (MapEntry<String, List<CommandDefinition>> entry) => <Widget>[
              if (entry.key != '-') ...<Widget>[
                const shad.Divider(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
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
  late final Map<String, List<TextEditingController>> _arrayControllers;
  late final ScrollController _frameScrollController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _frameScrollController = ScrollController();
    _controllers = <String, TextEditingController>{};
    _arrayControllers = <String, List<TextEditingController>>{};
    _createParameterControllers();
  }

  @override
  void didUpdateWidget(covariant _CommandTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command.id == widget.command.id &&
        oldWidget.command.parameters == widget.command.parameters) {
      return;
    }
    _disposeParameterControllers();
    _createParameterControllers();
    _validationError = null;
  }

  @override
  void dispose() {
    _frameScrollController.dispose();
    _disposeParameterControllers();
    super.dispose();
  }

  void _createParameterControllers() {
    for (final CommandParameter parameter in widget.command.parameters) {
      if (_isArrayParameter(parameter)) {
        _arrayControllers[parameter.key] = _arrayValues(parameter.defaultValue)
            .map((String value) => TextEditingController(text: value))
            .toList(growable: true);
      } else {
        _controllers[parameter.key] = TextEditingController(
          text: parameter.defaultValue,
        );
      }
    }
  }

  void _disposeParameterControllers() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    for (final List<TextEditingController> controllers
        in _arrayControllers.values) {
      for (final TextEditingController controller in controllers) {
        controller.dispose();
      }
    }
    _controllers.clear();
    _arrayControllers.clear();
  }

  Future<void> _send() async {
    final Map<String, String> values = <String, String>{
      for (final MapEntry<String, TextEditingController> entry
          in _controllers.entries)
        entry.key: entry.value.text.trim(),
      for (final MapEntry<String, List<TextEditingController>> entry
          in _arrayControllers.entries)
        entry.key: entry.value
            .map((TextEditingController controller) => controller.text.trim())
            .join(', '),
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
    final bool hasArrayParameters = command.parameters.any(_isArrayParameter);
    return Container(
      key: ValueKey<String>('quick-command-item-${command.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            Stack(
              alignment: Alignment.centerRight,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: shad.Scrollbar(
                    key: ValueKey<String>(
                      'quick-command-scrollbar-${command.id}',
                    ),
                    controller: _frameScrollController,
                    thumbVisibility: true,
                    thickness: _frameScrollbarThickness,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    child: SingleChildScrollView(
                      key: ValueKey<String>(
                        'quick-command-frame-scroll-${command.id}',
                      ),
                      controller: _frameScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(
                        6,
                        _frameRowTopInset,
                        44,
                        _frameScrollbarReservedHeight,
                      ),
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
                Positioned(
                  top: hasArrayParameters
                      ? _arraySendButtonTop
                      : hasParameters
                      ? _parameterLabelHeight + _frameCellGap
                      : 0,
                  right: _sendButtonRightInset,
                  child: ToolIconButton(
                    key: ValueKey<String>('quick-command-send-${command.id}'),
                    tooltip: '${widget.l10n.sendCommand} ${command.name}',
                    variant: ToolButtonVariant.primary,
                    touchSize: _sendButtonSize,
                    onPressed: sendEnabled ? _send : null,
                    icon: const Icon(AppIcons.sendOutlined, size: 16),
                  ),
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
                    fontSize: 11,
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
    if (_isArrayParameter(parameter)) {
      return _buildArrayParameterInput(parameter, label);
    }
    return Padding(
      padding: const EdgeInsets.only(right: _frameCellSpacing),
      child: SizedBox(
        key: ValueKey<String>(
          'quick-command-parameter-cell-${widget.command.id}-${parameter.key}',
        ),
        width: _parameterInputWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              key: ValueKey<String>(
                'quick-command-parameter-label-${widget.command.id}-${parameter.key}',
              ),
              width: double.infinity,
              height: _parameterLabelHeight,
              child: Center(
                child: ToolTooltip(
                  message: label,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _frameCellGap),
            SizedBox(
              height: _frameControlHeight,
              child: isChoice
                  ? ToolSelect<String>(
                      key: ValueKey<String>(
                        'quick-command-parameter-${widget.command.id}-${parameter.key}',
                      ),
                      value:
                          parameter.options.any(
                            (CommandParameterOption option) =>
                                option.value ==
                                _controllers[parameter.key]!.text,
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
                      textStyle: const TextStyle(fontSize: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 1,
                        vertical: 0,
                      ),
                      itemPadding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      itemHeight: 24,
                    )
                  : ToolTextField(
                      key: ValueKey<String>(
                        'quick-command-parameter-${widget.command.id}-${parameter.key}',
                      ),
                      controller: _controllers[parameter.key],
                      label: label,
                      showLabel: false,
                      keyboardType:
                          _usesNumericKeyboard(_scalarType(parameter.type))
                          ? TextInputType.number
                          : TextInputType.text,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 1,
                        vertical: 0,
                      ),
                      style: const TextStyle(fontSize: 12),
                      placeholderStyle: const TextStyle(fontSize: 12),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrayParameterInput(CommandParameter parameter, String label) {
    final List<TextEditingController> controllers =
        _arrayControllers[parameter.key]!;
    return Padding(
      padding: const EdgeInsets.only(right: _frameCellSpacing),
      child: SizedBox(
        height: _arrayFrameHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              key: ValueKey<String>(
                'quick-command-parameter-label-${widget.command.id}-${parameter.key}',
              ),
              height: _parameterLabelHeight,
              child: ToolTooltip(
                message: label,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: _frameCellGap),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (
                  int index = 0;
                  index < controllers.length;
                  index++
                ) ...<Widget>[
                  Column(
                    children: <Widget>[
                      SizedBox(
                        width: _parameterInputWidth,
                        height: _frameControlHeight,
                        child: ToolTextField(
                          key: ValueKey<String>(
                            'quick-command-array-parameter-${widget.command.id}-${parameter.key}-$index',
                          ),
                          controller: controllers[index],
                          label: '$label ${index + 1}',
                          showLabel: false,
                          keyboardType:
                              _usesNumericKeyboard(_scalarType(parameter.type))
                              ? TextInputType.number
                              : TextInputType.text,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 1,
                            vertical: 0,
                          ),
                          style: const TextStyle(fontSize: 12),
                          placeholderStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ToolIconButton(
                        key: ValueKey<String>(
                          'quick-command-array-remove-${widget.command.id}-${parameter.key}-$index',
                        ),
                        tooltip: '删除 $label ${index + 1}',
                        touchSize: _arrayActionSize,
                        onPressed: controllers.length > 1
                            ? () {
                                setState(() {
                                  final TextEditingController removed =
                                      controllers.removeAt(index);
                                  removed.dispose();
                                });
                              }
                            : null,
                        icon: const Icon(AppIcons.close, size: 13),
                      ),
                    ],
                  ),
                  const SizedBox(width: _frameCellSpacing),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: ToolIconButton(
                    key: ValueKey<String>(
                      'quick-command-array-add-${widget.command.id}-${parameter.key}',
                    ),
                    tooltip: '添加 $label',
                    touchSize: _arrayActionSize,
                    onPressed: () => setState(
                      () => controllers.add(TextEditingController()),
                    ),
                    icon: const Icon(AppIcons.add, size: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.only(right: _frameCellSpacing),
      child: SizedBox(
        width: 26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (showParameterLabelSpace) ...<Widget>[
              const SizedBox(height: _parameterLabelHeight),
              const SizedBox(height: _frameCellGap),
            ],
            SizedBox(
              height: _frameControlHeight,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    package: AppFonts.shadcnPackage,
                    fontSize: 11,
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
          const SizedBox(height: _parameterLabelHeight),
          const SizedBox(height: _frameCellGap),
        ],
        SizedBox(
          height: _frameControlHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: AppFonts.mono,
                package: AppFonts.shadcnPackage,
                fontSize: 11,
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
  CommandParameterType.int32 ||
  CommandParameterType.currentYear ||
  CommandParameterType.currentMonth ||
  CommandParameterType.currentDay ||
  CommandParameterType.currentHour ||
  CommandParameterType.currentMinute ||
  CommandParameterType.currentSecond => true,
  _ => false,
};

bool _isArrayParameter(CommandParameter parameter) =>
    parameter.isArray || parameter.type == CommandParameterType.uint8Array;

CommandParameterType _scalarType(CommandParameterType type) =>
    type == CommandParameterType.uint8Array ? CommandParameterType.uint8 : type;

const double _parameterLabelHeight = 16;
const double _frameCellGap = 2;
const double _frameControlHeight = 24;
const double _parameterInputWidth = 36;
const double _arrayActionSize = 20;
const double _arrayFrameHeight =
    _parameterLabelHeight +
    _frameCellGap +
    _frameControlHeight +
    _arrayActionSize;
const double _arraySendButtonTop = (_arrayFrameHeight - _sendButtonSize) / 2;
const double _frameCellSpacing = 4;
const double _sendButtonSize = 32;
const double _sendButtonRightInset = 12;
const double _frameRowTopInset = (_sendButtonSize - _frameControlHeight) / 2;
const double _frameScrollbarThickness = 4;
const double _frameScrollbarClearance = 4;
const double _frameScrollbarReservedHeight =
    _frameScrollbarThickness + _frameScrollbarClearance;

List<String> _arrayValues(String source) {
  final String normalized = source
      .trim()
      .replaceFirst(RegExp(r'^[\[\(]'), '')
      .replaceFirst(RegExp(r'[\]\)]$'), '')
      .trim();
  final List<String> values = normalized
      .split(RegExp(r'[,;\s]+'))
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? <String>[''] : values;
}
