part of '../home/home_screen.dart';

class _CharacteristicTile extends StatelessWidget {
  const _CharacteristicTile({
    required this.characteristic,
    required this.dense,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onRead,
    required this.l10n,
  });

  final BluetoothCharacteristicInfo characteristic;
  final bool dense;
  final Future<void> Function(BluetoothCharacteristicInfo, BluetoothWriteMode)
  onSelectWrite;
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
    const TextStyle actionTextStyle = TextStyle(fontSize: 12);
    final List<Widget> capabilityMarkers = <Widget>[
      if (characteristic.canRead)
        _CapabilityMarker(code: 'R←', label: l10n.readCapabilityDescription),
      if (characteristic.canWrite)
        _CapabilityMarker(code: 'W→', label: l10n.writeCapabilityDescription),
      if (characteristic.canWriteWithoutResponse)
        _CapabilityMarker(
          code: 'WNR→',
          label: l10n.writeNoResponseCapabilityDescription,
        ),
      if (characteristic.canNotify)
        _CapabilityMarker(code: 'N←', label: l10n.notifyCapabilityDescription),
      if (characteristic.canIndicate)
        _CapabilityMarker(
          code: 'I←',
          label: l10n.indicateCapabilityDescription,
        ),
    ];
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                characteristic.isSubscribed
                    ? AppIcons.sensorsOutlined
                    : AppIcons.memoryOutlined,
                size: 16,
                color: characteristic.isSubscribed
                    ? AppTheme.colorsOf(context).chart2
                    : AppTheme.colorsOf(context).border,
              ),
              const SizedBox(width: 4),
              Flexible(
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
              if (capabilityMarkers.isNotEmpty) ...<Widget>[
                const SizedBox(width: 4),
                ...capabilityMarkers.expand(
                  (Widget marker) => <Widget>[
                    marker,
                    if (marker != capabilityMarkers.last)
                      const SizedBox(width: 2),
                  ],
                ),
              ],
            ],
          ),
          Text(
            characteristic.characteristicId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.monoStyle.copyWith(fontSize: 10),
          ),
          if (characteristic.canRead ||
              characteristic.canWrite ||
              characteristic.canWriteWithoutResponse ||
              characteristic.canSubscribe)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  if (characteristic.canRead)
                    ToolButton.outline(
                      key: ValueKey<String>(
                        'characteristic-read-${characteristic.key}',
                      ),
                      compact: dense,
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      onPressed: () => onRead(characteristic),
                      child: const Text('Read', style: actionTextStyle),
                    ),
                  if (characteristic.canWrite)
                    ToolSelectedButton(
                      key: ValueKey<String>(
                        'characteristic-write-${characteristic.key}',
                      ),
                      value:
                          characteristic.writeMode ==
                          BluetoothWriteMode.withResponse,
                      compact: dense,
                      minHeight: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      onChanged: (_) => onSelectWrite(
                        characteristic,
                        BluetoothWriteMode.withResponse,
                      ),
                      child: const Text('Write', style: actionTextStyle),
                    ),
                  if (characteristic.canWriteWithoutResponse)
                    ToolSelectedButton(
                      key: ValueKey<String>(
                        'characteristic-write-no-response-${characteristic.key}',
                      ),
                      value:
                          characteristic.writeMode ==
                          BluetoothWriteMode.withoutResponse,
                      compact: dense,
                      minHeight: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      onChanged: (_) => onSelectWrite(
                        characteristic,
                        BluetoothWriteMode.withoutResponse,
                      ),
                      child: const Text(
                        'Write No Response',
                        maxLines: 1,
                        style: actionTextStyle,
                      ),
                    ),
                  if (characteristic.canNotify)
                    ToolSelectedButton(
                      key: ValueKey<String>(
                        'characteristic-notify-${characteristic.key}',
                      ),
                      value:
                          characteristic.isSubscribed &&
                          characteristic.subscriptionMode ==
                              BluetoothSubscriptionMode.notify,
                      compact: dense,
                      minHeight: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      onChanged: (bool selected) => onSubscriptionChanged(
                        characteristic,
                        BluetoothSubscriptionMode.notify,
                        selected,
                      ),
                      child: const Text('Notify', style: actionTextStyle),
                    ),
                  if (characteristic.canIndicate)
                    ToolSelectedButton(
                      key: ValueKey<String>(
                        'characteristic-indicate-${characteristic.key}',
                      ),
                      value:
                          characteristic.isSubscribed &&
                          characteristic.subscriptionMode ==
                              BluetoothSubscriptionMode.indicate,
                      compact: dense,
                      minHeight: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      onChanged: (bool selected) => onSubscriptionChanged(
                        characteristic,
                        BluetoothSubscriptionMode.indicate,
                        selected,
                      ),
                      child: const Text('Indicate', style: actionTextStyle),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CapabilityMarker extends StatelessWidget {
  const _CapabilityMarker({required this.code, required this.label});
  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ToolTooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.colorsOf(context).secondary,
            border: Border.all(color: AppTheme.colorsOf(context).border),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            code,
            maxLines: 1,
            style: TextStyle(
              color: AppTheme.colorsOf(context).secondaryForeground,
              fontFamily: AppFonts.mono,
              package: AppFonts.shadcnPackage,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
