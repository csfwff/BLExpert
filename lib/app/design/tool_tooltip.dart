import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

class ToolTooltip extends StatelessWidget {
  const ToolTooltip({
    super.key,
    required this.message,
    required this.child,
    this.showVisual = true,
  });

  final String message;
  final Widget child;
  final bool showVisual;

  @override
  Widget build(BuildContext context) {
    final Widget semantics = Semantics(tooltip: message, child: child);
    if (!showVisual) return semantics;

    return Semantics(
      tooltip: message,
      child: shad.Tooltip(
        waitDuration: const Duration(milliseconds: 500),
        showDuration: AppMotion.resolve(context, AppMotion.overlay),
        tooltip: (BuildContext context) {
          final shad.ThemeData theme = AppTheme.of(context);
          final shad.ColorScheme colors = theme.colorScheme;
          return Container(
            key: const ValueKey<String>('tool-tooltip-surface'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: colors.popover,
              border: Border.all(color: colors.border),
              borderRadius: theme.borderRadiusSm,
            ),
            child: Text(
              message,
              style: theme.typography.xSmall.copyWith(
                color: colors.popoverForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}
