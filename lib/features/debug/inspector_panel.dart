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
            child: _SelectedLogDetails(entry: selectedLog!, l10n: l10n),
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
  const _SelectedLogDetails({required this.entry, required this.l10n});

  final SessionLogRecord entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String timestamp = entry.timestamp.toIso8601String();
    final String frame = entry.data.isEmpty
        ? (entry.message ?? '')
        : _toHex(entry.data);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.colorsOf(context).muted,
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: ListView(
        children: <Widget>[
          Text(
            l10n.selectedLog,
            style: AppTheme.textStylesOf(
              context,
            ).labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('${entry.directionLabel(l10n)}  $timestamp'),
          Text('${l10n.source}: ${entry.characteristicId ?? l10n.noSource}'),
          Text('${l10n.length}: ${entry.data.length}'),
          if (entry.commandName != null)
            Text('${l10n.commandName}: ${entry.commandName}'),
          if (entry.transactionId != null)
            Text('${l10n.transaction}: ${entry.transactionId}'),
          const SizedBox(height: 4),
          shad.SelectableText(
            frame,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
