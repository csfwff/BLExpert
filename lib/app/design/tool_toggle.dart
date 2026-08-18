import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

class ToolSwitch extends StatelessWidget {
  const ToolSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      child: shad.Switch(
        value: value,
        enabled: enabled && onChanged != null,
        onChanged: onChanged,
      ),
    );
  }
}

class ToolSwitchTile extends StatelessWidget {
  const ToolSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                title,
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodySmall,
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ToolSwitch(value: value, enabled: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class ToolCheckbox extends StatelessWidget {
  const ToolCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      checked: value,
      child: shad.Checkbox(
        state: value
            ? shad.CheckboxState.checked
            : shad.CheckboxState.unchecked,
        enabled: enabled && onChanged != null,
        onChanged: onChanged == null
            ? null
            : (shad.CheckboxState state) =>
                  onChanged!(state == shad.CheckboxState.checked),
      ),
    );
  }
}

class ToolCheckboxTile extends StatelessWidget {
  const ToolCheckboxTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ToolCheckbox(value: value, onChanged: onChanged, enabled: enabled),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                title,
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodySmall,
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
