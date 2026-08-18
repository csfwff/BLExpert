part of '../main.dart';

enum _AppMode { debug, configure, records }

class _AppIdentity extends StatelessWidget {
  const _AppIdentity({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = MediaQuery.sizeOf(context).width < 680;
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
        Flexible(
          child: compact
              ? const Text(
                  'BLExpert',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                )
              : Column(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
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
    required this.onExportWorkspaces,
    required this.onImportWorkspaces,
    required this.l10n,
  });

  final ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final VoidCallback? onConfigureWebServices;
  final VoidCallback onExportWorkspaces;
  final VoidCallback onImportWorkspaces;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ToolbarAction>(
      tooltip: '更多操作',
      icon: const Icon(Icons.more_vert),
      onSelected: (_ToolbarAction action) {
        switch (action) {
          case _ToolbarAction.exportWorkspaces:
            onExportWorkspaces();
          case _ToolbarAction.importWorkspaces:
            onImportWorkspaces();
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
          value: _ToolbarAction.exportWorkspaces,
          child: ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('导出工作区'),
          ),
        ),
        PopupMenuItem(
          value: _ToolbarAction.importWorkspaces,
          child: const ListTile(
            leading: Icon(Icons.download_outlined),
            title: Text('导入工作区'),
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
  exportWorkspaces,
  importWorkspaces,
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
