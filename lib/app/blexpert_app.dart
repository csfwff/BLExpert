import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../features/home/home_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/bluetooth_service.dart';
import 'app_theme.dart';

class _ShadcnChineseFallbackDelegate
    extends LocalizationsDelegate<shad.ShadcnLocalizations> {
  const _ShadcnChineseFallbackDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';

  @override
  Future<shad.ShadcnLocalizations> load(Locale locale) {
    return shad.ShadcnLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(_ShadcnChineseFallbackDelegate old) => false;
}

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
  shad.ThemeMode _themeMode = shad.ThemeMode.system;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
  }

  @override
  Widget build(BuildContext context) {
    return shad.ShadcnApp(
      debugShowCheckedModeBanner: false,
      title: 'BLExpert',
      locale: _locale,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        const _ShadcnChineseFallbackDelegate(),
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: _themeMode,
      theme: buildAppTheme(Brightness.light, platform: widget.shadcnPlatform),
      darkTheme: buildAppTheme(
        Brightness.dark,
        platform: widget.shadcnPlatform,
      ),
      home: shad.ToastLayer(
        child: HomeScreen(
          themeMode: _themeMode,
          locale: _locale,
          onThemeModeChanged: (shad.ThemeMode value) =>
              setState(() => _themeMode = value),
          onLocaleChanged: (Locale? value) => setState(() => _locale = value),
          bluetoothService: widget.bluetoothService,
        ),
      ),
    );
  }
}
