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
  static const double _titleIconSize = 19;
  static const double _titleGap = 8;

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
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final Widget titleIcon = ExcludeSemantics(
      child: Transform.translate(
        offset: const Offset(0, 1),
        child: Icon(
          icon,
          key: const ValueKey<String>('tool-alert-dialog-icon'),
          size: _titleIconSize,
          color: colors.secondaryForeground,
        ),
      ),
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
        title: Row(
          key: const ValueKey<String>('tool-alert-dialog-title-row'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            titleIcon,
            const SizedBox(width: _titleGap),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        content: Padding(
          key: const ValueKey<String>('tool-alert-dialog-content'),
          padding: const EdgeInsets.only(left: _titleIconSize + _titleGap),
          child: content,
        ),
        actions: actions,
      ),
    );
  }
}
