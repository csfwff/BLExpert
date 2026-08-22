part of '../home/home_screen.dart';

class _ConfigurationWorkspace extends StatefulWidget {
  const _ConfigurationWorkspace({
    required this.workspace,
    required this.runtimeAvailable,
    required this.onWorkspaceChanged,
    required this.onProtocolChanged,
    required this.onScriptConfigChanged,
    required this.onNewCommand,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onCommandEnabledChanged,
    required this.onCommandQuickAccessChanged,
    required this.onCommandWhitelistChanged,
    required this.onNewResponseMapping,
    required this.onEditResponseMapping,
    required this.onDeleteResponseMapping,
    required this.onImportProtocolCandidate,
    required this.onImportProtocolText,
    required this.l10n,
  });

  final Workspace workspace;
  final bool runtimeAvailable;
  final ValueChanged<Workspace> onWorkspaceChanged;
  final ValueChanged<ProtocolDefinition> onProtocolChanged;
  final ValueChanged<ScriptConfig> onScriptConfigChanged;
  final VoidCallback onNewCommand;
  final ValueChanged<CommandDefinition> onEditCommand;
  final ValueChanged<CommandDefinition> onDeleteCommand;
  final void Function(CommandDefinition, bool) onCommandEnabledChanged;
  final void Function(CommandDefinition, bool) onCommandQuickAccessChanged;
  final ValueChanged<List<String>> onCommandWhitelistChanged;
  final VoidCallback onNewResponseMapping;
  final ValueChanged<ResponseMapping> onEditResponseMapping;
  final ValueChanged<ResponseMapping> onDeleteResponseMapping;
  final VoidCallback onImportProtocolCandidate;
  final VoidCallback onImportProtocolText;
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
        onChanged: widget.onWorkspaceChanged,
        onImportProtocolCandidate: widget.onImportProtocolCandidate,
        onImportProtocolText: widget.onImportProtocolText,
        l10n: widget.l10n,
      ),
      _ProtocolConfigurationPanel(
        protocol: widget.workspace.protocol,
        scriptConfig: widget.workspace.scriptConfig,
        onProtocolChanged: widget.onProtocolChanged,
        onScriptConfigChanged: widget.onScriptConfigChanged,
        runtimeAvailable: widget.runtimeAvailable,
        l10n: widget.l10n,
      ),
      _CommandLibraryPanel(
        commands: widget.workspace.commands,
        allowedCommandIds: widget.workspace.allowedCommandIds,
        onNewCommand: widget.onNewCommand,
        onEditCommand: widget.onEditCommand,
        onDeleteCommand: widget.onDeleteCommand,
        onEnabledChanged: widget.onCommandEnabledChanged,
        onQuickAccessChanged: widget.onCommandQuickAccessChanged,
        onWhitelistChanged: widget.onCommandWhitelistChanged,
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
          narrow: narrow,
        );
        return narrow
            ? Column(
                children: <Widget>[
                  navigation,
                  const shad.Divider(height: 1),
                  Expanded(child: pages[_section]),
                ],
              )
            : Row(
                children: <Widget>[
                  SizedBox(width: 220, child: navigation),
                  const shad.VerticalDivider(width: 1),
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
    required this.narrow,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    const List<({IconData icon, String label})> items =
        <({IconData icon, String label})>[
          (icon: AppIcons.folderOutlined, label: '工作区'),
          (icon: AppIcons.accountTree, label: '协议'),
          (icon: AppIcons.listAlt, label: '指令'),
          (icon: AppIcons.dataObject, label: '响应映射'),
        ];
    final List<Widget> navigationItems = <Widget>[
      for (int index = 0; index < items.length; index++)
        shad.NavigationItem(
          key: ValueKey<String>('configuration-section-$index'),
          selectedStyle: const shad.ButtonStyle.secondary(),
          label: Text(items[index].label),
          child: Icon(items[index].icon, size: 19),
        ),
    ];

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text('配置', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          shad.NavigationBar(
            key: const ValueKey<String>('configuration-navigation-mobile'),
            expanded: true,
            labelPosition: shad.NavigationLabelPosition.bottom,
            selectedKey: ValueKey<String>('configuration-section-$value'),
            onSelected: (Key? key) {
              final String? keyValue = (key as ValueKey<String>?)?.value;
              if (keyValue == null) return;
              final int? section = int.tryParse(keyValue.split('-').last);
              if (section != null) onChanged(section);
            },
            children: navigationItems,
          ),
        ],
      );
    }

    return shad.NavigationRail(
      key: const ValueKey<String>('configuration-navigation-desktop'),
      alignment: shad.NavigationRailAlignment.start,
      expanded: true,
      expandedSize: 220,
      labelType: shad.NavigationLabelType.all,
      labelPosition: shad.NavigationLabelPosition.end,
      selectedKey: ValueKey<String>('configuration-section-$value'),
      onSelected: (Key? key) {
        final String? keyValue = (key as ValueKey<String>?)?.value;
        if (keyValue == null) return;
        final int? section = int.tryParse(keyValue.split('-').last);
        if (section != null) onChanged(section);
      },
      header: const <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text('配置', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
      children: navigationItems,
    );
  }
}
