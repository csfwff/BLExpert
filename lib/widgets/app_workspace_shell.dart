part of '../main.dart';

enum _AppMode { debug, configure, records, settings }

enum _LanguagePreference { system, chinese, english }

class _AppIdentity extends StatelessWidget {
  const _AppIdentity();

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

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final bool includeAppearance;
  final VoidCallback? onConfigureWebServices;
  final AppLocalizations l10n;

  void _select(_ToolbarAction action) {
    switch (action) {
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
  }

  @override
  Widget build(BuildContext context) {
    return ToolIconButton(
      tooltip: '更多操作',
      icon: const Icon(Icons.more_vert),
      onPressed: () => shad
          .showDropdown<void>(
            context: context,
            widthConstraint: shad.PopoverConstraint.flexible,
            builder: (BuildContext context) => shad.DropdownMenu(
              children: <shad.MenuItem>[
                if (onConfigureWebServices != null)
                  shad.MenuButton(
                    leading: const Icon(Icons.tune),
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
                    leading: const Icon(Icons.light_mode_outlined),
                    onPressed: (_) => _select(_ToolbarAction.light),
                    child: Text(l10n.lightMode),
                  ),
                  shad.MenuButton(
                    leading: const Icon(Icons.dark_mode_outlined),
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
              destinations: <Widget>[
                NavigationDestination(
                  icon: Icon(Icons.terminal_outlined),
                  label: l10n.debug,
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  label: l10n.configure,
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  label: l10n.records,
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: l10n.settings,
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
    final List<
      ({_AppMode mode, IconData icon, IconData selectedIcon, String label})
    >
    items =
        <({_AppMode mode, IconData icon, IconData selectedIcon, String label})>[
          (
            mode: _AppMode.debug,
            icon: Icons.terminal_outlined,
            selectedIcon: Icons.terminal,
            label: l10n.debug,
          ),
          (
            mode: _AppMode.configure,
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune,
            label: l10n.configure,
          ),
          (
            mode: _AppMode.records,
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
            label: l10n.records,
          ),
          (
            mode: _AppMode.settings,
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: l10n.settings,
          ),
        ];
    return SizedBox(
      width: 76,
      child: shad.NavigationRail(
        key: const ValueKey<String>('app-mode-navigation'),
        alignment: shad.NavigationRailAlignment.start,
        expanded: true,
        expandedSize: 76,
        labelType: shad.NavigationLabelType.all,
        labelPosition: shad.NavigationLabelPosition.bottom,
        selectedKey: ValueKey<String>('app-mode-${value.name}'),
        children: <Widget>[
          for (final item in items)
            shad.SelectedButton(
              key: ValueKey<String>('app-mode-${item.mode.name}'),
              value: value == item.mode,
              style: const shad.ButtonStyle.ghost(
                size: shad.ButtonSize.small,
                density: shad.ButtonDensity.compact,
              ),
              selectedStyle: const shad.ButtonStyle.secondary(
                size: shad.ButtonSize.small,
                density: shad.ButtonDensity.compact,
              ),
              onChanged: (bool selected) {
                if (selected) onChanged(item.mode);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      value == item.mode ? item.selectedIcon : item.icon,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
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

  final ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
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
                      Icons.settings_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.settings,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SettingsSection(
                  icon: Icons.contrast_outlined,
                  title: l10n.themeMode,
                  child: KeyedSubtree(
                    key: const ValueKey<String>('theme-mode-selector'),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ThemeModeButton(
                          value: ThemeMode.system,
                          currentValue: themeMode,
                          icon: Icons.brightness_auto_outlined,
                          label: l10n.followSystem,
                          onChanged: onThemeModeChanged,
                        ),
                        _ThemeModeButton(
                          value: ThemeMode.light,
                          currentValue: themeMode,
                          icon: Icons.light_mode_outlined,
                          label: l10n.lightMode,
                          onChanged: onThemeModeChanged,
                        ),
                        _ThemeModeButton(
                          value: ThemeMode.dark,
                          currentValue: themeMode,
                          icon: Icons.dark_mode_outlined,
                          label: l10n.darkMode,
                          onChanged: onThemeModeChanged,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 40),
                _SettingsSection(
                  icon: Icons.language_outlined,
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

  final ThemeMode value;
  final ThemeMode currentValue;
  final IconData icon;
  final String label;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return shad.SelectedButton(
      value: currentValue == value,
      style: const shad.ButtonStyle.outline(
        size: shad.ButtonSize.small,
        density: shad.ButtonDensity.dense,
      ),
      selectedStyle: const shad.ButtonStyle.secondary(
        size: shad.ButtonSize.small,
        density: shad.ButtonDensity.dense,
      ),
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
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
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
                    child: ToolIconButton(
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
