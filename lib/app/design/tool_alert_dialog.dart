import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

/// Stable dialog contract for design-system migrations.
///
/// Material actions stay supported while the dialog surface uses the selected
/// component library. This keeps existing command and safety flows decoupled
/// from the third-party API.
class ToolAlertDialog extends StatelessWidget {
  const ToolAlertDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return shad.Theme(
      data: dark ? const shad.ThemeData.dark() : const shad.ThemeData(),
      child: Material(
        type: MaterialType.transparency,
        child: shad.AlertDialog(
          leading: ExcludeSemantics(
            child: Icon(icon, size: 19, color: colors.secondary),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          content: Material(type: MaterialType.transparency, child: content),
          actions: actions
              .map(
                (Widget action) =>
                    Material(type: MaterialType.transparency, child: action),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
