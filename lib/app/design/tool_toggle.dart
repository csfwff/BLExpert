import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

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
    final shad.ThemeData theme = AppTheme.of(context);
    final shad.ColorScheme colors = theme.colorScheme;
    final bool interactive = enabled && onChanged != null;
    final Duration duration = AppMotion.resolve(context, AppMotion.standard);
    final Color trackColor = value ? colors.primary : colors.input;
    final Color thumbColor = value ? colors.primaryForeground : colors.card;
    return Semantics(
      label: label,
      toggled: value,
      enabled: interactive,
      child: shad.Clickable(
        enabled: interactive,
        enableFeedback: false,
        onPressed: interactive ? () => onChanged!(!value) : null,
        child: AnimatedOpacity(
          duration: duration,
          opacity: interactive ? 1 : 0.48,
          child: AnimatedContainer(
            key: const ValueKey<String>('tool-switch-track'),
            duration: duration,
            curve: Curves.easeOutCubic,
            width: 38,
            height: 22,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: trackColor,
              border: Border.all(color: value ? colors.primary : colors.border),
              borderRadius: BorderRadius.circular(11),
            ),
            child: AnimatedAlign(
              duration: duration,
              curve: Curves.easeOutCubic,
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: AnimatedContainer(
                key: const ValueKey<String>('tool-switch-thumb-position'),
                duration: duration,
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: thumbColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.foreground.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ),
        ),
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
                    style: AppTheme.textStylesOf(context).bodySmall,
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
                    style: AppTheme.textStylesOf(context).bodySmall,
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
