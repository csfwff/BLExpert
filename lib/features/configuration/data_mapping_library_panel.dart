part of '../home/home_screen.dart';

class _DataMappingLibraryPanel extends StatelessWidget {
  const _DataMappingLibraryPanel({
    required this.mappings,
    required this.onNew,
    required this.onEdit,
    required this.onDelete,
    required this.l10n,
  });

  final List<ResponseMapping> mappings;
  final VoidCallback onNew;
  final ValueChanged<ResponseMapping> onEdit;
  final ValueChanged<ResponseMapping> onDelete;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey<String>('response-mapping-library-list'),
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.dataMappings,
              style: AppTheme.textStylesOf(
                context,
              ).titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ToolTooltip(
            message: l10n.addResponseMapping,
            child: ToolButton.primary(
              key: const ValueKey<String>('new-response-mapping-button'),
              onPressed: onNew,
              compact: true,
              height: 32,
              leading: const Icon(AppIcons.add, size: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(l10n.addResponseMapping),
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          l10n.dataMappingHint,
          style: AppTheme.textStylesOf(context).bodySmall,
        ),
      ),
      if (mappings.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: Text(l10n.noResponseMappings)),
        )
      else
        ...mappings.map(
          (ResponseMapping mapping) => Container(
            key: ValueKey<String>('response-mapping-item-${mapping.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.colorsOf(context).border),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ToolClickableRow(
                    onPressed: () => onEdit(mapping),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                mapping.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _AsciiLogStatus(enabled: mapping.asciiLogEnabled),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'CMD ${mapping.commandHex}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.textStylesOf(context).labelSmall
                              .copyWith(fontSize: 10)
                              .merge(AppFonts.monoStyle),
                        ),
                        if (mapping.fields.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: mapping.fields
                                  .map(
                                    (DataField field) =>
                                        _MappingFieldTag(field: field),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ToolIconButton(
                      tooltip: l10n.editResponseMapping,
                      onPressed: () => onEdit(mapping),
                      touchSize: 32,
                      icon: const Icon(AppIcons.editOutlined, size: 18),
                    ),
                    const SizedBox(width: 4),
                    ToolIconButton(
                      tooltip: l10n.deleteResponseMapping,
                      onPressed: () => onDelete(mapping),
                      touchSize: 32,
                      icon: const Icon(AppIcons.deleteOutline, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _AsciiLogStatus extends StatelessWidget {
  const _AsciiLogStatus({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final Color foreground = enabled ? colors.primary : colors.mutedForeground;
    return Container(
      key: ValueKey<String>('response-mapping-ascii-${enabled ? 'on' : 'off'}'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: foreground.withValues(alpha: 0.42)),
      ),
      child: Text(
        'ASCII ${enabled ? 'ON' : 'OFF'}',
        maxLines: 1,
        style: AppTheme.textStylesOf(context).labelSmall.copyWith(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MappingFieldTag extends StatelessWidget {
  const _MappingFieldTag({required this.field});

  final DataField field;

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final int endOffset = field.offset + field.byteLength - 1;
    final String range = endOffset == field.offset
        ? '${field.offset}'
        : '${field.offset}..$endOffset';
    final String key = field.key.trim();
    final String label = field.label.trim();
    final String name = switch ((label, key)) {
      ('', '') => field.type.name,
      ('', final String value) => value,
      (final String value, '') => value,
      (final String value, final String identifier) when value == identifier =>
        value,
      (final String value, final String identifier) => '$value ($identifier)',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        'DATA[$range] $name ${field.type.name}',
        style: AppTheme.textStylesOf(
          context,
        ).labelSmall.copyWith(fontSize: 10).merge(AppFonts.monoStyle),
      ),
    );
  }
}

class _CommandParameterEditor extends StatelessWidget {
  const _CommandParameterEditor({
    super.key,
    required this.parameter,
    required this.onChanged,
    required this.onDelete,
  });
  final CommandParameter parameter;
  final ValueChanged<CommandParameter> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stacked = constraints.maxWidth < 560;
          final Widget keyField = ToolTextField(
            initialValue: parameter.key,
            label: 'key',
            hintText: '参数名',
            onChanged: (String value) =>
                onChanged(parameter.copyWith(key: value.trim())),
          );
          final Widget labelField = ToolTextField(
            initialValue: parameter.label,
            label: '名称',
            hintText: '显示名称',
            onChanged: (String value) =>
                onChanged(parameter.copyWith(label: value)),
          );
          final Widget typeField = SizedBox(
            width: double.infinity,
            child: ToolSelect<CommandParameterType>(
              value: parameter.type,
              label: '类型',
              expand: true,
              options: CommandParameterType.values
                  .map(
                    (CommandParameterType item) =>
                        ToolSelectOption<CommandParameterType>(
                          value: item,
                          label: _commandParameterTypeLabel(item),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (CommandParameterType value) =>
                  onChanged(parameter.copyWith(type: value)),
            ),
          );
          final Widget defaultField = ToolTextField(
            initialValue: parameter.defaultValue,
            label: '默认值',
            hintText: '可选',
            onChanged: (String value) =>
                onChanged(parameter.copyWith(defaultValue: value)),
          );
          final Widget deleteButton = ToolIconButton(
            tooltip: '删除参数',
            onPressed: onDelete,
            touchSize: 32,
            icon: const Icon(AppIcons.deleteOutline, size: 18),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (stacked) ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(child: keyField),
                    const SizedBox(width: 8),
                    Expanded(child: labelField),
                    deleteButton,
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(child: typeField),
                    const SizedBox(width: 8),
                    Expanded(child: defaultField),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(flex: 3, child: keyField),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: labelField),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: typeField),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: defaultField),
                    const SizedBox(width: 8),
                    deleteButton,
                  ],
                ),
              if (parameter.type == CommandParameterType.enumValue) ...<Widget>[
                const SizedBox(height: 6),
                ToolTextField(
                  initialValue: parameter.options
                      .map(
                        (CommandParameterOption option) =>
                            '${option.label}=${option.value}',
                      )
                      .join(', '),
                  label: '枚举选项',
                  hintText: '名称=数值，多个选项以逗号分隔',
                  onChanged: (String value) => onChanged(
                    parameter.copyWith(options: _parseParameterOptions(value)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _MappingFieldEditor extends StatelessWidget {
  const _MappingFieldEditor({
    super.key,
    required this.field,
    required this.onChanged,
    required this.onDelete,
  });
  final DataField field;
  final ValueChanged<DataField> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool isNumeric = switch (field.type) {
      DataFieldType.uint8 ||
      DataFieldType.int8 ||
      DataFieldType.uint16 ||
      DataFieldType.int16 ||
      DataFieldType.uint32 ||
      DataFieldType.int32 => true,
      _ => false,
    };
    final bool needsByteOrder = switch (field.type) {
      DataFieldType.uint16 ||
      DataFieldType.int16 ||
      DataFieldType.uint32 ||
      DataFieldType.int32 => true,
      _ => false,
    };
    final Widget deleteButton = ToolIconButton(
      tooltip: l10n.deleteDataField,
      onPressed: onDelete,
      touchSize: 32,
      icon: const Icon(AppIcons.deleteOutline, size: 18),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = constraints.maxWidth < 560;
                    final Widget keyField = ToolTextField(
                      initialValue: field.key,
                      label: 'key',
                      hintText: 'key',
                      onChanged: (String value) =>
                          onChanged(field.copyWith(key: value.trim())),
                    );
                    final Widget labelField = ToolTextField(
                      initialValue: field.label,
                      label: l10n.fieldLabel,
                      hintText: l10n.fieldLabel,
                      onChanged: (String value) =>
                          onChanged(field.copyWith(label: value)),
                    );
                    final Widget offsetField = ToolTextField(
                      initialValue: field.offset.toString(),
                      label: l10n.dataOffset,
                      hintText: l10n.dataOffset,
                      keyboardType: TextInputType.number,
                      onChanged: (String value) => onChanged(
                        field.copyWith(offset: int.tryParse(value) ?? 0),
                      ),
                    );
                    final Widget lengthField = ToolTextField(
                      initialValue: field.byteLength.toString(),
                      label: l10n.fieldByteLength,
                      hintText: l10n.fieldByteLength,
                      keyboardType: TextInputType.number,
                      onChanged: (String value) => onChanged(
                        field.copyWith(byteLength: int.tryParse(value) ?? 1),
                      ),
                    );
                    final Widget typeField = ToolSelect<DataFieldType>(
                      value: field.type,
                      label: l10n.dataFieldType,
                      expand: true,
                      options: DataFieldType.values
                          .map(
                            (DataFieldType item) =>
                                ToolSelectOption<DataFieldType>(
                                  value: item,
                                  label: item.name,
                                ),
                          )
                          .toList(growable: false),
                      onChanged: (DataFieldType value) =>
                          onChanged(field.copyWith(type: value)),
                    );
                    if (stacked) {
                      return Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(child: keyField),
                              const SizedBox(width: 8),
                              Expanded(child: labelField),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Expanded(child: offsetField),
                              const SizedBox(width: 8),
                              Expanded(child: lengthField),
                              const SizedBox(width: 8),
                              Expanded(child: typeField),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(flex: 2, child: keyField),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: labelField),
                        const SizedBox(width: 8),
                        SizedBox(width: 72, child: offsetField),
                        const SizedBox(width: 8),
                        SizedBox(width: 72, child: lengthField),
                        const SizedBox(width: 8),
                        SizedBox(width: 120, child: typeField),
                      ],
                    );
                  },
                ),
                if (isNumeric) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ToolTextField(
                          initialValue: field.scale.toString(),
                          label: l10n.numericScale,
                          onChanged: (String value) => onChanged(
                            field.copyWith(scale: double.tryParse(value) ?? 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ToolTextField(
                          initialValue: field.offsetValue.toString(),
                          label: l10n.numericOffset,
                          onChanged: (String value) => onChanged(
                            field.copyWith(
                              offsetValue: double.tryParse(value) ?? 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ToolTextField(
                          initialValue: field.unit,
                          label: l10n.unit,
                          onChanged: (String value) =>
                              onChanged(field.copyWith(unit: value)),
                        ),
                      ),
                    ],
                  ),
                ],
                if (needsByteOrder) ...<Widget>[
                  const SizedBox(height: 8),
                  ToolSelect<ProtocolByteOrder>(
                    value: field.byteOrder,
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
                        onChanged(field.copyWith(byteOrder: value)),
                  ),
                ],
                if (field.type == DataFieldType.bit ||
                    field.type == DataFieldType.enumValue) ...<Widget>[
                  const SizedBox(height: 8),
                  ToolTextField(
                    initialValue: field.type == DataFieldType.bit
                        ? (field.bit ?? 0).toString()
                        : field.enumValues.entries
                              .map(
                                (MapEntry<String, String> item) =>
                                    '${item.key}=${item.value}',
                              )
                              .join(', '),
                    label: field.type == DataFieldType.bit
                        ? l10n.bitNumber
                        : l10n.enumValues,
                    helperText: field.type == DataFieldType.bit
                        ? l10n.bitNumberHint
                        : l10n.enumValuesHint,
                    onChanged: (String value) => onChanged(
                      field.type == DataFieldType.bit
                          ? field.copyWith(bit: int.tryParse(value) ?? 0)
                          : field.copyWith(enumValues: _parseEnumValues(value)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.showInDataPanel,
                        style: AppTheme.textStylesOf(context).labelMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ToolSwitch(
                      value: field.visibleInDataPanel,
                      onChanged: (bool value) =>
                          onChanged(field.copyWith(visibleInDataPanel: value)),
                      label: l10n.showInDataPanel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          deleteButton,
        ],
      ),
    );
  }
}

List<CommandParameterOption> _parseParameterOptions(String value) => value
    .split(',')
    .map((String item) => item.trim().split('='))
    .where((List<String> pair) => pair.length == 2 && pair[0].trim().isNotEmpty)
    .map(
      (List<String> pair) =>
          CommandParameterOption(label: pair[0].trim(), value: pair[1].trim()),
    )
    .toList(growable: false);

Map<String, String> _parseEnumValues(String value) => <String, String>{
  for (final List<String> pair
      in value.split(',').map((String item) => item.trim().split('=')))
    if (pair.length == 2 && pair[0].trim().isNotEmpty)
      pair[0].trim(): pair[1].trim(),
};

CommandParameter _newCommandParameter() => const CommandParameter(
  key: '',
  label: '',
  type: CommandParameterType.uint8,
  defaultValue: '',
  min: null,
  max: null,
  options: <CommandParameterOption>[],
);

DataField _newDataField(int index) => DataField(
  key: '',
  label: '',
  offset: index,
  byteLength: 1,
  type: DataFieldType.uint8,
  byteOrder: ProtocolByteOrder.littleEndian,
  scale: 1,
  offsetValue: 0,
  unit: '',
  bit: null,
  enumValues: const <String, String>{},
);

String _commandParameterTypeLabel(CommandParameterType type) => switch (type) {
  CommandParameterType.uint8 => 'uint8',
  CommandParameterType.int8 => 'int8',
  CommandParameterType.uint16 => 'uint16',
  CommandParameterType.int16 => 'int16',
  CommandParameterType.uint32 => 'uint32',
  CommandParameterType.int32 => 'int32',
  CommandParameterType.hex => 'HEX',
  CommandParameterType.ascii => 'ASCII',
  CommandParameterType.utf8 => 'UTF-8',
  CommandParameterType.boolean => 'Boolean',
  CommandParameterType.enumValue => 'Enum',
  CommandParameterType.currentYear => '当前年（2 位）',
  CommandParameterType.currentMonth => '当前月',
  CommandParameterType.currentDay => '当前日',
  CommandParameterType.currentHour => '当前时',
  CommandParameterType.currentMinute => '当前分',
  CommandParameterType.currentSecond => '当前秒',
};
