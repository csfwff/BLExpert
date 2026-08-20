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

  /// No description provided for @newWorkspace.
  ///
  /// In en, this message translates to:
  /// **'New workspace'**
  String get newWorkspace;

  /// No description provided for @deleteWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Delete workspace'**
  String get deleteWorkspace;

  /// No description provided for @deleteWorkspaceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? This cannot be undone.'**
  String deleteWorkspaceConfirm(String name);

  /// No description provided for @deleteWorkspaceLast.
  ///
  /// In en, this message translates to:
  /// **'At least one workspace must remain.'**
  String get deleteWorkspaceLast;

  /// No description provided for @workspaceSaved.
  ///
  /// In en, this message translates to:
  /// **'Workspace saved.'**
  String get workspaceSaved;

  /// No description provided for @importWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Import workspace'**
  String get importWorkspace;

  /// No description provided for @exportWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Export workspace'**
  String get exportWorkspace;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configure;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

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

  /// No description provided for @selectDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a device first'**
  String get selectDeviceFirst;

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

  /// No description provided for @disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get disconnecting;

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

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @txFilter.
  ///
  /// In en, this message translates to:
  /// **'TX'**
  String get txFilter;

  /// No description provided for @rxFilter.
  ///
  /// In en, this message translates to:
  /// **'RX'**
  String get rxFilter;

  /// No description provided for @systemFilter.
  ///
  /// In en, this message translates to:
  /// **'SYS'**
  String get systemFilter;

  /// No description provided for @errorFilter.
  ///
  /// In en, this message translates to:
  /// **'ERR'**
  String get errorFilter;

  /// No description provided for @filterLogs.
  ///
  /// In en, this message translates to:
  /// **'Filter logs'**
  String get filterLogs;

  /// No description provided for @searchLogs.
  ///
  /// In en, this message translates to:
  /// **'Search logs, HEX, source or command'**
  String get searchLogs;

  /// No description provided for @noMatchingLogs.
  ///
  /// In en, this message translates to:
  /// **'No matching logs'**
  String get noMatchingLogs;

  /// No description provided for @backToLatest.
  ///
  /// In en, this message translates to:
  /// **'Back to latest'**
  String get backToLatest;

  /// No description provided for @exportLogs.
  ///
  /// In en, this message translates to:
  /// **'Export logs'**
  String get exportLogs;

  /// No description provided for @retainedLogs.
  ///
  /// In en, this message translates to:
  /// **'{retained} retained / {discarded} discarded'**
  String retainedLogs(int retained, int discarded);

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

  /// No description provided for @sendUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sending unavailable: {reason}'**
  String sendUnavailable(String reason);

  /// No description provided for @noWriteTargetSelected.
  ///
  /// In en, this message translates to:
  /// **'No writable characteristic selected'**
  String get noWriteTargetSelected;

  /// No description provided for @inputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter data to send...'**
  String get inputPlaceholder;

  /// No description provided for @emptyInput.
  ///
  /// In en, this message translates to:
  /// **'Enter data to send'**
  String get emptyInput;

  /// No description provided for @invalidHexInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid HEX data'**
  String get invalidHexInput;

  /// No description provided for @payloadLength.
  ///
  /// In en, this message translates to:
  /// **'Payload {length} bytes'**
  String payloadLength(int length);

  /// No description provided for @finalFramePreview.
  ///
  /// In en, this message translates to:
  /// **'Final frame {length} bytes: {frame}'**
  String finalFramePreview(int length, String frame);

  /// No description provided for @scriptPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Script mode: final frame is generated before sending'**
  String get scriptPreviewUnavailable;

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

  /// No description provided for @filterCharacteristics.
  ///
  /// In en, this message translates to:
  /// **'Filter characteristic or UUID'**
  String get filterCharacteristics;

  /// No description provided for @operableOnly.
  ///
  /// In en, this message translates to:
  /// **'Show operable characteristics only'**
  String get operableOnly;

  /// No description provided for @noMatchingCharacteristics.
  ///
  /// In en, this message translates to:
  /// **'No matching characteristics.'**
  String get noMatchingCharacteristics;

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

  /// No description provided for @readCapabilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Read: the client retrieves data'**
  String get readCapabilityDescription;

  /// No description provided for @writeCapabilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Write with response: the client sends data and the server confirms receipt'**
  String get writeCapabilityDescription;

  /// No description provided for @writeNoResponseCapabilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Write without response: the client sends data without a server confirmation'**
  String get writeNoResponseCapabilityDescription;

  /// No description provided for @notifyCapabilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Notify: the server sends data without a client confirmation'**
  String get notifyCapabilityDescription;

  /// No description provided for @indicateCapabilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Indicate: the server sends data and the client confirms receipt'**
  String get indicateCapabilityDescription;

  /// No description provided for @selectedLog.
  ///
  /// In en, this message translates to:
  /// **'Selected log'**
  String get selectedLog;

  /// No description provided for @viewLogDetails.
  ///
  /// In en, this message translates to:
  /// **'View log details'**
  String get viewLogDetails;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// No description provided for @transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transaction;

  /// No description provided for @noSource.
  ///
  /// In en, this message translates to:
  /// **'No source'**
  String get noSource;

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

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @readValue.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readValue;

  /// No description provided for @dataSent.
  ///
  /// In en, this message translates to:
  /// **'Sent {length} bytes'**
  String dataSent(int length);

  /// No description provided for @dataRead.
  ///
  /// In en, this message translates to:
  /// **'Read {length} bytes'**
  String dataRead(int length);

  /// No description provided for @subscriptionEnabled.
  ///
  /// In en, this message translates to:
  /// **'Subscribed {mode}'**
  String subscriptionEnabled(String mode);

  /// No description provided for @subscriptionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed {mode}'**
  String subscriptionDisabled(String mode);

  /// No description provided for @genericAccess.
  ///
  /// In en, this message translates to:
  /// **'Generic Access'**
  String get genericAccess;

  /// No description provided for @genericAttribute.
  ///
  /// In en, this message translates to:
  /// **'Generic Attribute'**
  String get genericAttribute;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// No description provided for @serviceChanged.
  ///
  /// In en, this message translates to:
  /// **'Service Changed'**
  String get serviceChanged;

  /// No description provided for @webServiceUuids.
  ///
  /// In en, this message translates to:
  /// **'Web service UUIDs'**
  String get webServiceUuids;

  /// No description provided for @webServiceUuidsHint.
  ///
  /// In en, this message translates to:
  /// **'One UUID per line or separated by commas'**
  String get webServiceUuidsHint;

  /// No description provided for @webServiceUuidsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter valid 16-bit, 32-bit, or 128-bit UUIDs.'**
  String get webServiceUuidsInvalid;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @communication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get communication;

  /// No description provided for @workspaceSettings.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceSettings;

  /// No description provided for @deviceTools.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceTools;

  /// No description provided for @dataView.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataView;

  /// No description provided for @editWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Edit workspace'**
  String get editWorkspace;

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'Device model'**
  String get deviceModel;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @workspaceDevices.
  ///
  /// In en, this message translates to:
  /// **'Device profiles'**
  String get workspaceDevices;

  /// No description provided for @sentPackets.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sentPackets;

  /// No description provided for @receivedPackets.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get receivedPackets;

  /// No description provided for @noPacketData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noPacketData;

  /// No description provided for @noCommands.
  ///
  /// In en, this message translates to:
  /// **'This workspace has no commands yet.'**
  String get noCommands;

  /// No description provided for @editCommand.
  ///
  /// In en, this message translates to:
  /// **'Edit command'**
  String get editCommand;

  /// No description provided for @deleteCommand.
  ///
  /// In en, this message translates to:
  /// **'Delete command'**
  String get deleteCommand;

  /// No description provided for @commandGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get commandGroup;

  /// No description provided for @commandNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commandNotes;

  /// No description provided for @commandFormat.
  ///
  /// In en, this message translates to:
  /// **'Payload format'**
  String get commandFormat;

  /// No description provided for @commandHex.
  ///
  /// In en, this message translates to:
  /// **'HEX'**
  String get commandHex;

  /// No description provided for @commandText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get commandText;

  /// No description provided for @commandEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commandEnabled;

  /// No description provided for @invalidCommandPayload.
  ///
  /// In en, this message translates to:
  /// **'Enter valid payload data.'**
  String get invalidCommandPayload;

  /// No description provided for @configurationErrors.
  ///
  /// In en, this message translates to:
  /// **'Fix these issues before saving:'**
  String get configurationErrors;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String requiredField(String field);

  /// No description provided for @invalidHexPayload.
  ///
  /// In en, this message translates to:
  /// **'HEX payload must contain complete bytes.'**
  String get invalidHexPayload;

  /// No description provided for @invalidCommandParameters.
  ///
  /// In en, this message translates to:
  /// **'Each parameter key must exist and be used in the payload.'**
  String get invalidCommandParameters;

  /// No description provided for @commandLibrary.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commandLibrary;

  /// No description provided for @quickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get quickAccess;

  /// No description provided for @noQuickCommands.
  ///
  /// In en, this message translates to:
  /// **'No quick commands selected.'**
  String get noQuickCommands;

  /// No description provided for @protocolProfiles.
  ///
  /// In en, this message translates to:
  /// **'Protocols'**
  String get protocolProfiles;

  /// No description provided for @newProtocol.
  ///
  /// In en, this message translates to:
  /// **'New protocol'**
  String get newProtocol;

  /// No description provided for @editProtocol.
  ///
  /// In en, this message translates to:
  /// **'Edit protocol'**
  String get editProtocol;

  /// No description provided for @deleteProtocol.
  ///
  /// In en, this message translates to:
  /// **'Delete protocol'**
  String get deleteProtocol;

  /// No description provided for @noProtocolProfiles.
  ///
  /// In en, this message translates to:
  /// **'This workspace has no protocol definitions yet.'**
  String get noProtocolProfiles;

  /// No description provided for @protocolName.
  ///
  /// In en, this message translates to:
  /// **'Protocol name'**
  String get protocolName;

  /// No description provided for @protocolMode.
  ///
  /// In en, this message translates to:
  /// **'Protocol mode'**
  String get protocolMode;

  /// No description provided for @protocolHeader.
  ///
  /// In en, this message translates to:
  /// **'Header HEX'**
  String get protocolHeader;

  /// No description provided for @protocolFooter.
  ///
  /// In en, this message translates to:
  /// **'Footer HEX'**
  String get protocolFooter;

  /// No description provided for @sendFrame.
  ///
  /// In en, this message translates to:
  /// **'Send frame'**
  String get sendFrame;

  /// No description provided for @receiveFrame.
  ///
  /// In en, this message translates to:
  /// **'Receive frame'**
  String get receiveFrame;

  /// No description provided for @lengthField.
  ///
  /// In en, this message translates to:
  /// **'Length field'**
  String get lengthField;

  /// No description provided for @sequenceField.
  ///
  /// In en, this message translates to:
  /// **'Sequence field'**
  String get sequenceField;

  /// No description provided for @checksumField.
  ///
  /// In en, this message translates to:
  /// **'Checksum field'**
  String get checksumField;

  /// No description provided for @fieldOffset.
  ///
  /// In en, this message translates to:
  /// **'Field offset'**
  String get fieldOffset;

  /// No description provided for @fieldByteLength.
  ///
  /// In en, this message translates to:
  /// **'Byte length'**
  String get fieldByteLength;

  /// No description provided for @checksumAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'Checksum algorithm'**
  String get checksumAlgorithm;

  /// No description provided for @byteOrder.
  ///
  /// In en, this message translates to:
  /// **'Byte order'**
  String get byteOrder;

  /// No description provided for @calculationRange.
  ///
  /// In en, this message translates to:
  /// **'Calculation range'**
  String get calculationRange;

  /// No description provided for @payloadRange.
  ///
  /// In en, this message translates to:
  /// **'Payload'**
  String get payloadRange;

  /// No description provided for @frameExcludingChecksum.
  ///
  /// In en, this message translates to:
  /// **'Frame excluding checksum field'**
  String get frameExcludingChecksum;

  /// No description provided for @invalidProtocol.
  ///
  /// In en, this message translates to:
  /// **'Enter a protocol name and configure at least one valid frame rule.'**
  String get invalidProtocol;

  /// No description provided for @newProtocolSegment.
  ///
  /// In en, this message translates to:
  /// **'Add segment'**
  String get newProtocolSegment;

  /// No description provided for @editProtocolSegment.
  ///
  /// In en, this message translates to:
  /// **'Edit segment'**
  String get editProtocolSegment;

  /// No description provided for @deleteProtocolSegment.
  ///
  /// In en, this message translates to:
  /// **'Delete segment'**
  String get deleteProtocolSegment;

  /// No description provided for @noProtocolSegments.
  ///
  /// In en, this message translates to:
  /// **'No segments configured yet.'**
  String get noProtocolSegments;

  /// No description provided for @segmentType.
  ///
  /// In en, this message translates to:
  /// **'Segment type'**
  String get segmentType;

  /// No description provided for @segmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Segment label'**
  String get segmentLabel;

  /// No description provided for @fixedHexSegment.
  ///
  /// In en, this message translates to:
  /// **'Fixed HEX'**
  String get fixedHexSegment;

  /// No description provided for @payloadSegment.
  ///
  /// In en, this message translates to:
  /// **'Payload'**
  String get payloadSegment;

  /// No description provided for @invalidProtocolSegment.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid segment configuration.'**
  String get invalidProtocolSegment;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @scriptProtocolMode.
  ///
  /// In en, this message translates to:
  /// **'Script protocol'**
  String get scriptProtocolMode;

  /// No description provided for @editScriptConfig.
  ///
  /// In en, this message translates to:
  /// **'Edit scripts'**
  String get editScriptConfig;

  /// No description provided for @scriptEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable script protocol mode'**
  String get scriptEnabled;

  /// No description provided for @scriptEngineReady.
  ///
  /// In en, this message translates to:
  /// **'JavaScript runtime is available on this platform'**
  String get scriptEngineReady;

  /// No description provided for @scriptEngineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This platform only supports editing scripts'**
  String get scriptEngineUnavailable;

  /// No description provided for @beforeSendScript.
  ///
  /// In en, this message translates to:
  /// **'Before-send script'**
  String get beforeSendScript;

  /// No description provided for @afterReceiveScript.
  ///
  /// In en, this message translates to:
  /// **'After-receive script'**
  String get afterReceiveScript;

  /// No description provided for @loadProtocolSample.
  ///
  /// In en, this message translates to:
  /// **'Load sample protocol scripts'**
  String get loadProtocolSample;

  /// No description provided for @scriptRuntime.
  ///
  /// In en, this message translates to:
  /// **'Script runtime'**
  String get scriptRuntime;

  /// No description provided for @enabledState.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabledState;

  /// No description provided for @disabledState.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabledState;

  /// No description provided for @standardProtocol.
  ///
  /// In en, this message translates to:
  /// **'Standard protocol'**
  String get standardProtocol;

  /// No description provided for @standardProtocolHint.
  ///
  /// In en, this message translates to:
  /// **'Use for protocols described by fixed HEX, payload, length, sequence, and checksum fields. Configure ordered segments separately for send and receive.'**
  String get standardProtocolHint;

  /// No description provided for @scriptProtocolHint.
  ///
  /// In en, this message translates to:
  /// **'Use for encryption, escaping, dynamic CRC, TLV, or custom framing. Scripts take ownership of full-frame encoding and decoding.'**
  String get scriptProtocolHint;

  /// No description provided for @scriptMethods.
  ///
  /// In en, this message translates to:
  /// **'Required methods'**
  String get scriptMethods;

  /// No description provided for @beforeSendContract.
  ///
  /// In en, this message translates to:
  /// **'Called before sending. Accepts business payload HEX and returns the complete frame HEX to write.'**
  String get beforeSendContract;

  /// No description provided for @afterReceiveContract.
  ///
  /// In en, this message translates to:
  /// **'Called after receiving. Accepts a complete received frame HEX and returns decoded payload and validation state.'**
  String get afterReceiveContract;

  /// No description provided for @scriptBuiltins.
  ///
  /// In en, this message translates to:
  /// **'Built-in script tools'**
  String get scriptBuiltins;

  /// No description provided for @scriptBuiltinsHint.
  ///
  /// In en, this message translates to:
  /// **'Injected automatically by the runtime. Checksums return unsigned integers, hashes return uppercase HEX; value accepts HEX text or byte arrays.'**
  String get scriptBuiltinsHint;

  /// No description provided for @dataMappings.
  ///
  /// In en, this message translates to:
  /// **'Data mappings'**
  String get dataMappings;

  /// No description provided for @addResponseMapping.
  ///
  /// In en, this message translates to:
  /// **'Add response mapping'**
  String get addResponseMapping;

  /// No description provided for @dataMappingHint.
  ///
  /// In en, this message translates to:
  /// **'After protocol or script decoding produces CMD and DATA, field offsets begin at DATA byte 0.'**
  String get dataMappingHint;

  /// No description provided for @noResponseMappings.
  ///
  /// In en, this message translates to:
  /// **'No response mappings configured.'**
  String get noResponseMappings;

  /// No description provided for @mappingFieldCount.
  ///
  /// In en, this message translates to:
  /// **'CMD {command} | {count} fields'**
  String mappingFieldCount(String command, int count);

  /// No description provided for @newResponseMapping.
  ///
  /// In en, this message translates to:
  /// **'New response mapping'**
  String get newResponseMapping;

  /// No description provided for @editResponseMapping.
  ///
  /// In en, this message translates to:
  /// **'Edit response mapping'**
  String get editResponseMapping;

  /// No description provided for @deleteResponseMapping.
  ///
  /// In en, this message translates to:
  /// **'Delete response mapping'**
  String get deleteResponseMapping;

  /// No description provided for @responseName.
  ///
  /// In en, this message translates to:
  /// **'Response name'**
  String get responseName;

  /// No description provided for @responseCommandHex.
  ///
  /// In en, this message translates to:
  /// **'Response CMD HEX'**
  String get responseCommandHex;

  /// No description provided for @responseFieldsHint.
  ///
  /// In en, this message translates to:
  /// **'Fields (offsets are relative to DATA)'**
  String get responseFieldsHint;

  /// No description provided for @addDataField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get addDataField;

  /// No description provided for @responseAsciiLog.
  ///
  /// In en, this message translates to:
  /// **'ASCII log decoding'**
  String get responseAsciiLog;

  /// No description provided for @responseAsciiLogHint.
  ///
  /// In en, this message translates to:
  /// **'When this response matches, append printable ASCII with NUL and control bytes removed.'**
  String get responseAsciiLogHint;

  /// No description provided for @invalidResponseMapping.
  ///
  /// In en, this message translates to:
  /// **'Enter a response name, one CMD byte, and field keys.'**
  String get invalidResponseMapping;

  /// No description provided for @asciiDecodedLog.
  ///
  /// In en, this message translates to:
  /// **'ASCII {name}: {value}'**
  String asciiDecodedLog(String name, String value);

  /// No description provided for @fieldKey.
  ///
  /// In en, this message translates to:
  /// **'Field key'**
  String get fieldKey;

  /// No description provided for @fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Field label'**
  String get fieldLabel;

  /// No description provided for @deleteDataField.
  ///
  /// In en, this message translates to:
  /// **'Delete field'**
  String get deleteDataField;

  /// No description provided for @dataOffset.
  ///
  /// In en, this message translates to:
  /// **'DATA offset'**
  String get dataOffset;

  /// No description provided for @dataFieldType.
  ///
  /// In en, this message translates to:
  /// **'Field type'**
  String get dataFieldType;

  /// No description provided for @numericScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get numericScale;

  /// No description provided for @numericOffset.
  ///
  /// In en, this message translates to:
  /// **'Numeric offset'**
  String get numericOffset;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @bitNumber.
  ///
  /// In en, this message translates to:
  /// **'Bit number'**
  String get bitNumber;

  /// No description provided for @bitNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Zero-based'**
  String get bitNumberHint;

  /// No description provided for @enumValues.
  ///
  /// In en, this message translates to:
  /// **'Enum values'**
  String get enumValues;

  /// No description provided for @enumValuesHint.
  ///
  /// In en, this message translates to:
  /// **'value=display name, separated by commas'**
  String get enumValuesHint;

  /// No description provided for @commandsAndData.
  ///
  /// In en, this message translates to:
  /// **'Commands & data'**
  String get commandsAndData;

  /// No description provided for @mappedData.
  ///
  /// In en, this message translates to:
  /// **'Mapped data'**
  String get mappedData;

  /// No description provided for @noMappedFields.
  ///
  /// In en, this message translates to:
  /// **'No mapped fields selected for display.'**
  String get noMappedFields;

  /// No description provided for @showInDataPanel.
  ///
  /// In en, this message translates to:
  /// **'Show in data panel'**
  String get showInDataPanel;

  /// No description provided for @commandLog.
  ///
  /// In en, this message translates to:
  /// **'Command {name}: {parameters}'**
  String commandLog(String name, String parameters);

  /// No description provided for @responseLog.
  ///
  /// In en, this message translates to:
  /// **'Response {name} (CMD {command}): {values}'**
  String responseLog(String name, String command, String values);
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
