part of '../home/home_screen.dart';

class _DeviceToolsPanel extends StatefulWidget {
  const _DeviceToolsPanel({
    required this.characteristics,
    required this.connected,
    required this.safetyPolicy,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onRead,
    required this.onEditSafetyPolicy,
    required this.l10n,
  });

  final List<BluetoothCharacteristicInfo> characteristics;
  final bool connected;
  final DeviceSafetyPolicy safetyPolicy;
  final Future<void> Function(BluetoothCharacteristicInfo) onSelectWrite;
  final Future<void> Function(
    BluetoothCharacteristicInfo,
    BluetoothSubscriptionMode,
    bool,
  )
  onSubscriptionChanged;
  final Future<void> Function(BluetoothCharacteristicInfo) onRead;
  final VoidCallback onEditSafetyPolicy;
  final AppLocalizations l10n;

  @override
  State<_DeviceToolsPanel> createState() => _DeviceToolsPanelState();
}

class _DeviceToolsPanelState extends State<_DeviceToolsPanel> {
  final TextEditingController _filterController = TextEditingController();
  bool _operableOnly = false;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dense = MediaQuery.sizeOf(context).width >= 680;
    final List<BluetoothCharacteristicInfo> filteredCharacteristics =
        _filteredCharacteristics(widget.characteristics, widget.l10n);
    final Map<String, List<BluetoothCharacteristicInfo>> byService =
        <String, List<BluetoothCharacteristicInfo>>{};
    for (final BluetoothCharacteristicInfo characteristic
        in filteredCharacteristics) {
      byService
          .putIfAbsent(
            characteristic.serviceId,
            () => <BluetoothCharacteristicInfo>[],
          )
          .add(characteristic);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.l10n.characteristics,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.connected
                    ? widget.l10n.connected
                    : widget.l10n.disconnected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Tooltip(
                message: '设备发送策略',
                child: shad.IconButton.ghost(
                  icon: Icon(
                    widget.safetyPolicy.allowedWriteTargetKeys.isNotEmpty ||
                            widget.safetyPolicy.maxFinalFrameBytes != null ||
                            widget.safetyPolicy.requireWriteWithResponse
                        ? Icons.shield
                        : Icons.shield_outlined,
                    size: 19,
                  ),
                  size: dense ? shad.ButtonSize.small : shad.ButtonSize.normal,
                  onPressed:
                      widget.connected && widget.characteristics.isNotEmpty
                      ? widget.onEditSafetyPolicy
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!widget.connected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(widget.l10n.connectToDiscoverCharacteristics),
            )
          else if (widget.characteristics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(widget.l10n.noCharacteristics),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    key: const ValueKey<String>('characteristic-filter'),
                    height: 36,
                    child: ToolTextField(
                      controller: _filterController,
                      label: widget.l10n.filterCharacteristics,
                      hintText: widget.l10n.filterCharacteristics,
                      showLabel: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      onChanged: (_) => setState(() {}),
                      prefix: const Icon(Icons.search, size: 18),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: widget.l10n.operableOnly,
                  child: shad.SelectedButton(
                    key: const ValueKey<String>(
                      'operable-characteristics-filter',
                    ),
                    value: _operableOnly,
                    style: dense
                        ? const shad.ButtonStyle.ghost(
                            size: shad.ButtonSize.small,
                            density: shad.ButtonDensity.dense,
                          )
                        : const shad.ButtonStyle.ghost(),
                    selectedStyle: dense
                        ? const shad.ButtonStyle.secondary(
                            size: shad.ButtonSize.small,
                            density: shad.ButtonDensity.dense,
                          )
                        : const shad.ButtonStyle.secondary(),
                    onChanged: (bool value) =>
                        setState(() => _operableOnly = value),
                    child: const Text('R/W'),
                  ),
                ),
              ],
            ),
            if (filteredCharacteristics.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(widget.l10n.noMatchingCharacteristics),
              )
            else
              ...byService.entries.expand(
                (
                  MapEntry<String, List<BluetoothCharacteristicInfo>> entry,
                ) => <Widget>[
                  _ServiceTreeHeader(
                    serviceId: entry.key,
                    title: _serviceTitle(entry.key, widget.l10n),
                  ),
                  ...entry.value.map(
                    (BluetoothCharacteristicInfo characteristic) =>
                        _CharacteristicTile(
                          characteristic: characteristic,
                          onSelectWrite: widget.onSelectWrite,
                          onSubscriptionChanged: widget.onSubscriptionChanged,
                          onRead: widget.onRead,
                          l10n: widget.l10n,
                        ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  List<BluetoothCharacteristicInfo> _filteredCharacteristics(
    List<BluetoothCharacteristicInfo> source,
    AppLocalizations l10n,
  ) {
    final String query = _filterController.text.trim().toLowerCase();
    return source
        .where((BluetoothCharacteristicInfo characteristic) {
          final bool operable =
              characteristic.canRead ||
              characteristic.canWrite ||
              characteristic.canWriteWithoutResponse;
          if (_operableOnly && !operable) return false;
          if (query.isEmpty) return true;
          final String title =
              _characteristicTitle(characteristic.characteristicId, l10n) ?? '';
          return <String>[
            characteristic.serviceId,
            characteristic.characteristicId,
            title,
          ].any((String value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);
  }
}

class _ServiceTreeHeader extends StatelessWidget {
  const _ServiceTreeHeader({required this.serviceId, required this.title});

  final String serviceId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_tree_outlined,
            size: 15,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
