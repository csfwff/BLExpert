import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

/// Text input boundary used while migrating form controls to shadcn_flutter.
///
/// Labels and errors remain owned by the app so validation and accessibility
/// semantics do not depend on a third-party decoration API.
class ToolTextField extends StatelessWidget {
  static const EdgeInsetsGeometry defaultPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 4,
  );
  static const EdgeInsetsGeometry iconPadding = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 4,
  );
  static const shad.Density iconDensity = shad.Density(
    baseContainerPadding: 8,
    baseGap: 2,
    baseContentPadding: 8,
  );

  const ToolTextField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.errorText,
    this.helperText,
    this.hintText,
    this.showLabel = true,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.style,
    this.placeholderStyle,
    this.inputFormatters,
    this.enabled = true,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.padding,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final bool showLabel;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final EdgeInsetsGeometry? padding;

  Widget _buildField(BuildContext context, FormFieldState<String>? field) {
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final shad.ThemeData appTheme = AppTheme.of(context);
    final bool hasInputIcon = prefix != null || suffix != null;
    final shad.ThemeData compactFieldTheme = appTheme.copyWith(
      density: () => hasInputIcon ? iconDensity : shad.Density.compactDensity,
    );
    final TextStyle inputTextStyle = appTheme.typography.xSmall.merge(style);
    final TextStyle effectivePlaceholderStyle = inputTextStyle
        .copyWith(color: colors.mutedForeground)
        .merge(placeholderStyle);
    final TextStyle labelTextStyle = appTheme.typography.xSmall.copyWith(
      color: colors.foreground,
      fontWeight: FontWeight.w500,
    );
    final String? effectiveError = errorText ?? field?.errorText;
    final Widget input = shad.Theme(
      data: compactFieldTheme,
      child: shad.TextField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        focusNode: focusNode,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textAlign: textAlign,
        style: inputTextStyle,
        padding: padding ?? (hasInputIcon ? iconPadding : defaultPadding),
        inputFormatters: inputFormatters,
        enabled: enabled,
        placeholder: hintText == null && showLabel
            ? null
            : Text(hintText ?? label, style: effectivePlaceholderStyle),
        features: <shad.InputFeature>[
          if (prefix != null)
            shad.InputFeature.leading(
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 24),
                child: Center(child: prefix),
              ),
            ),
          if (suffix != null) shad.InputFeature.trailing(suffix!),
        ],
        onChanged: (String value) {
          field?.didChange(value);
          onChanged?.call(value);
        },
        onSubmitted: onSubmitted,
      ),
    );
    if (!showLabel && helperText == null && effectiveError == null) {
      return Semantics(textField: true, label: label, child: input);
    }
    return Semantics(
      textField: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showLabel) ...<Widget>[
            Text(label, style: labelTextStyle),
            const SizedBox(height: 2),
          ],
          input,
          if (helperText != null && effectiveError == null) ...<Widget>[
            const SizedBox(height: 2),
            Text(helperText!, style: AppTheme.textStylesOf(context).bodySmall),
          ],
          if (effectiveError != null) ...<Widget>[
            const SizedBox(height: 2),
            Semantics(
              liveRegion: true,
              label: effectiveError,
              child: Text(
                effectiveError,
                style: AppTheme.textStylesOf(
                  context,
                ).bodySmall.copyWith(color: colors.destructive),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (validator == null) return _buildField(context, null);
    return FormField<String>(
      initialValue: controller?.text ?? initialValue ?? '',
      validator: validator,
      builder: (FormFieldState<String> field) => _buildField(context, field),
    );
  }
}
