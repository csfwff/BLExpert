part of '../../main.dart';

class _ConfigurationWorkspace extends StatefulWidget {
  const _ConfigurationWorkspace({
    required this.workspace,
    required this.runtimeAvailable,
    required this.onEditWorkspace,
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
    required this.l10n,
  });

  final Workspace workspace;
  final bool runtimeAvailable;
  final VoidCallback onEditWorkspace;
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
