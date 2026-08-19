part of '../home/home_screen.dart';

class _WorkspaceOverview extends StatefulWidget {
  const _WorkspaceOverview({
    required this.workspace,
    required this.onChanged,
    required this.l10n,
  });

  final Workspace workspace;
  final ValueChanged<Workspace> onChanged;
  final AppLocalizations l10n;

  @override
  State<_WorkspaceOverview> createState() => _WorkspaceOverviewState();
}

class _WorkspaceOverviewState extends State<_WorkspaceOverview> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _deviceModelController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _deviceModelController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _WorkspaceOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id ||
        oldWidget.workspace.updatedAt != widget.workspace.updatedAt) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deviceModelController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _nameController.text = widget.workspace.name;
    _deviceModelController.text = widget.workspace.deviceModel;
    _descriptionController.text = widget.workspace.description;
    _tagsController.text = widget.workspace.tags.join(', ');
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final Workspace updated = widget.workspace.copyWith(
      name: _nameController.text.trim(),
      deviceModel: _deviceModelController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: _tagsController.text
          .split(',')
          .map((String tag) => tag.trim())
          .where((String tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
    widget.onChanged(updated);
    showToolToast(context, widget.l10n.workspaceSaved);
  }

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(AppIcons.folderOutlined, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.l10n.workspaceSettings,
                        style: AppTheme.textStylesOf(
                          context,
                        ).titleLarge.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ToolTextField(
                  key: const ValueKey<String>('workspace-name-field'),
                  controller: _nameController,
                  label: widget.l10n.workspace,
                  textInputAction: TextInputAction.next,
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return widget.l10n.requiredField(widget.l10n.workspace);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                ToolTextField(
                  key: const ValueKey<String>('workspace-device-model-field'),
                  controller: _deviceModelController,
                  label: widget.l10n.deviceModel,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                ToolTextField(
                  key: const ValueKey<String>('workspace-description-field'),
                  controller: _descriptionController,
                  label: widget.l10n.description,
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 14),
                ToolTextField(
                  key: const ValueKey<String>('workspace-tags-field'),
                  controller: _tagsController,
                  label: widget.l10n.tags,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Icon(
                      AppIcons.devicesOther,
                      size: 20,
                      color: colors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.l10n.workspaceDevices),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.workspace.devices.length}',
                      style: AppTheme.textStylesOf(
                        context,
                      ).labelLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ToolButton.primary(
                    onPressed: _save,
                    leading: const Icon(AppIcons.saveOutlined),
                    child: Text(widget.l10n.save),
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

class _WorkspaceField extends StatelessWidget {
  const _WorkspaceField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTheme.textStylesOf(context).labelMedium),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value),
        ],
      ),
    );
  }
}
