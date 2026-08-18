import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

enum ToolButtonVariant { primary, secondary, outline, ghost, destructive }

/// Project-owned button boundary for compact tool surfaces.
///
/// shadcn aligns content to the start when a leading icon is present. Tool
/// actions are centered explicitly so icon/label combinations keep a stable
/// visual center across normal and loading states.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = ToolButtonVariant.primary,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
  });

  const ToolButton.primary({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
  }) : variant = ToolButtonVariant.primary;

  const ToolButton.secondary({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
  }) : variant = ToolButtonVariant.secondary;

  const ToolButton.outline({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
  }) : variant = ToolButtonVariant.outline;

  const ToolButton.ghost({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
  }) : variant = ToolButtonVariant.ghost;

  const ToolButton.destructive({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
  }) : variant = ToolButtonVariant.destructive;

  final Widget child;
  final VoidCallback? onPressed;
  final ToolButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool compact;
  final AlignmentGeometry alignment;

  shad.ButtonStyle get _style => switch (variant) {
    ToolButtonVariant.primary => shad.ButtonStyle.primary(
      size: compact ? shad.ButtonSize.small : shad.ButtonSize.normal,
      density: shad.ButtonDensity.dense,
    ),
    ToolButtonVariant.secondary => shad.ButtonStyle.secondary(
      size: compact ? shad.ButtonSize.small : shad.ButtonSize.normal,
      density: shad.ButtonDensity.dense,
    ),
    ToolButtonVariant.outline => shad.ButtonStyle.outline(
      size: compact ? shad.ButtonSize.small : shad.ButtonSize.normal,
      density: shad.ButtonDensity.dense,
    ),
    ToolButtonVariant.ghost => shad.ButtonStyle.ghost(
      size: compact ? shad.ButtonSize.small : shad.ButtonSize.normal,
      density: shad.ButtonDensity.dense,
    ),
    ToolButtonVariant.destructive => shad.ButtonStyle.destructive(
      size: compact ? shad.ButtonSize.small : shad.ButtonSize.normal,
      density: shad.ButtonDensity.dense,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 36 : 40,
      child: shad.Button(
        style: _style,
        alignment: alignment,
        leading: leading,
        trailing: trailing,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

class ToolIconButton extends StatelessWidget {
  const ToolIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = ToolButtonVariant.ghost,
    this.compact = true,
    this.touchSize,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final ToolButtonVariant variant;
  final bool compact;
  final double? touchSize;

  shad.AbstractButtonStyle get _variance => switch (variant) {
    ToolButtonVariant.primary => shad.ButtonVariance.primary,
    ToolButtonVariant.secondary => shad.ButtonVariance.secondary,
    ToolButtonVariant.outline => shad.ButtonVariance.outline,
    ToolButtonVariant.ghost => shad.ButtonVariance.ghost,
    ToolButtonVariant.destructive => shad.ButtonVariance.destructive,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: touchSize ?? (compact ? 36 : 40),
      child: Tooltip(
        message: tooltip,
        child: shad.IconButton(
          icon: icon,
          variance: _variance,
          size: compact ? shad.ButtonSize.small : shad.ButtonSize.normal,
          density: shad.ButtonDensity.iconDense,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class ToolLoadingIcon extends StatelessWidget {
  const ToolLoadingIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Center(
        child: shad.CircularProgressIndicator(
          size: size,
          strokeWidth: 2,
          onSurface: true,
        ),
      ),
    );
  }
}

class ToolSegmentOption<T> {
  const ToolSegmentOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final Widget? icon;
}

class ToolSegmentedControl<T> extends StatelessWidget {
  const ToolSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<ToolSegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map(
              (ToolSegmentOption<T> option) => Padding(
                padding: EdgeInsets.only(right: option == options.last ? 0 : 4),
                child: shad.SelectedButton(
                  value: value == option.value,
                  style: const shad.ButtonStyle.outline(
                    size: shad.ButtonSize.small,
                    density: shad.ButtonDensity.dense,
                  ),
                  selectedStyle: const shad.ButtonStyle.secondary(
                    size: shad.ButtonSize.small,
                    density: shad.ButtonDensity.dense,
                  ),
                  onChanged: (_) => onChanged(option.value),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (option.icon != null) ...<Widget>[
                        IconTheme(
                          data: const IconThemeData(size: 16),
                          child: option.icon!,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(option.label),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
