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
    this.showLabel = true,
    this.errorText,
    this.textStyle,
    this.padding,
    this.itemPadding,
    this.itemHeight,
  });

  final T value;
  final List<ToolSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? label;
  final bool showLabel;
  final String? errorText;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? itemPadding;
  final double? itemHeight;

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
      padding: padding,
      itemBuilder: (BuildContext context, T item) => Text(
        _optionFor(item).label,
        style: textStyle,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
      popupConstraints: const BoxConstraints(maxHeight: 180),
      popoverAlignment: Alignment.bottomCenter,
      popoverAnchorAlignment: Alignment.topCenter,
      popup: shad.SelectPopup<T>(
        items: shad.SelectItemList(
          children: options
              .map(
                (ToolSelectOption<T> option) => itemPadding == null
                    ? shad.SelectItemButton<T>(
                        value: option.value,
                        child: Text(
                          option.label,
                          style: textStyle,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : _ToolSelectItem<T>(
                        value: option.value,
                        height: itemHeight,
                        padding: itemPadding!,
                        child: Text(
                          option.label,
                          style: textStyle,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
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
    if ((!showLabel || label == null) && errorText == null) return semantics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLabel && label != null) ...<Widget>[
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

class _ToolSelectItem<T> extends StatelessWidget {
  const _ToolSelectItem({
    required this.value,
    required this.padding,
    required this.child,
    this.height,
  });

  final T value;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final shad.SelectPopupHandle? data =
        shad.Data.maybeOf<shad.SelectPopupHandle>(context);
    final bool isSelected = data?.isSelected(value) ?? false;
    final bool hasSelection = data?.hasSelection ?? false;
    return SizedBox(
      key: ValueKey<String>('tool-select-option-$value'),
      height: height,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              data?.selectItem(value, !isSelected);
              return null;
            },
          ),
        },
        child: shad.SubFocus(
          builder: (BuildContext context, shad.SubFocusState state) =>
              shad.WidgetStatesProvider(
                states: <WidgetState>{if (state.isFocused) WidgetState.hovered},
                child: shad.Button(
                  disableTransition: true,
                  alignment: AlignmentDirectional.centerStart,
                  onPressed: () => data?.selectItem(value, !isSelected),
                  style: const shad.ButtonStyle.ghost().copyWith(
                    padding: (_, _, _) => padding,
                  ),
                  trailing: isSelected
                      ? const Icon(shad.LucideIcons.check, size: 14)
                      : hasSelection
                      ? const SizedBox(width: 14)
                      : null,
                  child: child,
                ),
              ),
        ),
      ),
    );
  }
}
