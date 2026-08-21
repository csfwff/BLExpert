part of 'home_screen.dart';

class _WorkspaceSelector extends StatelessWidget {
  const _WorkspaceSelector({
    required this.workspace,
    required this.workspaces,
    required this.compact,
    required this.onSelected,
    required this.onNew,
    required this.onDelete,
    required this.onExportCurrent,
    required this.onExportAll,
    required this.onImport,
    required this.l10n,
  });
  final Workspace workspace;
  final List<Workspace> workspaces;
  final bool compact;
  final ValueChanged<String> onSelected;
  final VoidCallback onNew;
  final VoidCallback onDelete;
  final VoidCallback onExportCurrent;
  final VoidCallback onExportAll;
  final VoidCallback onImport;
  final AppLocalizations l10n;

  static const double _toolbarControlHeight = 36;
  static const double _toolbarControlWidth = 136;
  static const double _toolbarControlGap = 8;
  static const double _compactToolbarBreakpoint = 760;

  void _showWorkspaceMenu(BuildContext context) {
    shad
        .showDropdown<void>(
          context: context,
          widthConstraint: shad.PopoverConstraint.flexible,
          showDuration: AppMotion.overlay,
          dismissDuration: AppMotion.overlay,
          builder: (BuildContext context) => SizedBox(
            width: compact ? null : 200,
            child: shad.DropdownMenu(
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
                  onPressed: (_) => onExportCurrent(),
                  child: const Text(
                    '导出当前工作区',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                shad.MenuButton(
                  leading: const Icon(AppIcons.uploadFile),
                  onPressed: (_) => onExportAll(),
                  child: const Text(
                    '导出全部工作区',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        )
        .future;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle toolbarTextStyle = AppTheme.of(context).typography.xSmall;
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
                  style: toolbarTextStyle,
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
    final TextStyle toolbarTextStyle = AppTheme.of(context).typography.xSmall;
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
          child: Text(
            label,
            style: toolbarTextStyle,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

class _CompactDeviceSelectItem extends StatelessWidget {
  const _CompactDeviceSelectItem({required this.value, required this.child});

  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shad.SelectPopupHandle? data =
        shad.Data.maybeOf<shad.SelectPopupHandle>(context);
    final bool isSelected = data?.isSelected(value) ?? false;
    final bool hasSelection = data?.hasSelection ?? false;

    return SizedBox(
      key: ValueKey<String>('bluetooth-device-option-$value'),
      height: 24,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              data?.selectItem(value, !isSelected);
              return null;
            },
          ),
        },
        child: shad.SubFocus(
          builder: (BuildContext context, shad.SubFocusState state) =>
              shad.WidgetStatesProvider(
                states: <WidgetState>{if (state.isFocused) WidgetState.hovered},
                child: shad.Button(
                  disableTransition: true,
                  alignment: AlignmentDirectional.centerStart,
                  onPressed: () => data?.selectItem(value, !isSelected),
                  style: const shad.ButtonStyle.ghost().copyWith(
                    padding: (_, _, _) =>
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    mouseCursor: (_, _, _) => SystemMouseCursors.basic,
                  ),
                  trailing: isSelected
                      ? const Icon(shad.LucideIcons.check, size: 14)
                      : hasSelection
                      ? const SizedBox(width: 14)
                      : null,
                  child: child,
                ),
              ),
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
    final TextStyle toolbarTextStyle = AppTheme.of(context).typography.xSmall;
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
              placeholder: Text(l10n.noDevice, style: toolbarTextStyle),
              constraints: const BoxConstraints.tightFor(
                height: _WorkspaceSelector._toolbarControlHeight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              popupConstraints: const BoxConstraints(maxHeight: 280),
              popoverAlignment: Alignment.topCenter,
              popoverAnchorAlignment: Alignment.bottomCenter,
              itemBuilder: (BuildContext context, String deviceId) {
                final BluetoothDeviceInfo item = devices.firstWhere(
                  (BluetoothDeviceInfo item) => item.id == deviceId,
                );
                return Text(
                  item.name,
                  style: toolbarTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
              onChanged: devices.isEmpty ? null : onSelected,
              popup: shad.SelectPopup<String>(
                items: shad.SelectItemList(
                  children: devices
                      .map(
                        (BluetoothDeviceInfo item) => _CompactDeviceSelectItem(
                          value: item.id,
                          child: Text(
                            item.name,
                            style: toolbarTextStyle,
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
                child: Text(
                  buttonLabel,
                  style: toolbarTextStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
