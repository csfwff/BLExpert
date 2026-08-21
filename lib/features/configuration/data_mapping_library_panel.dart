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
    padding: const EdgeInsets.all(18),
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
          ToolIconButton(
            tooltip: l10n.addResponseMapping,
            onPressed: onNew,
            icon: const Icon(AppIcons.add, size: 19),
          ),
        ],
      ),
      Padding(
        padding: EdgeInsets.only(top: 4, bottom: 12),
        child: Text(l10n.dataMappingHint),
      ),
      if (mappings.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: Text(l10n.noResponseMappings)),
        )
      else
        ...mappings.map(
          (ResponseMapping mapping) => Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(mapping.name),
                        const SizedBox(height: 3),
                        Text(
                          l10n.mappingFieldCount(
                            mapping.commandHex,
                            mapping.fields.length,
                          ),
                          style: const TextStyle(
                            fontFamily: AppFonts.mono,
                            package: AppFonts.shadcnPackage,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ToolIconButton(
                  tooltip: l10n.editResponseMapping,
                  onPressed: () => onEdit(mapping),
                  icon: const Icon(AppIcons.editOutlined, size: 18),
                ),
                ToolIconButton(
                  tooltip: l10n.deleteResponseMapping,
                  onPressed: () => onDelete(mapping),
                  icon: const Icon(AppIcons.deleteOutline, size: 18),
                ),
              ],
            ),
          ),
        ),
    ],
  );
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
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: ToolTextField(
                  initialValue: field.key,
                  label: 'key',
                  onChanged: (String value) =>
                      onChanged(field.copyWith(key: value.trim())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolTextField(
                  initialValue: field.label,
                  label: l10n.fieldLabel,
                  onChanged: (String value) =>
                      onChanged(field.copyWith(label: value)),
                ),
              ),
              ToolIconButton(
                tooltip: l10n.deleteDataField,
                onPressed: onDelete,
                icon: const Icon(AppIcons.deleteOutline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: ToolTextField(
                  initialValue: field.offset.toString(),
                  label: l10n.dataOffset,
                  keyboardType: TextInputType.number,
                  onChanged: (String value) => onChanged(
                    field.copyWith(offset: int.tryParse(value) ?? 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolTextField(
                  initialValue: field.byteLength.toString(),
                  label: l10n.fieldByteLength,
                  keyboardType: TextInputType.number,
                  onChanged: (String value) => onChanged(
                    field.copyWith(byteLength: int.tryParse(value) ?? 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ToolSelect<DataFieldType>(
                  value: field.type,
                  label: l10n.dataFieldType,
                  options: DataFieldType.values
                      .map(
                        (DataFieldType item) => ToolSelectOption<DataFieldType>(
                          value: item,
                          label: item.name,
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (DataFieldType value) =>
                      onChanged(field.copyWith(type: value)),
                ),
              ),
            ],
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
                      field.copyWith(offsetValue: double.tryParse(value) ?? 0),
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
          ToolSwitchTile(
            title: Text(l10n.showInDataPanel),
            value: field.visibleInDataPanel,
            onChanged: (bool value) =>
                onChanged(field.copyWith(visibleInDataPanel: value)),
          ),
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
  key: 'field$index',
  label: '字段 $index',
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
