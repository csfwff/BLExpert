part of '../features/home/home_screen.dart';

enum _AppMode { debug, configure, records, settings }

enum _LanguagePreference { system, chinese, english }

class _AppIdentity extends StatelessWidget {
  const _AppIdentity();

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.secondary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            AppIcons.bluetoothConnected,
            size: 18,
            color: colors.secondaryForeground,
          ),
        ),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'BLExpert',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _AppOverflowMenu extends StatelessWidget {
  const _AppOverflowMenu({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.includeAppearance,
    required this.onConfigureWebServices,
    required this.l10n,
  });

  final shad.ThemeMode themeMode;
  final ValueChanged<shad.ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final bool includeAppearance;
  final VoidCallback? onConfigureWebServices;
  final AppLocalizations l10n;

  void _select(_ToolbarAction action) {
    switch (action) {
      case _ToolbarAction.webServices:
        onConfigureWebServices?.call();
      case _ToolbarAction.light:
        onThemeModeChanged(shad.ThemeMode.light);
      case _ToolbarAction.dark:
        onThemeModeChanged(shad.ThemeMode.dark);
      case _ToolbarAction.systemTheme:
        onThemeModeChanged(shad.ThemeMode.system);
      case _ToolbarAction.chinese:
        onLocaleChanged(const Locale('zh'));
      case _ToolbarAction.english:
        onLocaleChanged(const Locale('en'));
      case _ToolbarAction.systemLanguage:
        onLocaleChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolIconButton(
      tooltip: '更多操作',
      icon: const Icon(AppIcons.moreVertical),
      onPressed: () => shad
          .showDropdown<void>(
            context: context,
            widthConstraint: shad.PopoverConstraint.flexible,
            builder: (BuildContext context) => shad.DropdownMenu(
              children: <shad.MenuItem>[
                if (onConfigureWebServices != null)
                  shad.MenuButton(
                    leading: const Icon(AppIcons.tune),
                    onPressed: (_) => _select(_ToolbarAction.webServices),
                    child: Text(l10n.webServiceUuids),
                  ),
                if (onConfigureWebServices != null && includeAppearance)
                  const shad.MenuDivider(),
                if (includeAppearance) ...<shad.MenuItem>[
                  shad.MenuButton(
                    leading: Icon(_themeModeIcon(themeMode)),
                    onPressed: (_) => _select(_ToolbarAction.systemTheme),
                    child: Text(l10n.followSystem),
                  ),
                  shad.MenuButton(
                    leading: const Icon(AppIcons.lightMode),
                    onPressed: (_) => _select(_ToolbarAction.light),
                    child: Text(l10n.lightMode),
                  ),
                  shad.MenuButton(
                    leading: const Icon(AppIcons.darkMode),
                    onPressed: (_) => _select(_ToolbarAction.dark),
                    child: Text(l10n.darkMode),
                  ),
                  const shad.MenuDivider(),
                  shad.MenuButton(
                    onPressed: (_) => _select(_ToolbarAction.systemLanguage),
                    child: Text(l10n.followSystem),
                  ),
                  shad.MenuButton(
                    onPressed: (_) => _select(_ToolbarAction.chinese),
                    child: Text(l10n.chinese),
                  ),
                  shad.MenuButton(
                    onPressed: (_) => _select(_ToolbarAction.english),
                    child: Text(l10n.english),
                  ),
                ],
              ],
            ),
          )
          .future,
    );
  }
}

enum _ToolbarAction {
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
    required this.l10n,
    required this.inspectorOpen,
    required this.onInspectorVisibilityChanged,
    required this.debugPane,
    required this.devicePane,
    required this.inspectorPane,
    required this.configurationPane,
    required this.recordPane,
    required this.settingsPane,
  });

  final _AppMode mode;
  final ValueChanged<_AppMode> onModeChanged;
  final AppLocalizations l10n;
  final bool inspectorOpen;
  final ValueChanged<bool> onInspectorVisibilityChanged;
  final Widget debugPane;
  final Widget devicePane;
  final Widget inspectorPane;
  final Widget configurationPane;
  final Widget recordPane;
  final Widget settingsPane;

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
          _AppMode.settings => settingsPane,
        };
        if (desktop) {
          return Row(
            children: <Widget>[
              _ModeRail(value: mode, onChanged: onModeChanged, l10n: l10n),
              const shad.VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        }
        final List<({IconData icon, String label})> mobileItems =
            <({IconData icon, String label})>[
              (icon: AppIcons.terminalOutlined, label: l10n.debug),
              (icon: AppIcons.tuneOutlined, label: l10n.configure),
              (icon: AppIcons.historyOutlined, label: l10n.records),
              (icon: AppIcons.settingsOutlined, label: l10n.settings),
            ];
        return Column(
          children: <Widget>[
            Expanded(child: content),
            const shad.Divider(height: 1),
            SafeArea(
              top: false,
              child: shad.NavigationBar(
                key: const ValueKey<String>('app-mode-navigation-mobile'),
                expanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                spacing: 0,
                children: <Widget>[
                  for (int index = 0; index < mobileItems.length; index++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ToolSelectedButton(
                          key: ValueKey<String>(
                            'app-mode-${_AppMode.values[index].name}',
                          ),
                          value: mode == _AppMode.values[index],
                          onChanged: (bool selected) {
                            if (selected) {
                              onModeChanged(_AppMode.values[index]);
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(mobileItems[index].icon, size: 20),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  mobileItems[index].label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: AppTheme.textStylesOf(
                                    context,
                                  ).labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeRail extends StatelessWidget {
  const _ModeRail({
    required this.value,
    required this.onChanged,
    required this.l10n,
  });

  final _AppMode value;
  final ValueChanged<_AppMode> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<({_AppMode mode, IconData icon, String label})> items =
        <({_AppMode mode, IconData icon, String label})>[
          (
            mode: _AppMode.debug,
            icon: AppIcons.terminalOutlined,
            label: l10n.debug,
          ),
          (
            mode: _AppMode.configure,
            icon: AppIcons.tuneOutlined,
            label: l10n.configure,
          ),
          (
            mode: _AppMode.records,
            icon: AppIcons.historyOutlined,
            label: l10n.records,
          ),
          (
            mode: _AppMode.settings,
            icon: AppIcons.settingsOutlined,
            label: l10n.settings,
          ),
        ];
    return SizedBox(
      width: 88,
      child: shad.NavigationRail(
        key: const ValueKey<String>('app-mode-navigation'),
        alignment: shad.NavigationRailAlignment.start,
        expanded: true,
        expandedSize: 88,
        labelType: shad.NavigationLabelType.all,
        labelPosition: shad.NavigationLabelPosition.bottom,
        selectedKey: ValueKey<String>('app-mode-${value.name}'),
        children: <Widget>[
          for (final item in items)
            ToolSelectedButton(
              key: ValueKey<String>('app-mode-${item.mode.name}'),
              value: value == item.mode,
              onChanged: (bool selected) {
                if (selected) onChanged(item.mode);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(item.icon, size: 20),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        style: AppTheme.textStylesOf(context).labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsWorkspace extends StatelessWidget {
  const _SettingsWorkspace({
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.l10n,
  });

  final shad.ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<shad.ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 680;
    final _LanguagePreference language = switch (locale?.languageCode) {
      'zh' => _LanguagePreference.chinese,
      'en' => _LanguagePreference.english,
      _ => _LanguagePreference.system,
    };
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 16 : 32,
        vertical: narrow ? 20 : 28,
      ),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      AppIcons.settingsOutlined,
                      color: AppTheme.colorsOf(context).secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.settings,
                      style: AppTheme.textStylesOf(
                        context,
                      ).titleLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SettingsSection(
                  icon: AppIcons.contrastOutlined,
                  title: l10n.themeMode,
                  child: KeyedSubtree(
                    key: const ValueKey<String>('theme-mode-selector'),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ThemeModeButton(
                          value: shad.ThemeMode.system,
                          currentValue: themeMode,
                          icon: AppIcons.brightnessAuto,
                          label: l10n.followSystem,
                          onChanged: onThemeModeChanged,
                        ),
                        _ThemeModeButton(
                          value: shad.ThemeMode.light,
                          currentValue: themeMode,
                          icon: AppIcons.lightMode,
                          label: l10n.lightMode,
                          onChanged: onThemeModeChanged,
                        ),
                        _ThemeModeButton(
                          value: shad.ThemeMode.dark,
                          currentValue: themeMode,
                          icon: AppIcons.darkMode,
                          label: l10n.darkMode,
                          onChanged: onThemeModeChanged,
                        ),
                      ],
                    ),
                  ),
                ),
                const shad.Divider(height: 40),
                _SettingsSection(
                  icon: AppIcons.languageOutlined,
                  title: l10n.language,
                  child: ToolSelect<_LanguagePreference>(
                    key: const ValueKey<String>('language-selector'),
                    value: language,
                    options: <ToolSelectOption<_LanguagePreference>>[
                      ToolSelectOption<_LanguagePreference>(
                        value: _LanguagePreference.system,
                        label: l10n.followSystem,
                      ),
                      ToolSelectOption<_LanguagePreference>(
                        value: _LanguagePreference.chinese,
                        label: l10n.chinese,
                      ),
                      ToolSelectOption<_LanguagePreference>(
                        value: _LanguagePreference.english,
                        label: l10n.english,
                      ),
                    ],
                    onChanged: (_LanguagePreference value) {
                      onLocaleChanged(switch (value) {
                        _LanguagePreference.system => null,
                        _LanguagePreference.chinese => const Locale('zh'),
                        _LanguagePreference.english => const Locale('en'),
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton({
    required this.value,
    required this.currentValue,
    required this.icon,
    required this.label,
    required this.onChanged,
  });

  final shad.ThemeMode value;
  final shad.ThemeMode currentValue;
  final IconData icon;
  final String label;
  final ValueChanged<shad.ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return ToolSelectedButton(
      value: currentValue == value,
      onChanged: (bool selected) {
        if (selected) onChanged(value);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 20, color: AppTheme.colorsOf(context).secondary),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTheme.textStylesOf(
                context,
              ).titleSmall.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _DebugWorkspace extends StatefulWidget {
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
  State<_DebugWorkspace> createState() => _DebugWorkspaceState();
}

class _DebugWorkspaceState extends State<_DebugWorkspace> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: <Widget>[
              shad.Tabs(
                index: _tabIndex,
                expand: true,
                onChanged: (int value) => setState(() => _tabIndex = value),
                children: const <shad.TabItem>[
                  shad.TabItem(child: Text('控制台')),
                  shad.TabItem(child: Text('设备')),
                  shad.TabItem(child: Text('上下文')),
                ],
              ),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: <Widget>[
                    widget.consolePane,
                    widget.devicePane,
                    widget.inspectorPane,
                  ],
                ),
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            SizedBox(width: 240, child: widget.devicePane),
            const shad.VerticalDivider(width: 1),
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: widget.consolePane),
                  Positioned(
                    top: 6,
                    right: 8,
                    child: ToolIconButton(
                      tooltip: widget.inspectorOpen ? '收起上下文面板' : '展开上下文面板',
                      onPressed: () => widget.onInspectorVisibilityChanged(
                        !widget.inspectorOpen,
                      ),
                      icon: Icon(
                        widget.inspectorOpen
                            ? AppIcons.chevronsRight
                            : AppIcons.chevronsLeft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.inspectorOpen) ...<Widget>[
              const shad.VerticalDivider(width: 1),
              SizedBox(width: 320, child: widget.inspectorPane),
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
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            AppIcons.dataObject,
            size: 17,
            color: AppTheme.colorsOf(context).secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.textStylesOf(
                context,
              ).titleSmall.copyWith(fontWeight: FontWeight.w700),
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
