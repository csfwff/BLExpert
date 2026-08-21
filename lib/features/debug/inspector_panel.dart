part of '../home/home_screen.dart';

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.characteristics,
    required this.canSend,
    required this.onSendCommand,
    required this.commands,
    required this.responseMappings,
    required this.monitoredValues,
    required this.selectedLog,
    required this.onSelectedLogCleared,
    required this.l10n,
  });

  final List<BluetoothCharacteristicInfo> characteristics;
  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>)
  onSendCommand;
  final List<CommandDefinition> commands;
  final List<ResponseMapping> responseMappings;
  final Map<String, _MonitoredFieldValue> monitoredValues;
  final SessionLogRecord? selectedLog;
  final VoidCallback onSelectedLogCleared;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final BluetoothCharacteristicInfo? writeTarget = characteristics
        .where((item) => item.isWriteTarget)
        .firstOrNull;
    return Column(
      children: <Widget>[
        _PanelHeading(
          title: _localizedInspectorTitle(l10n),
          trailing: Text(
            writeTarget == null
                ? _localizedNoWriteTarget(l10n)
                : _shortUuid(writeTarget.characteristicId),
            style: AppTheme.textStylesOf(context).labelSmall,
          ),
        ),
        if (selectedLog != null)
          SizedBox(
            height: 220,
            child: _SelectedLogDetails(
              entry: selectedLog!,
              onClose: onSelectedLogCleared,
              l10n: l10n,
            ),
          ),
        Expanded(
          child: _CommandsAndDataPanel(
            canSend: canSend,
            onSend: onSendCommand,
            commands: commands,
            responseMappings: responseMappings,
            monitoredValues: monitoredValues,
            l10n: l10n,
          ),
        ),
      ],
    );
  }
}

class _SelectedLogDetails extends StatelessWidget {
  const _SelectedLogDetails({
    required this.entry,
    required this.onClose,
    required this.l10n,
  });

  final SessionLogRecord entry;
  final VoidCallback onClose;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String timestamp = entry.timestamp.toIso8601String();
    final String frame = entry.data.isEmpty
        ? (entry.message ?? '')
        : _toHex(entry.data);
    final bool frameIsMessage = entry.data.isEmpty;
    final TextStyle detailStyle = AppTheme.textStylesOf(context).bodySmall
        .copyWith(color: AppTheme.colorsOf(context).foreground, height: 1.45);
    return Container(
      key: const ValueKey<String>('selected-log-details'),
      decoration: BoxDecoration(
        color: AppTheme.colorsOf(context).muted,
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Column(
        children: <Widget>[
          _PanelHeading(
            key: const ValueKey<String>('selected-log-heading'),
            title: l10n.selectedLog,
            icon: AppIcons.subjectOutlined,
            height: 36,
            trailingPinned: true,
            titleStyle: AppTheme.textStylesOf(
              context,
            ).labelLarge.copyWith(fontSize: 12),
            trailing: ToolIconButton(
              key: const ValueKey<String>('selected-log-close'),
              tooltip: l10n.closeLogDetails,
              onPressed: onClose,
              touchSize: 28,
              icon: const Icon(AppIcons.close, size: 16),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              children: <Widget>[
                Text(
                  '${entry.directionLabel(l10n)}  $timestamp',
                  style: detailStyle,
                ),
                Text(
                  '${l10n.source}: ${entry.characteristicId ?? l10n.noSource}',
                  style: detailStyle,
                ),
                Text(
                  '${l10n.length}: ${entry.data.length}',
                  style: detailStyle,
                ),
                if (entry.commandName != null)
                  Text(
                    '${l10n.commandName}: ${entry.commandName}',
                    style: detailStyle,
                  ),
                if (entry.transactionId != null)
                  Text(
                    '${l10n.transaction}: ${entry.transactionId}',
                    style: detailStyle,
                  ),
                const SizedBox(height: 6),
                shad.SelectableText(
                  frame,
                  style: frameIsMessage
                      ? AppTheme.of(context).typography.xSmall.copyWith(
                          height: 1.45,
                          color: AppTheme.colorsOf(context).foreground,
                        )
                      : AppFonts.monoStyle.copyWith(fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
