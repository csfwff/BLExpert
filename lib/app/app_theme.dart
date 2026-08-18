part of '../main.dart';

ThemeData _buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
        secondary: dark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
        tertiary: dark ? const Color(0xFF34D399) : const Color(0xFF047857),
        error: dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
        surface: dark ? const Color(0xFF101824) : const Color(0xFFFCFDFF),
        surfaceContainerLow: dark
            ? const Color(0xFF152131)
            : const Color(0xFFF3F6FA),
        surfaceContainerHighest: dark
            ? const Color(0xFF203147)
            : const Color(0xFFE8EEF5),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0A111B)
        : const Color(0xFFF7F9FC),
    textTheme: Typography.material2021().black.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: 'sans-serif',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF101824) : scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF101B29) : scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xFF2A3C52) : const Color(0xFFD9E2EC),
      space: 1,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      border: const UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xFF0D1622) : const Color(0xFFFAFCFE),
      indicatorColor: dark ? const Color(0xFF173A5E) : const Color(0xFFDCEBFF),
      selectedIconTheme: IconThemeData(color: scheme.primary),
      selectedLabelTextStyle: TextStyle(
        color: scheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      unselectedLabelTextStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: dark ? const Color(0xFF101824) : scheme.surface,
      indicatorColor: dark ? const Color(0xFF173A5E) : const Color(0xFFDCEBFF),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurface, fontSize: 12),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFFE7EDF5) : const Color(0xFF172033),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: TextStyle(
        color: dark ? const Color(0xFF172033) : Colors.white,
      ),
    ),
  );
}
