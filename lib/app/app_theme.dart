import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

abstract final class AppFonts {
  static const String sans = 'NotoSansSC';
  static const String mono = 'GeistMono';
  static const String shadcnPackage = 'shadcn_flutter';

  static const TextStyle sansStyle = TextStyle(fontFamily: sans);
  static const TextStyle monoStyle = TextStyle(
    fontFamily: mono,
    package: shadcnPackage,
  );
}

TextStyle _sansTextStyle(TextStyle style) => AppFonts.sansStyle.merge(style);

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration overlay = Duration(milliseconds: 240);

  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

class AppTextStyles {
  const AppTextStyles(this._typography, this._foreground, this._muted);

  final shad.Typography _typography;
  final Color _foreground;
  final Color _muted;

  TextStyle get labelSmall => _typography.xSmall.copyWith(color: _muted);
  TextStyle get labelMedium => _typography.small.copyWith(
    color: _foreground,
    fontWeight: FontWeight.w500,
  );
  TextStyle get labelLarge => _typography.small.copyWith(
    color: _foreground,
    fontWeight: FontWeight.w600,
  );
  TextStyle get bodySmall => _typography.xSmall.copyWith(color: _muted);
  TextStyle get titleSmall => _typography.small.copyWith(
    color: _foreground,
    fontWeight: FontWeight.w700,
  );
  TextStyle get titleMedium => _typography.base.copyWith(
    color: _foreground,
    fontWeight: FontWeight.w700,
  );
  TextStyle get titleLarge => _typography.xLarge.copyWith(
    color: _foreground,
    fontWeight: FontWeight.w700,
  );
}

abstract final class AppTheme {
  static shad.ThemeData of(BuildContext context) => shad.Theme.of(context);

  static shad.ColorScheme colorsOf(BuildContext context) =>
      of(context).colorScheme;

  static AppTextStyles textStylesOf(BuildContext context) {
    final shad.ThemeData theme = of(context);
    return AppTextStyles(
      theme.typography,
      theme.colorScheme.foreground,
      theme.colorScheme.mutedForeground,
    );
  }
}

shad.ThemeData buildAppTheme(
  Brightness brightness, {
  TargetPlatform? platform,
}) {
  const shad.Typography baseTypography = shad.Typography.geist();
  final shad.Typography typography = baseTypography.copyWith(
    sans: () => AppFonts.sansStyle,
    mono: () => AppFonts.monoStyle,
    xSmall: () => _sansTextStyle(baseTypography.xSmall),
    small: () => _sansTextStyle(baseTypography.small),
    base: () => _sansTextStyle(baseTypography.base),
    large: () => _sansTextStyle(baseTypography.large),
    xLarge: () => _sansTextStyle(baseTypography.xLarge),
    x2Large: () => _sansTextStyle(baseTypography.x2Large),
    x3Large: () => _sansTextStyle(baseTypography.x3Large),
    x4Large: () => _sansTextStyle(baseTypography.x4Large),
    x5Large: () => _sansTextStyle(baseTypography.x5Large),
    x6Large: () => _sansTextStyle(baseTypography.x6Large),
    x7Large: () => _sansTextStyle(baseTypography.x7Large),
    x8Large: () => _sansTextStyle(baseTypography.x8Large),
    x9Large: () => _sansTextStyle(baseTypography.x9Large),
    thin: () => _sansTextStyle(baseTypography.thin),
    light: () => _sansTextStyle(baseTypography.light),
    extraLight: () => _sansTextStyle(baseTypography.extraLight),
    normal: () => _sansTextStyle(baseTypography.normal),
    medium: () => _sansTextStyle(baseTypography.medium),
    semiBold: () => _sansTextStyle(baseTypography.semiBold),
    bold: () => _sansTextStyle(baseTypography.bold),
    extraBold: () => _sansTextStyle(baseTypography.extraBold),
    black: () => _sansTextStyle(baseTypography.black),
    italic: () => _sansTextStyle(baseTypography.italic),
    h1: () => _sansTextStyle(baseTypography.h1),
    h2: () => _sansTextStyle(baseTypography.h2),
    h3: () => _sansTextStyle(baseTypography.h3),
    h4: () => _sansTextStyle(baseTypography.h4),
    p: () => _sansTextStyle(baseTypography.p),
    blockQuote: () => _sansTextStyle(baseTypography.blockQuote),
    inlineCode: () => baseTypography.inlineCode.merge(AppFonts.monoStyle),
    lead: () => _sansTextStyle(baseTypography.lead),
    textLarge: () => _sansTextStyle(baseTypography.textLarge),
    textSmall: () => _sansTextStyle(baseTypography.textSmall),
    textMuted: () => _sansTextStyle(baseTypography.textMuted),
  );
  final bool dark = brightness == Brightness.dark;
  final shad.ColorScheme scheme = shad.ColorScheme(
    brightness: brightness,
    background: dark ? const Color(0xFF0A111B) : const Color(0xFFF7F9FC),
    foreground: dark ? const Color(0xFFE7EDF5) : const Color(0xFF172033),
    card: dark ? const Color(0xFF101824) : const Color(0xFFFCFDFF),
    cardForeground: dark ? const Color(0xFFE7EDF5) : const Color(0xFF172033),
    popover: dark ? const Color(0xFF101B29) : const Color(0xFFFFFFFF),
    popoverForeground: dark ? const Color(0xFFE7EDF5) : const Color(0xFF172033),
    primary: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    primaryForeground: dark ? const Color(0xFF07111F) : const Color(0xFFFFFFFF),
    secondary: dark ? const Color(0xFF173A5E) : const Color(0xFFDBEAFE),
    secondaryForeground: dark
        ? const Color(0xFFDBEAFE)
        : const Color(0xFF1D4ED8),
    muted: dark ? const Color(0xFF152131) : const Color(0xFFEEF3F8),
    mutedForeground: dark ? const Color(0xFFAAB8C8) : const Color(0xFF526174),
    accent: dark ? const Color(0xFF12344D) : const Color(0xFFE0F2FE),
    accentForeground: dark ? const Color(0xFFBAE6FD) : const Color(0xFF075985),
    destructive: dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
    destructiveForeground: dark
        ? const Color(0xFF1B0A0A)
        : const Color(0xFFFFFFFF),
    border: dark ? const Color(0xFF40536A) : const Color(0xFFC9D4E0),
    input: dark ? const Color(0xFF40536A) : const Color(0xFFB8C5D4),
    ring: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    chart1: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    chart2: dark ? const Color(0xFF34D399) : const Color(0xFF047857),
    chart3: dark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
    chart4: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
    chart5: dark ? const Color(0xFFF472B6) : const Color(0xFFBE185D),
  );
  return shad.ThemeData(
    colorScheme: scheme,
    typography: typography,
    radius: 0.5,
    platform: platform,
    surfaceOpacity: 1,
  );
}
