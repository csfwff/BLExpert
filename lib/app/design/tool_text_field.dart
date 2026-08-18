import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

/// Text input boundary used while migrating form controls to shadcn_flutter.
///
/// Labels and errors remain owned by the app so validation and accessibility
/// semantics do not depend on a third-party decoration API.
class ToolTextField extends StatelessWidget {
  const ToolTextField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      textField: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          shad.TextField(
            controller: controller,
            autofocus: autofocus,
            minLines: minLines,
            maxLines: maxLines,
            placeholder: Text(label),
          ),
          if (errorText != null) ...<Widget>[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              label: errorText,
              child: Text(
                errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
