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
  final Future<void> Function(BluetoothCharacteristicInfo, BluetoothWriteMode)
  onSelectWrite;
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
  final ScrollController _characteristicScrollController = ScrollController();
  bool _operableOnly = false;

  @override
  void dispose() {
    _filterController.dispose();
    _characteristicScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool multiPane = _DebugWorkspaceLayoutScope.multiPaneOf(context);
    final TextStyle hintStyle = AppTheme.textStylesOf(context).bodySmall;
    final TextStyle actionTextStyle = AppTheme.of(context).typography.xSmall;
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
    final bool showCharacteristicList =
        widget.connected && widget.characteristics.isNotEmpty;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool dense = multiPane || constraints.maxWidth >= 680;
        return Container(
          key: const ValueKey<String>('characteristic-panel'),
          color: AppTheme.colorsOf(context).muted,
          child: Column(
            children: <Widget>[
              Padding(
                key: const ValueKey<String>(
                  'characteristic-panel-pinned-header',
                ),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            widget.l10n.characteristics,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.textStylesOf(
                              context,
                            ).titleSmall.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ExcludeSemantics(
                              child: Icon(
                                widget.connected
                                    ? AppIcons.bluetoothConnected
                                    : AppIcons.bluetoothOutlined,
                                key: const ValueKey<String>(
                                  'characteristic-connection-status-icon',
                                ),
                                size: 14,
                                color: widget.connected
                                    ? AppTheme.colorsOf(context).chart2
                                    : AppTheme.colorsOf(
                                        context,
                                      ).mutedForeground,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.connected
                                  ? widget.l10n.connected
                                  : widget.l10n.disconnected,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: AppTheme.textStylesOf(context).labelSmall,
                            ),
                          ],
                        ),
                        ToolTooltip(
                          message: '设备发送策略',
                          child: shad.IconButton.ghost(
                            icon: Icon(
                              widget
                                          .safetyPolicy
                                          .allowedWriteTargetKeys
                                          .isNotEmpty ||
                                      widget.safetyPolicy.maxFinalFrameBytes !=
                                          null ||
                                      widget
                                          .safetyPolicy
                                          .requireWriteWithResponse
                                  ? AppIcons.shield
                                  : AppIcons.shieldOutlined,
                              size: 19,
                            ),
                            size: dense
                                ? shad.ButtonSize.small
                                : shad.ButtonSize.normal,
                            onPressed:
                                widget.connected &&
                                    widget.characteristics.isNotEmpty
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
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.l10n.connectToDiscoverCharacteristics,
                            style: hintStyle,
                          ),
                        ),
                      ),
                    if (widget.connected && widget.characteristics.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.l10n.noCharacteristics,
                            style: hintStyle,
                          ),
                        ),
                      ),
                    if (showCharacteristicList)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: SizedBox(
                                key: const ValueKey<String>(
                                  'characteristic-filter',
                                ),
                                height: 32,
                                child: ToolTextField(
                                  controller: _filterController,
                                  label: widget.l10n.filterCharacteristics,
                                  hintText: widget.l10n.filterCharacteristics,
                                  showLabel: false,
                                  onChanged: (_) => setState(() {}),
                                  prefix: const Icon(AppIcons.search, size: 18),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ToolTooltip(
                            message: widget.l10n.operableOnly,
                            child: ToolSelectedButton(
                              key: const ValueKey<String>(
                                'operable-characteristics-filter',
                              ),
                              value: _operableOnly,
                              compact: dense,
                              onChanged: (bool value) =>
                                  setState(() => _operableOnly = value),
                              child: Text('R/W', style: actionTextStyle),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (showCharacteristicList)
                Expanded(
                  child: shad.Scrollbar(
                    key: const ValueKey<String>(
                      'characteristic-list-scrollbar',
                    ),
                    controller: _characteristicScrollController,
                    thumbVisibility: true,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: ListView(
                        key: const ValueKey<String>('characteristic-list'),
                        controller: _characteristicScrollController,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        children: <Widget>[
                          if (filteredCharacteristics.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                widget.l10n.noMatchingCharacteristics,
                                style: hintStyle,
                              ),
                            )
                          else
                            ...byService.entries.expand(
                              (
                                MapEntry<
                                  String,
                                  List<BluetoothCharacteristicInfo>
                                >
                                entry,
                              ) => <Widget>[
                                _ServiceTreeHeader(
                                  serviceId: entry.key,
                                  title: _serviceTitle(entry.key, widget.l10n),
                                ),
                                ...entry.value.map(
                                  (
                                    BluetoothCharacteristicInfo characteristic,
                                  ) => _CharacteristicTile(
                                    characteristic: characteristic,
                                    dense: dense,
                                    onSelectWrite: widget.onSelectWrite,
                                    onSubscriptionChanged:
                                        widget.onSubscriptionChanged,
                                    onRead: widget.onRead,
                                    l10n: widget.l10n,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            AppIcons.accountTree,
            size: 15,
            color: AppTheme.colorsOf(context).secondary,
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
