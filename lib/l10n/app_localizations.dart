import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BLExpert'**
  String get appTitle;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start scan'**
  String get startScan;

  /// No description provided for @stopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop scan'**
  String get stopScan;

  /// No description provided for @exportWorkspacePreview.
  ///
  /// In en, this message translates to:
  /// **'Export workspace preview'**
  String get exportWorkspacePreview;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get followSystem;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @deviceCount.
  ///
  /// In en, this message translates to:
  /// **'Devices: {count}'**
  String deviceCount(int count);

  /// No description provided for @deviceScan.
  ///
  /// In en, this message translates to:
  /// **'Device scan'**
  String get deviceScan;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @deviceDetails.
  ///
  /// In en, this message translates to:
  /// **'{protocol} / RSSI {rssi} / {id}'**
  String deviceDetails(String protocol, int rssi, String id);

  /// No description provided for @debugConsole.
  ///
  /// In en, this message translates to:
  /// **'Debug console'**
  String get debugConsole;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No sent or received data yet.'**
  String get noData;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'RECEIVED'**
  String get received;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get system;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get error;

  /// No description provided for @deviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The BLE device is no longer available. Scan again and reconnect.'**
  String get deviceUnavailable;

  /// No description provided for @bluetoothOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth operation failed: {error}'**
  String bluetoothOperationFailed(String error);

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @connectingDevice.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}...'**
  String connectingDevice(String name);

  /// No description provided for @disconnectingDevice.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting from {name}...'**
  String disconnectingDevice(String name);

  /// No description provided for @connectedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}.'**
  String connectedToDevice(String name);

  /// No description provided for @workspaceSelector.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceSelector;

  /// No description provided for @selectWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Select workspace'**
  String get selectWorkspace;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @connectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect device'**
  String get connectDevice;

  /// No description provided for @disconnectDevice.
  ///
  /// In en, this message translates to:
  /// **'Disconnect device'**
  String get disconnectDevice;

  /// No description provided for @noDevice.
  ///
  /// In en, this message translates to:
  /// **'No device'**
  String get noDevice;

  /// No description provided for @console.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get console;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @autoScroll.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll'**
  String get autoScroll;

  /// No description provided for @sendData.
  ///
  /// In en, this message translates to:
  /// **'Send data'**
  String get sendData;

  /// No description provided for @inputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter data to send...'**
  String get inputPlaceholder;

  /// No description provided for @textMode.
  ///
  /// In en, this message translates to:
  /// **'TEXT'**
  String get textMode;

  /// No description provided for @hexMode.
  ///
  /// In en, this message translates to:
  /// **'HEX'**
  String get hexMode;

  /// No description provided for @lineEnding.
  ///
  /// In en, this message translates to:
  /// **'Line ending'**
  String get lineEnding;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @lf.
  ///
  /// In en, this message translates to:
  /// **'LF'**
  String get lf;

  /// No description provided for @crlf.
  ///
  /// In en, this message translates to:
  /// **'CRLF'**
  String get crlf;

  /// No description provided for @checksum.
  ///
  /// In en, this message translates to:
  /// **'Checksum'**
  String get checksum;

  /// No description provided for @autoSend.
  ///
  /// In en, this message translates to:
  /// **'Auto-send'**
  String get autoSend;

  /// No description provided for @quickCommands.
  ///
  /// In en, this message translates to:
  /// **'Quick commands'**
  String get quickCommands;

  /// No description provided for @newCommand.
  ///
  /// In en, this message translates to:
  /// **'New command'**
  String get newCommand;

  /// No description provided for @commandName.
  ///
  /// In en, this message translates to:
  /// **'Command name'**
  String get commandName;

  /// No description provided for @commandPayload.
  ///
  /// In en, this message translates to:
  /// **'Payload'**
  String get commandPayload;

  /// No description provided for @sendCommand.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendCommand;

  /// No description provided for @connectedDevice.
  ///
  /// In en, this message translates to:
  /// **'Connected: {name}'**
  String connectedDevice(String name);

  /// No description provided for @deviceCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} devices'**
  String deviceCountShort(int count);

  /// No description provided for @characteristics.
  ///
  /// In en, this message translates to:
  /// **'Characteristics'**
  String get characteristics;

  /// No description provided for @connectToDiscoverCharacteristics.
  ///
  /// In en, this message translates to:
  /// **'Connect a device to discover its GATT characteristics.'**
  String get connectToDiscoverCharacteristics;

  /// No description provided for @noCharacteristics.
  ///
  /// In en, this message translates to:
  /// **'No GATT characteristics were discovered.'**
  String get noCharacteristics;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @writeTarget.
  ///
  /// In en, this message translates to:
  /// **'Write target'**
  String get writeTarget;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @writeWithResponse.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get writeWithResponse;

  /// No description provided for @writeWithoutResponse.
  ///
  /// In en, this message translates to:
  /// **'Write no response'**
  String get writeWithoutResponse;

  /// No description provided for @notify.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get notify;

  /// No description provided for @indicate.
  ///
  /// In en, this message translates to:
  /// **'Indicate'**
  String get indicate;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
