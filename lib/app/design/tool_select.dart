import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

class ToolSelectOption<T> {
  const ToolSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Select boundary used for gradual shadcn_flutter form migration.
///
/// The app owns labels, option values and validation semantics while the
/// third-party component provides the popup, keyboard focus and selection UI.
class ToolSelect<T> extends StatelessWidget {
  const ToolSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
    this.errorText,
  });

  final T value;
  final List<ToolSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? label;
  final String? errorText;

  ToolSelectOption<T> _optionFor(T value) {
    return options.firstWhere(
      (ToolSelectOption<T> option) => option.value == value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final ToolSelectOption<T> selected = _optionFor(value);
    final Widget select = shad.Select<T>(
      value: value,
      onChanged: (T? next) {
        if (next != null) onChanged(next);
      },
      itemBuilder: (BuildContext context, T item) =>
          Text(_optionFor(item).label),
      popupConstraints: const BoxConstraints(maxHeight: 180),
      popoverAlignment: Alignment.bottomCenter,
      popoverAnchorAlignment: Alignment.topCenter,
      popup: shad.SelectPopup<T>(
        items: shad.SelectItemList(
          children: options
              .map(
                (ToolSelectOption<T> option) => shad.SelectItemButton<T>(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
              .toList(growable: false),
        ),
      ).call,
    );

    final Widget semantics = Semantics(
      button: true,
      label: label ?? selected.label,
      value: selected.label,
      child: select,
    );
    if (label == null && errorText == null) return semantics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(label!, style: AppTheme.textStylesOf(context).labelMedium),
          const SizedBox(height: 4),
        ],
        semantics,
        if (errorText != null) ...<Widget>[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            label: errorText,
            child: Text(
              errorText!,
              style: AppTheme.textStylesOf(
                context,
              ).bodySmall.copyWith(color: colors.destructive),
            ),
          ),
        ],
      ],
    );
  }
}
