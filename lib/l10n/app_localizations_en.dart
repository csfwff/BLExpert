// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BLExpert';

  @override
  String get startScan => 'Start scan';

  @override
  String get stopScan => 'Stop scan';

  @override
  String get exportWorkspacePreview => 'Export workspace preview';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'System default';

  @override
  String get lightMode => 'Light mode';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get workspace => 'Workspace';

  @override
  String deviceCount(int count) {
    return 'Devices: $count';
  }

  @override
  String get deviceScan => 'Device scan';

  @override
  String get connect => 'Connect';

  @override
  String get connected => 'Connected';

  @override
  String deviceDetails(String protocol, int rssi, String id) {
    return '$protocol / RSSI $rssi / $id';
  }

  @override
  String get debugConsole => 'Debug console';

  @override
  String get noData => 'No sent or received data yet.';

  @override
  String get received => 'RECEIVED';

  @override
  String get system => 'SYSTEM';

  @override
  String get workspaceSelector => 'Workspace';

  @override
  String get selectWorkspace => 'Select workspace';

  @override
  String get connection => 'Connection';

  @override
  String get connectDevice => 'Connect device';

  @override
  String get disconnectDevice => 'Disconnect device';

  @override
  String get noDevice => 'No device';

  @override
  String get console => 'Console';

  @override
  String get clear => 'Clear';

  @override
  String get autoScroll => 'Auto-scroll';

  @override
  String get sendData => 'Send data';

  @override
  String get inputPlaceholder => 'Enter data to send...';

  @override
  String get textMode => 'TEXT';

  @override
  String get hexMode => 'HEX';

  @override
  String get lineEnding => 'Line ending';

  @override
  String get none => 'None';

  @override
  String get lf => 'LF';

  @override
  String get crlf => 'CRLF';

  @override
  String get checksum => 'Checksum';

  @override
  String get autoSend => 'Auto-send';

  @override
  String get quickCommands => 'Quick commands';

  @override
  String get newCommand => 'New command';

  @override
  String get commandName => 'Command name';

  @override
  String get commandPayload => 'Payload';

  @override
  String get sendCommand => 'Send';

  @override
  String connectedDevice(String name) {
    return 'Connected: $name';
  }

  @override
  String deviceCountShort(int count) {
    return '$count devices';
  }
}
