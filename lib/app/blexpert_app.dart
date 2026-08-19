import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../features/home/home_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/bluetooth_service.dart';
import 'app_theme.dart';

class BlexpertApp extends StatefulWidget {
  const BlexpertApp({
    super.key,
    this.locale,
    this.bluetoothService,
    this.shadcnPlatform,
  });

  final Locale? locale;
  final BluetoothService? bluetoothService;
  final TargetPlatform? shadcnPlatform;

  @override
  State<BlexpertApp> createState() => _BlexpertAppState();
}

class _BlexpertAppState extends State<BlexpertApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLExpert',
      builder: (BuildContext context, Widget? child) {
        return shad.ShadcnLayer(
          theme: shad.ThemeData(platform: widget.shadcnPlatform),
          darkTheme: shad.ThemeData.dark(platform: widget.shadcnPlatform),
          themeMode: switch (_themeMode) {
            ThemeMode.light => shad.ThemeMode.light,
            ThemeMode.dark => shad.ThemeMode.dark,
            ThemeMode.system => shad.ThemeMode.system,
          },
          child: shad.DrawerOverlay(child: child!),
        );
      },
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: _themeMode,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: HomeScreen(
        themeMode: _themeMode,
        locale: _locale,
        onThemeModeChanged: (ThemeMode value) =>
            setState(() => _themeMode = value),
        onLocaleChanged: (Locale? value) => setState(() => _locale = value),
        bluetoothService: widget.bluetoothService,
      ),
    );
  }
}
