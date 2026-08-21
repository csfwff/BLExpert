import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';
import 'tool_tooltip.dart';

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
    this.height,
    this.padding,
    this.preservePrimaryColorWhenDisabled = false,
  });

  const ToolButton.primary({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
    this.height,
    this.padding,
    this.preservePrimaryColorWhenDisabled = false,
  }) : variant = ToolButtonVariant.primary;

  const ToolButton.secondary({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
    this.height,
    this.padding,
    this.preservePrimaryColorWhenDisabled = false,
  }) : variant = ToolButtonVariant.secondary;

  const ToolButton.outline({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
    this.height,
    this.padding,
    this.preservePrimaryColorWhenDisabled = false,
  }) : variant = ToolButtonVariant.outline;

  const ToolButton.ghost({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
    this.height,
    this.padding,
    this.preservePrimaryColorWhenDisabled = false,
  }) : variant = ToolButtonVariant.ghost;

  const ToolButton.destructive({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.compact = false,
    this.alignment = Alignment.center,
    this.height,
    this.padding,
    this.preservePrimaryColorWhenDisabled = false,
  }) : variant = ToolButtonVariant.destructive;

  final Widget child;
  final VoidCallback? onPressed;
  final ToolButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool compact;
  final AlignmentGeometry alignment;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool preservePrimaryColorWhenDisabled;

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
    shad.AbstractButtonStyle style = padding == null
        ? _style
        : _style.withPadding(padding: padding);
    if (preservePrimaryColorWhenDisabled &&
        variant == ToolButtonVariant.primary) {
      final shad.ColorScheme colors = AppTheme.colorsOf(context);
      style = style
          .withBackgroundColor(
            disabledColor: colors.primary.withValues(alpha: 0.42),
          )
          .withForegroundColor(
            disabledColor: colors.primaryForeground.withValues(alpha: 0.78),
          );
    }
    return SizedBox(
      height: height ?? (compact ? 36 : 40),
      child: shad.Button(
        style: style,
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
      child: ToolTooltip(
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

enum ToolSelectedEmphasis { strong, subtle }

/// Project selected-state boundary with persistent high-contrast styling.
///
/// shadcn's Clickable keeps focus, pointer and keyboard behavior while the
/// project owns the 200ms persistent-state transition and semantic contrast.
class ToolSelectedButton extends StatefulWidget {
  const ToolSelectedButton({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
    this.emphasis = ToolSelectedEmphasis.subtle,
    this.compact = true,
    this.enabled = true,
    this.onPressed,
    this.minHeight,
    this.padding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget child;
  final ToolSelectedEmphasis emphasis;
  final bool compact;
  final bool enabled;
  final VoidCallback? onPressed;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;

  @override
  State<ToolSelectedButton> createState() => _ToolSelectedButtonState();
}

class _ToolSelectedButtonState extends State<ToolSelectedButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.enabled && widget.onChanged != null;

  Color _stateOverlay(Color base, shad.ColorScheme colors) {
    if (!_enabled) return base.withValues(alpha: 0.48);
    if (_pressed) {
      return Color.alphaBlend(colors.foreground.withValues(alpha: 0.12), base);
    }
    if (_hovered) {
      return Color.alphaBlend(colors.primary.withValues(alpha: 0.10), base);
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final shad.ThemeData theme = AppTheme.of(context);
    final shad.ColorScheme colors = theme.colorScheme;
    final bool strong = widget.emphasis == ToolSelectedEmphasis.strong;
    final Color baseColor = widget.value
        ? (strong ? colors.primary : colors.secondary)
        : colors.card;
    final Color foreground = widget.value
        ? (strong ? colors.primaryForeground : colors.secondaryForeground)
        : colors.foreground;
    final Color borderColor = widget.value ? colors.primary : colors.border;
    final Duration duration = AppMotion.resolve(context, AppMotion.standard);
    final EdgeInsetsGeometry padding =
        widget.padding ??
        EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : 14,
          vertical: widget.compact ? 7 : 9,
        );
    return Semantics(
      button: true,
      selected: widget.value,
      enabled: _enabled,
      child: shad.Clickable(
        enabled: _enabled,
        onHover: (bool hovered) => setState(() => _hovered = hovered),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onPressed: _enabled
            ? () {
                widget.onPressed?.call();
                widget.onChanged?.call(!widget.value);
              }
            : null,
        enableFeedback: false,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minHeight: widget.minHeight ?? (widget.compact ? 36 : 40),
          ),
          padding: padding,
          decoration: BoxDecoration(
            color: _stateOverlay(baseColor, colors),
            border: Border.all(color: borderColor),
            borderRadius: theme.borderRadiusSm,
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: Curves.easeOutCubic,
            // Preserve the application sans font when this widget becomes
            // the nearest DefaultTextStyle for its label.
            style: theme.typography.sans
                .merge(theme.typography.small)
                .copyWith(
                  color: foreground,
                  fontWeight: widget.value ? FontWeight.w700 : FontWeight.w500,
                ),
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 16),
              child: widget.child,
            ),
          ),
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
    this.textStyle,
    this.padding,
    this.height = 36,
  });

  final T value;
  final List<ToolSegmentOption<T>> options;
  final ValueChanged<T> onChanged;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map(
              (ToolSegmentOption<T> option) => Padding(
                padding: EdgeInsets.only(right: option == options.last ? 0 : 4),
                child: ToolSelectedButton(
                  value: value == option.value,
                  onChanged: (_) => onChanged(option.value),
                  padding: padding,
                  minHeight: height,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (option.icon != null) ...<Widget>[
                        option.icon!,
                        const SizedBox(width: 5),
                      ],
                      Text(
                        option.label,
                        style: textStyle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
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
