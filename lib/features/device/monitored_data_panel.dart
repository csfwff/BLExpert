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

class _MappedDataCell extends StatelessWidget {
  const _MappedDataCell({
    super.key,
    required this.definition,
    required this.latest,
  });

  final _MonitoredFieldDefinition definition;
  final _MonitoredFieldValue? latest;

  @override
  Widget build(BuildContext context) {
    final String name = definition.field.label.isEmpty
        ? definition.field.key
        : definition.field.label;
    final String value = latest == null
        ? '--'
        : '${latest!.value.displayValue}${latest!.value.unit.isEmpty ? '' : ' ${latest!.value.unit}'}';
    final String source =
        '${definition.mapping.name} | CMD ${definition.mapping.commandHex}';
    return Semantics(
      label: '$name：$value，$source',
      child: ToolTooltip(
        message: '$name\n$source',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.colorsOf(context).card,
            border: Border.all(color: AppTheme.colorsOf(context).border),
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
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.colorsOf(context).mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
