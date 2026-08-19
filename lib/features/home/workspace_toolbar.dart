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

  void _showWorkspaceMenu(BuildContext context) {
    shad
        .showDropdown<void>(
          context: context,
          widthConstraint: shad.PopoverConstraint.flexible,
          showDuration: Duration.zero,
          dismissDuration: Duration.zero,
          builder: (BuildContext context) => shad.DropdownMenu(
            children: <shad.MenuItem>[
              shad.MenuLabel(
                leading: const Icon(Icons.folder_outlined, size: 18),
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
                leading: const Icon(Icons.create_new_folder_outlined),
                onPressed: (_) => onNew(),
                child: Text(l10n.newWorkspace),
              ),
              shad.MenuButton(
                leading: const Icon(Icons.delete_outline),
                enabled: workspaces.length > 1,
                onPressed: (_) => onDelete(),
                child: Text(l10n.deleteWorkspace),
              ),
              const shad.MenuDivider(),
              shad.MenuButton(
                leading: const Icon(Icons.download_outlined),
                onPressed: (_) => onImport(),
                child: Text(l10n.importWorkspace),
              ),
              shad.MenuButton(
                leading: const Icon(Icons.upload_file_outlined),
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
              icon: const Icon(Icons.folder_outlined),
              size: shad.ButtonSize.small,
              onPressed: () => _showWorkspaceMenu(context),
            )
          : SizedBox(
              width: 190,
              child: shad.Button(
                key: const ValueKey<String>('workspace-selector'),
                style: const shad.ButtonStyle.outline(
                  size: shad.ButtonSize.small,
                  density: shad.ButtonDensity.dense,
                ),
                leading: const Icon(Icons.folder_outlined, size: 18),
                trailing: const Icon(Icons.expand_more, size: 18),
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
      child: Tooltip(message: l10n.selectWorkspace, child: trigger),
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
      width: 108,
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
          scanning ? Icons.stop_circle_outlined : Icons.radar,
          size: 18,
        ),
        child: Text(label),
      ),
    );
  }
}

class _ConnectionSelector extends StatelessWidget {
  const _ConnectionSelector({
    required this.devices,
    required this.selectedId,
    required this.connected,
    required this.connecting,
    required this.onSelected,
    required this.onToggleConnection,
    required this.l10n,
  });
  final List<BluetoothDeviceInfo> devices;
  final String? selectedId;
  final bool connected;
  final bool connecting;
  final ValueChanged<String?> onSelected;
  final VoidCallback onToggleConnection;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final device = devices.where((item) => item.id == selectedId).firstOrNull;
    final String actionLabel = connecting
        ? l10n.connecting
        : device == null
        ? l10n.selectDeviceFirst
        : connected
        ? '${l10n.connected} · ${l10n.disconnectDevice}'
        : l10n.connectDevice;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: l10n.connection,
          child: SizedBox(
            width: 174,
            child: shad.Select<String>(
              key: const ValueKey<String>('bluetooth-device-selector'),
              value: device?.id,
              enabled: devices.isNotEmpty,
              placeholder: Text(l10n.noDevice),
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
        const SizedBox(width: 8),
        Tooltip(
          message: actionLabel,
          child: SizedBox(
            width: 160,
            height: _WorkspaceSelector._toolbarControlHeight,
            child: shad.Button(
              key: const ValueKey<String>('connection-action-button'),
              style: connected
                  ? const shad.ButtonStyle.secondary(
                      size: shad.ButtonSize.small,
                      density: shad.ButtonDensity.dense,
                    )
                  : const shad.ButtonStyle.primary(
                      size: shad.ButtonSize.small,
                      density: shad.ButtonDensity.dense,
                    ),
              onPressed: device == null || connecting
                  ? null
                  : onToggleConnection,
              alignment: Alignment.center,
              leading: connecting
                  ? const ToolLoadingIcon()
                  : Icon(
                      connected
                          ? Icons.link_off_outlined
                          : Icons.bluetooth_connected_outlined,
                      size: 18,
                    ),
              child: Text(actionLabel),
            ),
          ),
        ),
      ],
    );
  }
}
