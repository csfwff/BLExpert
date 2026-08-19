part of '../home/home_screen.dart';

class _CharacteristicTile extends StatelessWidget {
  const _CharacteristicTile({
    required this.characteristic,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onRead,
    required this.l10n,
  });

  final BluetoothCharacteristicInfo characteristic;
  final Future<void> Function(BluetoothCharacteristicInfo) onSelectWrite;
  final Future<void> Function(
    BluetoothCharacteristicInfo,
    BluetoothSubscriptionMode,
    bool,
  )
  onSubscriptionChanged;
  final Future<void> Function(BluetoothCharacteristicInfo) onRead;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool dense = MediaQuery.sizeOf(context).width >= 680;
    final shad.AbstractButtonStyle actionStyle = dense
        ? const shad.ButtonStyle.ghost(
            size: shad.ButtonSize.small,
            density: shad.ButtonDensity.dense,
          )
        : const shad.ButtonStyle.ghost();
    final shad.AbstractButtonStyle selectedActionStyle = dense
        ? const shad.ButtonStyle.secondary(
            size: shad.ButtonSize.small,
            density: shad.ButtonDensity.dense,
          )
        : const shad.ButtonStyle.secondary();
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                characteristic.isSubscribed
                    ? Icons.sensors_outlined
                    : Icons.memory_outlined,
                size: 16,
                color: characteristic.isSubscribed
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _characteristicTitle(characteristic.characteristicId, l10n) ??
                      _shortUuid(characteristic.characteristicId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Text(
            characteristic.characteristicId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              if (characteristic.canWrite)
                _CapabilityChip(code: 'W', label: l10n.writeWithResponse),
              if (characteristic.canWriteWithoutResponse)
                _CapabilityChip(code: 'NR', label: l10n.writeWithoutResponse),
              if (characteristic.canRead)
                _CapabilityChip(code: 'R', label: l10n.read),
              if (characteristic.canNotify)
                _CapabilityChip(code: 'N', label: l10n.notify),
              if (characteristic.canIndicate)
                _CapabilityChip(code: 'I', label: l10n.indicate),
            ],
          ),
          if (characteristic.canRead ||
              characteristic.canWrite ||
              characteristic.canWriteWithoutResponse ||
              characteristic.canSubscribe)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  if (characteristic.canRead)
                    Tooltip(
                      message: l10n.readValue,
                      child: shad.IconButton.ghost(
                        key: ValueKey<String>(
                          'characteristic-read-${characteristic.key}',
                        ),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        size: dense
                            ? shad.ButtonSize.small
                            : shad.ButtonSize.normal,
                        onPressed: () => onRead(characteristic),
                      ),
                    ),
                  if (characteristic.canWrite ||
                      characteristic.canWriteWithoutResponse)
                    shad.SelectedButton(
                      key: ValueKey<String>(
                        'characteristic-write-target-${characteristic.key}',
                      ),
                      value: characteristic.isWriteTarget,
                      style: actionStyle,
                      selectedStyle: selectedActionStyle,
                      onChanged: (_) => onSelectWrite(characteristic),
                      child: Text(l10n.writeTarget),
                    ),
                  if (characteristic.canNotify)
                    shad.SelectedButton(
                      key: ValueKey<String>(
                        'characteristic-notify-${characteristic.key}',
                      ),
                      value:
                          characteristic.isSubscribed &&
                          characteristic.subscriptionMode ==
                              BluetoothSubscriptionMode.notify,
                      style: actionStyle,
                      selectedStyle: selectedActionStyle,
                      onChanged: (bool selected) => onSubscriptionChanged(
                        characteristic,
                        BluetoothSubscriptionMode.notify,
                        selected,
                      ),
                      child: Text(l10n.notify),
                    ),
                  if (characteristic.canIndicate)
                    shad.SelectedButton(
                      key: ValueKey<String>(
                        'characteristic-indicate-${characteristic.key}',
                      ),
                      value:
                          characteristic.isSubscribed &&
                          characteristic.subscriptionMode ==
                              BluetoothSubscriptionMode.indicate,
                      style: actionStyle,
                      selectedStyle: selectedActionStyle,
                      onChanged: (bool selected) => onSubscriptionChanged(
                        characteristic,
                        BluetoothSubscriptionMode.indicate,
                        selected,
                      ),
                      child: Text(l10n.indicate),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.code, required this.label});
  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: shad.SecondaryBadge(
          style: const shad.ButtonStyle.secondary(
            size: shad.ButtonSize.xSmall,
            density: shad.ButtonDensity.dense,
          ),
          child: Text(code, style: const TextStyle(fontSize: 10)),
        ),
      ),
    );
  }
}
