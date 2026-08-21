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
      padding: const EdgeInsets.all(16),
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
                    Icon(
                      AppIcons.folderOutlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.l10n.workspaceSettings,
                        style: AppTheme.textStylesOf(context).titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = constraints.maxWidth < 560;
                    return Column(
                      children: <Widget>[
                        _ConfigurationFormRow(
                          key: const ValueKey<String>('workspace-name-row'),
                          label: widget.l10n.workspace,
                          stacked: stacked,
                          child: ToolTextField(
                            key: const ValueKey<String>('workspace-name-field'),
                            controller: _nameController,
                            label: widget.l10n.workspace,
                            showLabel: false,
                            hintText: '',
                            textInputAction: TextInputAction.next,
                            validator: (String? value) {
                              if (value == null || value.trim().isEmpty) {
                                return widget.l10n.requiredField(
                                  widget.l10n.workspace,
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                        _ConfigurationFormRow(
                          key: const ValueKey<String>(
                            'workspace-device-model-row',
                          ),
                          label: widget.l10n.deviceModel,
                          stacked: stacked,
                          child: ToolTextField(
                            key: const ValueKey<String>(
                              'workspace-device-model-field',
                            ),
                            controller: _deviceModelController,
                            label: widget.l10n.deviceModel,
                            showLabel: false,
                            hintText: '',
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        _ConfigurationFormRow(
                          key: const ValueKey<String>(
                            'workspace-description-row',
                          ),
                          label: widget.l10n.description,
                          stacked: stacked,
                          alignLabelToTop: true,
                          child: ToolTextField(
                            key: const ValueKey<String>(
                              'workspace-description-field',
                            ),
                            controller: _descriptionController,
                            label: widget.l10n.description,
                            showLabel: false,
                            hintText: '',
                            minLines: 3,
                            maxLines: 5,
                          ),
                        ),
                        _ConfigurationFormRow(
                          key: const ValueKey<String>('workspace-tags-row'),
                          label: widget.l10n.tags,
                          stacked: stacked,
                          child: ToolTextField(
                            key: const ValueKey<String>('workspace-tags-field'),
                            controller: _tagsController,
                            label: widget.l10n.tags,
                            showLabel: false,
                            hintText: '',
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ToolButton.primary(
                    key: const ValueKey<String>('workspace-save-button'),
                    onPressed: _save,
                    leading: const Icon(AppIcons.saveOutlined),
                    compact: true,
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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

class _ConfigurationFormRow extends StatelessWidget {
  const _ConfigurationFormRow({
    super.key,
    required this.label,
    required this.child,
    required this.stacked,
    this.alignLabelToTop = false,
    this.labelWidth = 96,
  });

  final String label;
  final Widget child;
  final bool stacked;
  final bool alignLabelToTop;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = AppTheme.textStylesOf(context).labelMedium;
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(label, style: labelStyle),
            ),
            child,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: alignLabelToTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: EdgeInsets.only(top: alignLabelToTop ? 8 : 0),
              child: Text(label, style: labelStyle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
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
