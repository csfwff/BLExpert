import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

class ToolTooltip extends StatelessWidget {
  const ToolTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      tooltip: message,
      child: shad.Tooltip(
        waitDuration: const Duration(milliseconds: 500),
        showDuration: AppMotion.resolve(context, AppMotion.overlay),
        tooltip: (BuildContext context) => Text(message),
        child: child,
      ),
    );
  }
}
