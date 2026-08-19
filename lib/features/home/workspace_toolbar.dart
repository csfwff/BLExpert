part of 'home_screen.dart';

class _WorkspaceSelector extends StatelessWidget {
  const _WorkspaceSelector({
    required this.workspace,
    required this.workspaces,
    required this.compact,
    required this.onSelected,
    required this.onNew,
    required this.onDelete,
    required this.onExport,
    required this.onImport,
    required this.l10n,
  });
  final Workspace workspace;
  final List<Workspace> workspaces;
  final bool compact;
  final ValueChanged<String> onSelected;
  final VoidCallback onNew;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final AppLocalizations l10n;

  static const double _toolbarControlHeight = 36;
  static const double _toolbarControlWidth = 136;
  static const double _toolbarControlGap = 8;

  void _showWorkspaceMenu(BuildContext context) {
    shad
        .showDropdown<void>(
          context: context,
          widthConstraint: compact
              ? shad.PopoverConstraint.flexible
              : shad.PopoverConstraint.anchorFixedSize,
          showDuration: AppMotion.overlay,
          dismissDuration: AppMotion.overlay,
          builder: (BuildContext context) => shad.DropdownMenu(
            children: <shad.MenuItem>[
              shad.MenuLabel(
                leading: const Icon(AppIcons.folderOutlined, size: 18),
                child: Text(l10n.selectWorkspace),
              ),
              const shad.MenuDivider(),
              shad.MenuRadioGroup<String>(
                value: workspace.id,
                onChanged: (BuildContext context, String workspaceId) =>
                    onSelected(workspaceId),
                children: workspaces
                    .map(
                      (Workspace item) => shad.MenuRadio<String>(
                        value: item.id,
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const shad.MenuDivider(),
              shad.MenuButton(
                leading: const Icon(AppIcons.createNewFolder),
                onPressed: (_) => onNew(),
                child: Text(l10n.newWorkspace),
              ),
              shad.MenuButton(
                leading: const Icon(AppIcons.deleteOutline),
                enabled: workspaces.length > 1,
                onPressed: (_) => onDelete(),
                child: Text(l10n.deleteWorkspace),
              ),
              const shad.MenuDivider(),
              shad.MenuButton(
                leading: const Icon(AppIcons.downloadOutlined),
                onPressed: (_) => onImport(),
                child: Text(l10n.importWorkspace),
              ),
              shad.MenuButton(
                leading: const Icon(AppIcons.uploadFile),
                onPressed: (_) => onExport(),
                child: Text(l10n.exportWorkspace),
              ),
            ],
          ),
        )
        .future;
  }

  @override
  Widget build(BuildContext context) {
    final Widget trigger = SizedBox(
      height: _toolbarControlHeight,
      child: compact
          ? shad.IconButton.ghost(
              key: const ValueKey<String>('workspace-selector'),
              icon: const Icon(AppIcons.folderOutlined),
              size: shad.ButtonSize.small,
              onPressed: () => _showWorkspaceMenu(context),
            )
          : SizedBox(
              width: _toolbarControlWidth,
              child: shad.Button(
                key: const ValueKey<String>('workspace-selector'),
                style: const shad.ButtonStyle.outline(
                  size: shad.ButtonSize.small,
                  density: shad.ButtonDensity.dense,
                ),
                leading: const Icon(AppIcons.folderOutlined, size: 18),
                trailing: const Icon(AppIcons.expandMore, size: 18),
                alignment: Alignment.centerLeft,
                onPressed: () => _showWorkspaceMenu(context),
                child: Text(
                  workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
    );
    return Semantics(
      button: true,
      label: l10n.selectWorkspace,
      value: workspace.name,
      child: ToolTooltip(
        message: l10n.selectWorkspace,
        showVisual: compact,
        child: trigger,
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.scanning,
    required this.onPressed,
    required this.l10n,
  });

  final bool scanning;
  final VoidCallback onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String label = scanning ? l10n.stopScan : l10n.startScan;
    return SizedBox(
      width: _WorkspaceSelector._toolbarControlWidth,
      height: _WorkspaceSelector._toolbarControlHeight,
      child: shad.Button(
        key: const ValueKey<String>('scan-button'),
        style: scanning
            ? const shad.ButtonStyle.outline(
                size: shad.ButtonSize.small,
                density: shad.ButtonDensity.dense,
              )
            : const shad.ButtonStyle.primary(
                size: shad.ButtonSize.small,
                density: shad.ButtonDensity.dense,
              ),
        onPressed: onPressed,
        alignment: Alignment.center,
        leading: Icon(
          scanning ? AppIcons.stopCircle : AppIcons.radar,
          size: 18,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      ),
    );
  }
}

class _ConnectionSelector extends StatelessWidget {
  const _ConnectionSelector({
    required this.devices,
    required this.selectedId,
    required this.connected,
    required this.operation,
    required this.onSelected,
    required this.onToggleConnection,
    required this.l10n,
  });
  final List<BluetoothDeviceInfo> devices;
  final String? selectedId;
  final bool connected;
  final _ConnectionOperation? operation;
  final ValueChanged<String?> onSelected;
  final VoidCallback onToggleConnection;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final device = devices.where((item) => item.id == selectedId).firstOrNull;
    final TextStyle deviceTextStyle = AppTheme.of(context).typography.xSmall;
    final bool busy = operation != null;
    final bool useConnectedStyle =
        operation == _ConnectionOperation.disconnect ||
        operation == null && connected;
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final String buttonLabel = operation == _ConnectionOperation.disconnect
        ? l10n.disconnecting
        : operation == _ConnectionOperation.connect
        ? l10n.connecting
        : connected
        ? l10n.disconnectDevice
        : l10n.connectDevice;
    final shad.AbstractButtonStyle baseButtonStyle = useConnectedStyle
        ? const shad.ButtonStyle.secondary(
            size: shad.ButtonSize.small,
            density: shad.ButtonDensity.dense,
          )
        : const shad.ButtonStyle.primary(
            size: shad.ButtonSize.small,
            density: shad.ButtonDensity.dense,
          );
    final shad.AbstractButtonStyle buttonStyle = busy
        ? baseButtonStyle
              .withBackgroundColor(
                disabledColor: useConnectedStyle
                    ? colors.secondary
                    : colors.primary,
              )
              .withForegroundColor(
                disabledColor: useConnectedStyle
                    ? colors.secondaryForeground
                    : colors.primaryForeground,
              )
              .withBorder(
                disabledBorder: useConnectedStyle
                    ? Border.all(color: colors.secondaryForeground)
                    : null,
              )
        : baseButtonStyle;
    final String actionLabel = device == null
        ? l10n.selectDeviceFirst
        : buttonLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: l10n.connection,
          child: SizedBox(
            width: _WorkspaceSelector._toolbarControlWidth,
            child: shad.Select<String>(
              key: const ValueKey<String>('bluetooth-device-selector'),
              value: device?.id,
              enabled: devices.isNotEmpty,
              placeholder: Text(l10n.noDevice, style: deviceTextStyle),
              constraints: const BoxConstraints.tightFor(
                height: _WorkspaceSelector._toolbarControlHeight,
              ),
              popupConstraints: const BoxConstraints(maxHeight: 280),
              popoverAlignment: Alignment.bottomCenter,
              popoverAnchorAlignment: Alignment.topCenter,
              itemBuilder: (BuildContext context, String deviceId) {
                final BluetoothDeviceInfo item = devices.firstWhere(
                  (BluetoothDeviceInfo item) => item.id == deviceId,
                );
                return Text(
                  item.name,
                  style: deviceTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
              onChanged: devices.isEmpty ? null : onSelected,
              popup: shad.SelectPopup<String>(
                items: shad.SelectItemList(
                  children: devices
                      .map(
                        (BluetoothDeviceInfo item) =>
                            shad.SelectItemButton<String>(
                              value: item.id,
                              child: Text(
                                item.name,
                                style: deviceTextStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      )
                      .toList(growable: false),
                ),
              ).call,
            ),
          ),
        ),
        const SizedBox(width: _WorkspaceSelector._toolbarControlGap),
        ToolTooltip(
          message: actionLabel,
          showVisual: false,
          child: SizedBox(
            width: _WorkspaceSelector._toolbarControlWidth,
            height: _WorkspaceSelector._toolbarControlHeight,
            child: shad.Button(
              key: const ValueKey<String>('connection-action-button'),
              style: buttonStyle,
              onPressed: device == null || busy ? null : onToggleConnection,
              alignment: Alignment.center,
              leading: busy
                  ? const ToolLoadingIcon()
                  : Icon(
                      connected
                          ? AppIcons.linkOff
                          : AppIcons.bluetoothConnectedOutlined,
                      size: 18,
                    ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(buttonLabel, maxLines: 1, softWrap: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
