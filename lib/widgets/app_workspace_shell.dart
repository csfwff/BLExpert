part of '../main.dart';

enum _AppMode { debug, configure, records }

class _AppIdentity extends StatelessWidget {
  const _AppIdentity({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.bluetooth_connected,
            size: 18,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'BLExpert',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              workspace.deviceModel.isEmpty
                  ? workspace.name
                  : workspace.deviceModel,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _AppOverflowMenu extends StatelessWidget {
  const _AppOverflowMenu({
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.onConfigureWebServices,
    required this.onPreviewExport,
    required this.l10n,
  });

  final ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final VoidCallback? onConfigureWebServices;
  final VoidCallback onPreviewExport;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ToolbarAction>(
      tooltip: '更多操作',
      icon: const Icon(Icons.more_vert),
      onSelected: (_ToolbarAction action) {
        switch (action) {
          case _ToolbarAction.exportPreview:
            onPreviewExport();
          case _ToolbarAction.webServices:
            onConfigureWebServices?.call();
          case _ToolbarAction.light:
            onThemeModeChanged(ThemeMode.light);
          case _ToolbarAction.dark:
            onThemeModeChanged(ThemeMode.dark);
          case _ToolbarAction.systemTheme:
            onThemeModeChanged(ThemeMode.system);
          case _ToolbarAction.chinese:
            onLocaleChanged(const Locale('zh'));
          case _ToolbarAction.english:
            onLocaleChanged(const Locale('en'));
          case _ToolbarAction.systemLanguage:
            onLocaleChanged(null);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_ToolbarAction>>[
        PopupMenuItem(
          value: _ToolbarAction.exportPreview,
          child: ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.exportWorkspacePreview),
          ),
        ),
        if (onConfigureWebServices != null)
          PopupMenuItem(
            value: _ToolbarAction.webServices,
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.webServiceUuids),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ToolbarAction.systemTheme,
          child: ListTile(
            leading: Icon(_themeModeIcon(themeMode)),
            title: Text(l10n.followSystem),
          ),
        ),
        PopupMenuItem(
          value: _ToolbarAction.light,
          child: ListTile(
            leading: const Icon(Icons.light_mode_outlined),
            title: Text(l10n.lightMode),
          ),
        ),
        PopupMenuItem(
          value: _ToolbarAction.dark,
          child: ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.darkMode),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ToolbarAction.systemLanguage,
          child: Text(l10n.followSystem),
        ),
        PopupMenuItem(value: _ToolbarAction.chinese, child: Text(l10n.chinese)),
        PopupMenuItem(value: _ToolbarAction.english, child: Text(l10n.english)),
      ],
    );
  }
}

enum _ToolbarAction {
  exportPreview,
  webServices,
  light,
  dark,
  systemTheme,
  chinese,
  english,
  systemLanguage,
}

class _AppWorkspaceShell extends StatelessWidget {
  const _AppWorkspaceShell({
    required this.mode,
    required this.onModeChanged,
    required this.inspectorOpen,
    required this.onInspectorVisibilityChanged,
    required this.debugPane,
    required this.devicePane,
    required this.inspectorPane,
    required this.configurationPane,
    required this.recordPane,
  });

  final _AppMode mode;
  final ValueChanged<_AppMode> onModeChanged;
  final bool inspectorOpen;
  final ValueChanged<bool> onInspectorVisibilityChanged;
  final Widget debugPane;
  final Widget devicePane;
  final Widget inspectorPane;
  final Widget configurationPane;
  final Widget recordPane;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool desktop = constraints.maxWidth >= 900;
        final Widget content = switch (mode) {
          _AppMode.debug => _DebugWorkspace(
            devicePane: devicePane,
            consolePane: debugPane,
            inspectorPane: inspectorPane,
            inspectorOpen: inspectorOpen,
            onInspectorVisibilityChanged: onInspectorVisibilityChanged,
          ),
          _AppMode.configure => configurationPane,
          _AppMode.records => recordPane,
        };
        if (desktop) {
          return Row(
            children: <Widget>[
              _ModeRail(value: mode, onChanged: onModeChanged),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        }
        return Column(
          children: <Widget>[
            Expanded(child: content),
            const Divider(height: 1),
            NavigationBar(
              selectedIndex: mode.index,
              onDestinationSelected: (int index) =>
                  onModeChanged(_AppMode.values[index]),
              destinations: const <Widget>[
                NavigationDestination(
                  icon: Icon(Icons.terminal_outlined),
                  label: '调试',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  label: '配置',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  label: '记录',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ModeRail extends StatelessWidget {
  const _ModeRail({required this.value, required this.onChanged});

  final _AppMode value;
  final ValueChanged<_AppMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: value.index,
      labelType: NavigationRailLabelType.all,
      minWidth: 76,
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.terminal_outlined),
          selectedIcon: Icon(Icons.terminal),
          label: Text('调试'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune),
          label: Text('配置'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: Text('记录'),
        ),
      ],
      onDestinationSelected: (int index) => onChanged(_AppMode.values[index]),
    );
  }
}

class _DebugWorkspace extends StatelessWidget {
  const _DebugWorkspace({
    required this.devicePane,
    required this.consolePane,
    required this.inspectorPane,
    required this.inspectorOpen,
    required this.onInspectorVisibilityChanged,
  });

  final Widget devicePane;
  final Widget consolePane;
  final Widget inspectorPane;
  final bool inspectorOpen;
  final ValueChanged<bool> onInspectorVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 680) {
          return DefaultTabController(
            length: 3,
            child: Column(
              children: <Widget>[
                const TabBar(
                  tabs: <Widget>[
                    Tab(text: '控制台'),
                    Tab(text: '设备'),
                    Tab(text: '上下文'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[consolePane, devicePane, inspectorPane],
                  ),
                ),
              ],
            ),
          );
        }
        return Row(
          children: <Widget>[
            SizedBox(width: 240, child: devicePane),
            const VerticalDivider(width: 1),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: consolePane),
                  Positioned(
                    top: 6,
                    right: 8,
                    child: IconButton(
                      tooltip: inspectorOpen ? '收起上下文面板' : '展开上下文面板',
                      onPressed: () =>
                          onInspectorVisibilityChanged(!inspectorOpen),
                      icon: Icon(
                        inspectorOpen
                            ? Icons.keyboard_double_arrow_right_outlined
                            : Icons.keyboard_double_arrow_left_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (inspectorOpen) ...<Widget>[
              const VerticalDivider(width: 1),
              SizedBox(width: 320, child: inspectorPane),
            ],
          ],
        );
      },
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.characteristics,
    required this.canSend,
    required this.onSendCommand,
    required this.commands,
    required this.responseMappings,
    required this.monitoredValues,
    required this.l10n,
  });

  final List<BluetoothCharacteristicInfo> characteristics;
  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>)
  onSendCommand;
  final List<CommandDefinition> commands;
  final List<ResponseMapping> responseMappings;
  final Map<String, _MonitoredFieldValue> monitoredValues;
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
            style: Theme.of(context).textTheme.labelSmall,
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

class _ConfigurationWorkspace extends StatefulWidget {
  const _ConfigurationWorkspace({
    required this.workspace,
    required this.onEditWorkspace,
    required this.onProtocolChanged,
    required this.onScriptConfigChanged,
    required this.onNewCommand,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onCommandEnabledChanged,
    required this.onCommandQuickAccessChanged,
    required this.onNewResponseMapping,
    required this.onEditResponseMapping,
    required this.onDeleteResponseMapping,
    required this.l10n,
  });

  final Workspace workspace;
  final VoidCallback onEditWorkspace;
  final ValueChanged<ProtocolDefinition> onProtocolChanged;
  final ValueChanged<ScriptConfig> onScriptConfigChanged;
  final VoidCallback onNewCommand;
  final ValueChanged<CommandDefinition> onEditCommand;
  final ValueChanged<CommandDefinition> onDeleteCommand;
  final void Function(CommandDefinition, bool) onCommandEnabledChanged;
  final void Function(CommandDefinition, bool) onCommandQuickAccessChanged;
  final VoidCallback onNewResponseMapping;
  final ValueChanged<ResponseMapping> onEditResponseMapping;
  final ValueChanged<ResponseMapping> onDeleteResponseMapping;
  final AppLocalizations l10n;

  @override
  State<_ConfigurationWorkspace> createState() =>
      _ConfigurationWorkspaceState();
}

class _ConfigurationWorkspaceState extends State<_ConfigurationWorkspace> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _WorkspaceOverview(
        workspace: widget.workspace,
        onEdit: widget.onEditWorkspace,
        l10n: widget.l10n,
      ),
      _ProtocolConfigurationPanel(
        protocol: widget.workspace.protocol,
        scriptConfig: widget.workspace.scriptConfig,
        onProtocolChanged: widget.onProtocolChanged,
        onScriptConfigChanged: widget.onScriptConfigChanged,
        runtimeAvailable: !kIsWeb,
        l10n: widget.l10n,
      ),
      _CommandLibraryPanel(
        commands: widget.workspace.commands,
        onNewCommand: widget.onNewCommand,
        onEditCommand: widget.onEditCommand,
        onDeleteCommand: widget.onDeleteCommand,
        onEnabledChanged: widget.onCommandEnabledChanged,
        onQuickAccessChanged: widget.onCommandQuickAccessChanged,
        l10n: widget.l10n,
      ),
      _DataMappingLibraryPanel(
        mappings: widget.workspace.responseMappings,
        onNew: widget.onNewResponseMapping,
        onEdit: widget.onEditResponseMapping,
        onDelete: widget.onDeleteResponseMapping,
        l10n: widget.l10n,
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < 680;
        final Widget navigation = _ConfigurationNavigation(
          value: _section,
          onChanged: (int value) => setState(() => _section = value),
        );
        return narrow
            ? Column(
                children: <Widget>[
                  navigation,
                  const Divider(height: 1),
                  Expanded(child: pages[_section]),
                ],
              )
            : Row(
                children: <Widget>[
                  SizedBox(width: 220, child: navigation),
                  const VerticalDivider(width: 1),
                  Expanded(child: pages[_section]),
                ],
              );
      },
    );
  }
}

class _ConfigurationNavigation extends StatelessWidget {
  const _ConfigurationNavigation({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<({IconData icon, String label})> items =
        <({IconData icon, String label})>[
          (icon: Icons.folder_outlined, label: '工作区'),
          (icon: Icons.account_tree_outlined, label: '协议'),
          (icon: Icons.list_alt_outlined, label: '指令'),
          (icon: Icons.data_object_outlined, label: '响应映射'),
        ];
    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Text('配置', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        for (int index = 0; index < items.length; index++)
          ListTile(
            dense: true,
            selected: value == index,
            leading: Icon(items[index].icon, size: 20),
            title: Text(items[index].label),
            onTap: () => onChanged(index),
          ),
      ],
    );
  }
}

class _RecordWorkspace extends StatefulWidget {
  const _RecordWorkspace({
    required this.logs,
    required this.l10n,
    required this.onExport,
  });

  final List<SessionLogRecord> logs;
  final AppLocalizations l10n;
  final ValueChanged<List<SessionLogRecord>> onExport;

  @override
  State<_RecordWorkspace> createState() => _RecordWorkspaceState();
}

class _RecordWorkspaceState extends State<_RecordWorkspace> {
  final TextEditingController _filterController = TextEditingController();
  SessionLogKind? _kindFilter;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<SessionLogRecord> _filteredLogs() {
    final String query = _filterController.text.trim().toLowerCase();
    return widget.logs
        .where((SessionLogRecord log) {
          if (_kindFilter != null && log.kind != _kindFilter) return false;
          if (query.isEmpty) return true;
          final String payload = log.message ?? _toHex(log.data);
          return payload.toLowerCase().contains(query) ||
              log.kind.name.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<SessionLogRecord> filteredLogs = _filteredLogs();
    return Column(
      children: <Widget>[
        _PanelHeading(
          title: '会话记录',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${filteredLogs.length}/${widget.logs.length} 条',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: '导出会话记录',
                onPressed: filteredLogs.isEmpty
                    ? null
                    : () => widget.onExport(filteredLogs),
                icon: const Icon(Icons.download_outlined, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _filterController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: '搜索文本或 HEX',
              suffixIcon: _filterController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除筛选',
                      onPressed: () {
                        _filterController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear, size: 18),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: <Widget>[
              _filterChip('全部', null),
              _filterChip('TX', SessionLogKind.sent),
              _filterChip('RX', SessionLogKind.received),
              _filterChip('SYS', SessionLogKind.system),
              _filterChip('ERR', SessionLogKind.error),
            ],
          ),
        ),
        Expanded(
          child: filteredLogs.isEmpty
              ? Center(child: Text(widget.l10n.noData))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, int index) =>
                      _LogLine(entry: filteredLogs[index], l10n: widget.l10n),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, SessionLogKind? kind) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: FilterChip(
      label: Text(label),
      selected: _kindFilter == kind,
      onSelected: (_) => setState(() => _kindFilter = kind),
      visualDensity: VisualDensity.compact,
    ),
  );
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.data_object_outlined,
            size: 17,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            Flexible(
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.end,
                child: trailing!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _shortUuid(String value) =>
    value.length <= 8 ? value : value.substring(0, 8).toUpperCase();

String _localizedInspectorTitle(AppLocalizations l10n) =>
    l10n.console == 'Console' ? 'Current context' : '当前上下文';

String _localizedNoWriteTarget(AppLocalizations l10n) =>
    l10n.console == 'Console' ? 'No write target' : '未选写入特征';
