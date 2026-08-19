import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

/// Presents a tool dialog with the layout route expected by shadcn_flutter.
///
/// Keeping this route behind the design boundary prevents callers from
/// accidentally combining Material's full-screen dialog constraints with the
/// shadcn surface layout.
Future<T?> showToolDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return shad
      .showOverlay<T>(
        context,
        shad.DialogConfiguration<T>(
          builder: builder,
          barrierDismissible: barrierDismissible,
        ),
      )
      .future;
}

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
    this.centerTitleIcon = false,
  });

  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool centerTitleIcon;

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    Widget buildTitleIcon({double verticalOffset = 0}) => ExcludeSemantics(
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: Icon(
          icon,
          key: const ValueKey<String>('tool-alert-dialog-icon'),
          size: 19,
          color: colors.secondaryForeground,
        ),
      ),
    );
    final Widget titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    // Keep modal surfaces aligned with the app's compact 4-6px radius scale.
    // This override is scoped to the dialog so other shadcn components keep
    // their default theme behavior.
    final shad.ThemeData dialogTheme = shad.Theme.of(
      context,
    ).copyWith(radius: () => 0.25);
    return shad.Theme(
      data: dialogTheme,
      child: shad.AlertDialog(
        leading: centerTitleIcon ? null : buildTitleIcon(),
        title: centerTitleIcon
            ? Row(
                key: const ValueKey<String>('tool-alert-dialog-title-row'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  buildTitleIcon(verticalOffset: 1),
                  const SizedBox(width: 8),
                  titleText,
                ],
              )
            : titleText,
        content: content,
        actions: actions,
      ),
    );
  }
}
