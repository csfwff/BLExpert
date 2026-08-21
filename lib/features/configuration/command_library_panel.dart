part of '../home/home_screen.dart';

class _CommandLibraryPanel extends StatelessWidget {
  const _CommandLibraryPanel({
    required this.commands,
    required this.allowedCommandIds,
    required this.onNewCommand,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onEnabledChanged,
    required this.onQuickAccessChanged,
    required this.onWhitelistChanged,
    required this.l10n,
  });

  final List<CommandDefinition> commands;
  final List<String> allowedCommandIds;
  final VoidCallback onNewCommand;
  final ValueChanged<CommandDefinition> onEditCommand;
  final ValueChanged<CommandDefinition> onDeleteCommand;
  final void Function(CommandDefinition, bool) onEnabledChanged;
  final void Function(CommandDefinition, bool) onQuickAccessChanged;
  final ValueChanged<List<String>> onWhitelistChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool whitelistEnabled = allowedCommandIds.isNotEmpty;
    final Map<String, List<CommandDefinition>> byGroup =
        <String, List<CommandDefinition>>{};
    for (final CommandDefinition command in commands) {
      byGroup
          .putIfAbsent(command.group.isEmpty ? '-' : command.group, () {
            return <CommandDefinition>[];
          })
          .add(command);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.commandLibrary,
                style: AppTheme.textStylesOf(
                  context,
                ).titleMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ToolTooltip(
              message: l10n.newCommand,
              child: ToolButton.primary(
                key: const ValueKey<String>('new-command-button'),
                onPressed: onNewCommand,
                compact: true,
                height: 32,
                leading: const Icon(AppIcons.add, size: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(l10n.newCommand),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ToolSwitchTile(
          title: const Text('仅允许已选指令发送'),
          subtitle: Text(
            whitelistEnabled
                ? '当前允许 ${allowedCommandIds.length} 条指令；手动控制台发送不受影响。'
                : '关闭时所有已启用指令都可发送；手动控制台发送不受影响。',
          ),
          value: whitelistEnabled,
          onChanged: commands.isEmpty
              ? null
              : (bool enabled) async {
                  if (!enabled) {
                    onWhitelistChanged(const <String>[]);
                    return;
                  }
                  final List<String>? selected = await _selectWhitelist(
                    context,
                    commands,
                    allowedCommandIds,
                  );
                  if (selected != null && selected.isNotEmpty) {
                    onWhitelistChanged(selected);
                  }
                },
        ),
        const SizedBox(height: 8),
        if (commands.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text(l10n.noCommands)),
          )
        else
          ...byGroup.entries.expand(
            (MapEntry<String, List<CommandDefinition>> entry) => <Widget>[
              if (entry.key != '-') ...<Widget>[
                const shad.Divider(height: 16),
                Text(
                  entry.key,
                  style: AppTheme.textStylesOf(context).labelLarge,
                ),
                const SizedBox(height: 4),
              ],
              ...entry.value.map(
                (CommandDefinition command) => _CommandLibraryTile(
                  command: command,
                  onEdit: () => onEditCommand(command),
                  onDelete: () => onDeleteCommand(command),
                  onEnabledChanged: (bool value) =>
                      onEnabledChanged(command, value),
                  onQuickAccessChanged: (bool value) =>
                      onQuickAccessChanged(command, value),
                  l10n: l10n,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<List<String>?> _selectWhitelist(
    BuildContext context,
    List<CommandDefinition> commands,
    List<String> currentIds,
  ) async {
    final Set<String> selectedIds = currentIds.isEmpty
        ? commands.map((CommandDefinition command) => command.id).toSet()
        : currentIds.toSet();
    return showToolDialog<List<String>>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            ToolAlertDialog(
              icon: AppIcons.verifiedUser,
              title: '选择允许发送的指令',
              content: SizedBox(
                width: 440,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('未选中的可复用指令将被拒绝，手动控制台发送不受影响。'),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: <Widget>[
                            for (final CommandDefinition command in commands)
                              ToolCheckboxTile(
                                title: Text(command.name),
                                subtitle: Text(
                                  command.group.isEmpty
                                      ? command.payload
                                      : command.group,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                value: selectedIds.contains(command.id),
                                onChanged: (bool value) => setDialogState(() {
                                  if (value) {
                                    selectedIds.add(command.id);
                                  } else {
                                    selectedIds.remove(command.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                ToolButton.ghost(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ToolButton.primary(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          selectedIds.toList(growable: false),
                        ),
                  child: const Text('保存'),
                ),
              ],
            ),
      ),
    );
  }
}

class _CommandLibraryTile extends StatelessWidget {
  const _CommandLibraryTile({
    required this.command,
    required this.onEdit,
    required this.onDelete,
    required this.onEnabledChanged,
    required this.onQuickAccessChanged,
    required this.l10n,
  });

  final CommandDefinition command;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onQuickAccessChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('command-library-item-${command.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.colorsOf(context).border),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ToolClickableRow(
              onPressed: onEdit,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(command.name),
                  const SizedBox(height: 3),
                  Text(
                    command.payload,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.textStylesOf(
                      context,
                    ).bodySmall.merge(AppFonts.monoStyle),
                  ),
                  if (command.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        command.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.textStylesOf(context).labelSmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            key: ValueKey<String>(
              'command-library-status-controls-${command.id}',
            ),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _CommandStatusControl(
                key: ValueKey<String>(
                  'command-library-enabled-control-${command.id}',
                ),
                label: l10n.commandEnabled,
                child: ToolSwitch(
                  value: command.enabled,
                  onChanged: onEnabledChanged,
                  label: l10n.commandEnabled,
                ),
              ),
              const SizedBox(width: 8),
              _CommandStatusControl(
                key: ValueKey<String>(
                  'command-library-quick-access-control-${command.id}',
                ),
                label: l10n.quickAccess,
                child: ToolCheckbox(
                  value: command.isQuickAccess,
                  onChanged: onQuickAccessChanged,
                  label: l10n.quickAccess,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Row(
            key: ValueKey<String>('command-library-actions-${command.id}'),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ToolIconButton(
                tooltip: l10n.editCommand,
                onPressed: onEdit,
                touchSize: 32,
                icon: const Icon(AppIcons.editOutlined, size: 18),
              ),
              const SizedBox(width: 4),
              ToolIconButton(
                tooltip: l10n.deleteCommand,
                onPressed: onDelete,
                touchSize: 32,
                icon: const Icon(AppIcons.deleteOutline, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandStatusControl extends StatelessWidget {
  const _CommandStatusControl({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: AppTheme.textStylesOf(context).labelSmall.copyWith(
              color: AppTheme.colorsOf(context).mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 4),
        ToolTooltip(message: label, child: child),
      ],
    );
  }
}
