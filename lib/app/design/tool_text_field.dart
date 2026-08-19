import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app_theme.dart';

/// Text input boundary used while migrating form controls to shadcn_flutter.
///
/// Labels and errors remain owned by the app so validation and accessibility
/// semantics do not depend on a third-party decoration API.
class ToolTextField extends StatelessWidget {
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
    final String? effectiveError = errorText ?? field?.errorText;
    final Widget input = shad.TextField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textAlign: textAlign,
      style: style,
      padding: padding,
      inputFormatters: inputFormatters,
      enabled: enabled,
      placeholder: hintText == null && showLabel
          ? null
          : Text(hintText ?? label),
      features: <shad.InputFeature>[
        if (prefix != null) shad.InputFeature.leading(prefix!),
        if (suffix != null) shad.InputFeature.trailing(suffix!),
      ],
      onChanged: (String value) {
        field?.didChange(value);
        onChanged?.call(value);
      },
      onSubmitted: onSubmitted,
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
            Text(label, style: AppTheme.textStylesOf(context).labelMedium),
            const SizedBox(height: 4),
          ],
          input,
          if (helperText != null && effectiveError == null) ...<Widget>[
            const SizedBox(height: 4),
            Text(helperText!, style: AppTheme.textStylesOf(context).bodySmall),
          ],
          if (effectiveError != null) ...<Widget>[
            const SizedBox(height: 4),
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
