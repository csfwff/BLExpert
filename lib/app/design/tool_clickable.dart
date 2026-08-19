import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

class ToolClickableRow extends StatelessWidget {
  const ToolClickableRow({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  });

  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shad.ThemeData theme = AppTheme.of(context);
    return shad.Clickable(
      enabled: onPressed != null,
      onPressed: onPressed,
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      decoration: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final Color color = states.contains(WidgetState.pressed)
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : states.contains(WidgetState.hovered)
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : const Color(0x00000000);
        return BoxDecoration(color: color, borderRadius: theme.borderRadiusSm);
      }),
      child: child,
    );
  }
}
