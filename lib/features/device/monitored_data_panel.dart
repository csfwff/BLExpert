part of '../home/home_screen.dart';

class _MonitoredFieldDefinition {
  const _MonitoredFieldDefinition({required this.mapping, required this.field});
  final ResponseMapping mapping;
  final DataField field;
}

class _MonitoredFieldValue {
  const _MonitoredFieldValue({
    required this.responseName,
    required this.commandHex,
    required this.value,
    required this.timestamp,
  });
  final String responseName;
  final String commandHex;
  final ParsedDataValue value;
  final DateTime timestamp;
}

String _monitorFieldId(ResponseMapping mapping, String fieldKey) =>
    '${mapping.id}:$fieldKey';

String _formatCommandSendLog(
  CommandDefinition command,
  Map<String, String> values,
  AppLocalizations l10n,
) {
  final String parameters = command.parameters
      .map((CommandParameter parameter) {
        final String label = parameter.label.isEmpty
            ? parameter.key
            : parameter.label;
        final String value = values[parameter.key] ?? parameter.defaultValue;
        return '$label=$value';
      })
      .join(', ');
  return l10n.commandLog(command.name, parameters.isEmpty ? '--' : parameters);
}

String _formatParsedResponseLog(
  ParsedResponse response,
  AppLocalizations l10n,
) {
  final String values = response.values
      .map(
        (ParsedDataValue value) =>
            '${value.label}=${value.displayValue}${value.unit.isEmpty ? '' : value.unit}',
      )
      .join(', ');
  return l10n.responseLog(
    response.mapping.name,
    response.commandHex,
    values.isEmpty ? '--' : values,
  );
}

class _CommandsAndDataPanel extends StatelessWidget {
  const _CommandsAndDataPanel({
    required this.canSend,
    required this.onSend,
    required this.commands,
    required this.responseMappings,
    required this.monitoredValues,
    required this.l10n,
  });
  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>) onSend;
  final List<CommandDefinition> commands;
  final List<ResponseMapping> responseMappings;
  final Map<String, _MonitoredFieldValue> monitoredValues;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _QuickCommandsPanel(
            canSend: canSend,
            onSend: onSend,
            commands: commands,
            l10n: l10n,
          ),
        ),
        const shad.Divider(height: 1),
        Expanded(
          flex: 4,
          child: _MappedDataPanel(
            mappings: responseMappings,
            monitoredValues: monitoredValues,
            l10n: l10n,
          ),
        ),
      ],
    );
  }
}

class _MappedDataPanel extends StatelessWidget {
  const _MappedDataPanel({
    required this.mappings,
    required this.monitoredValues,
    required this.l10n,
  });
  final List<ResponseMapping> mappings;
  final Map<String, _MonitoredFieldValue> monitoredValues;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<_MonitoredFieldDefinition> fields = <_MonitoredFieldDefinition>[
      for (final ResponseMapping mapping in mappings)
        for (final DataField field in mapping.fields)
          if (field.visibleInDataPanel)
            _MonitoredFieldDefinition(mapping: mapping, field: field),
    ];
    return Container(
      key: const ValueKey<String>('mapped-data-panel'),
      padding: const EdgeInsets.all(8),
      color: AppTheme.colorsOf(context).muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.mappedData,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (fields.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  l10n.noMappedFields,
                  style: AppTheme.textStylesOf(context).bodySmall,
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                key: const ValueKey<String>('mapped-data-grid'),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 132,
                  mainAxisExtent: 56,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: fields.length,
                itemBuilder: (BuildContext context, int index) {
                  final _MonitoredFieldDefinition definition = fields[index];
                  final _MonitoredFieldValue? latest =
                      monitoredValues[_monitorFieldId(
                        definition.mapping,
                        definition.field.key,
                      )];
                  return _MappedDataCell(
                    key: ValueKey<String>(
                      'mapped-data-cell-${definition.mapping.id}-${definition.field.key}',
                    ),
                    definition: definition,
                    latest: latest,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MappedDataCell extends StatefulWidget {
  const _MappedDataCell({
    super.key,
    required this.definition,
    required this.latest,
  });

  final _MonitoredFieldDefinition definition;
  final _MonitoredFieldValue? latest;

  @override
  State<_MappedDataCell> createState() => _MappedDataCellState();
}

class _MappedDataCellState extends State<_MappedDataCell> {
  static const Duration _transitionDuration = Duration(milliseconds: 180);
  bool _highlighted = false;

  @override
  void didUpdateWidget(covariant _MappedDataCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latest == null) {
      if (_highlighted) setState(() => _highlighted = false);
      return;
    }
    if (_monitoredValueChanged(oldWidget.latest, widget.latest)) {
      if (!_highlighted) setState(() => _highlighted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _MonitoredFieldDefinition definition = widget.definition;
    final _MonitoredFieldValue? latest = widget.latest;
    final bool isArray = latest?.value.isArray ?? false;
    final String name = definition.field.label.isEmpty
        ? definition.field.key
        : definition.field.label;
    final String value = latest == null
        ? '--'
        : '${latest.value.displayValue}${latest.value.unit.isEmpty ? '' : ' ${latest.value.unit}'}';
    final String source =
        '${definition.mapping.name} | CMD ${definition.mapping.commandHex}';
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final Widget dataCard = AnimatedContainer(
      duration: _transitionDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: _highlighted
            ? colors.accent.withValues(alpha: 0.5)
            : colors.card,
        border: Border.all(
          color: _highlighted ? colors.accentForeground : colors.border,
        ),
        borderRadius: AppTheme.of(context).borderRadiusSm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            key: ValueKey<String>(
              'mapped-data-value-${definition.mapping.id}-${definition.field.key}',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.mono,
              package: AppFonts.shadcnPackage,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            key: ValueKey<String>(
              'mapped-data-name-${definition.mapping.id}-${definition.field.key}',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: colors.mutedForeground),
          ),
        ],
      ),
    );
    return Semantics(
      button: isArray,
      label: '$name：$value，$source',
      child: ToolTooltip(
        message: isArray
            ? '$name\n$source\nClick to view details'
            : '$name\n$source',
        child: isArray && latest != null
            ? ToolClickableRow(
                onPressed: () => _showArrayDetails(context, name, latest.value),
                padding: EdgeInsets.zero,
                child: dataCard,
              )
            : dataCard,
      ),
    );
  }

  void _showArrayDetails(
    BuildContext context,
    String name,
    ParsedDataValue value,
  ) {
    showToolDialog<void>(
      context: context,
      builder: (BuildContext context) => _ArrayValueDetailsDialog(
        name: name,
        values: value.arrayValue,
        unit: value.unit,
      ),
    );
  }
}

class _ArrayValueDetailsDialog extends StatelessWidget {
  const _ArrayValueDetailsDialog({
    required this.name,
    required this.values,
    required this.unit,
  });

  final String name;
  final List<Object?> values;
  final String unit;

  @override
  Widget build(BuildContext context) => ToolAlertDialog(
    icon: AppIcons.dataObject,
    title: name,
    content: SizedBox(
      width: 340,
      height: 280,
      child: ListView.separated(
        key: const ValueKey<String>('mapped-array-details-list'),
        itemCount: values.length,
        separatorBuilder: (BuildContext context, int index) =>
            shad.Divider(height: 1, color: AppTheme.colorsOf(context).border),
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 48,
                child: Text(
                  '[$index]',
                  style: AppFonts.monoStyle.copyWith(
                    color: AppTheme.colorsOf(context).mutedForeground,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${values[index] ?? '--'}${unit.isEmpty ? '' : ' $unit'}',
                  textAlign: TextAlign.end,
                  style: AppFonts.monoStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: <Widget>[
      ToolIconButton(
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(AppIcons.close, size: 18),
      ),
    ],
  );
}

bool _monitoredValueChanged(
  _MonitoredFieldValue? previous,
  _MonitoredFieldValue? current,
) {
  if (current == null) return false;
  if (previous == null) return true;
  return previous.value.value != current.value.value ||
      previous.value.displayValue != current.value.displayValue ||
      previous.value.unit != current.value.unit;
}
