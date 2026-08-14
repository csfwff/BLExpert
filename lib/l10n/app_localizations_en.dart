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
  String get error => 'ERROR';

  @override
  String get deviceUnavailable =>
      'The BLE device is no longer available. Scan again and reconnect.';

  @override
  String bluetoothOperationFailed(String error) {
    return 'Bluetooth operation failed: $error';
  }

  @override
  String get connecting => 'Connecting';

  @override
  String connectingDevice(String name) {
    return 'Connecting to $name...';
  }

  @override
  String disconnectingDevice(String name) {
    return 'Disconnecting from $name...';
  }

  @override
  String connectedToDevice(String name) {
    return 'Connected to $name.';
  }

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

  @override
  String get characteristics => 'Characteristics';

  @override
  String get connectToDiscoverCharacteristics =>
      'Connect a device to discover its GATT characteristics.';

  @override
  String get noCharacteristics => 'No GATT characteristics were discovered.';

  @override
  String get service => 'Service';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get writeTarget => 'Write target';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get writeWithResponse => 'Write';

  @override
  String get writeWithoutResponse => 'Write no response';

  @override
  String get notify => 'Notify';

  @override
  String get indicate => 'Indicate';

  @override
  String get read => 'Read';

  @override
  String get readValue => 'Read';

  @override
  String dataSent(int length) {
    return 'Sent $length bytes';
  }

  @override
  String dataRead(int length) {
    return 'Read $length bytes';
  }

  @override
  String subscriptionEnabled(String mode) {
    return 'Subscribed $mode';
  }

  @override
  String subscriptionDisabled(String mode) {
    return 'Unsubscribed $mode';
  }

  @override
  String get genericAccess => 'Generic Access';

  @override
  String get genericAttribute => 'Generic Attribute';

  @override
  String get deviceName => 'Device Name';

  @override
  String get serviceChanged => 'Service Changed';

  @override
  String get webServiceUuids => 'Web service UUIDs';

  @override
  String get webServiceUuidsHint => 'One UUID per line or separated by commas';

  @override
  String get webServiceUuidsInvalid =>
      'Enter valid 16-bit, 32-bit, or 128-bit UUIDs.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get communication => 'Communication';

  @override
  String get workspaceSettings => 'Workspace';

  @override
  String get deviceTools => 'Device';

  @override
  String get dataView => 'Data';

  @override
  String get editWorkspace => 'Edit workspace';

  @override
  String get deviceModel => 'Device model';

  @override
  String get description => 'Description';

  @override
  String get tags => 'Tags';

  @override
  String get workspaceDevices => 'Device profiles';

  @override
  String get sentPackets => 'Sent';

  @override
  String get receivedPackets => 'Received';

  @override
  String get noPacketData => 'No data';

  @override
  String get noCommands => 'This workspace has no commands yet.';

  @override
  String get editCommand => 'Edit command';

  @override
  String get deleteCommand => 'Delete command';

  @override
  String get commandGroup => 'Group';

  @override
  String get commandNotes => 'Notes';

  @override
  String get commandFormat => 'Payload format';

  @override
  String get commandHex => 'HEX';

  @override
  String get commandText => 'Text';

  @override
  String get commandEnabled => 'Enabled';

  @override
  String get invalidCommandPayload => 'Enter valid payload data.';

  @override
  String get commandLibrary => 'Commands';

  @override
  String get quickAccess => 'Quick access';

  @override
  String get noQuickCommands => 'No quick commands selected.';

  @override
  String get protocolProfiles => 'Protocols';

  @override
  String get newProtocol => 'New protocol';

  @override
  String get editProtocol => 'Edit protocol';

  @override
  String get deleteProtocol => 'Delete protocol';

  @override
  String get noProtocolProfiles =>
      'This workspace has no protocol definitions yet.';

  @override
  String get protocolName => 'Protocol name';

  @override
  String get protocolHeader => 'Header HEX';

  @override
  String get protocolFooter => 'Footer HEX';

  @override
  String get sendFrame => 'Send frame';

  @override
  String get receiveFrame => 'Receive frame';

  @override
  String get lengthField => 'Length field';

  @override
  String get sequenceField => 'Sequence field';

  @override
  String get checksumField => 'Checksum field';

  @override
  String get fieldOffset => 'Field offset';

  @override
  String get fieldByteLength => 'Byte length';

  @override
  String get checksumAlgorithm => 'Checksum algorithm';

  @override
  String get byteOrder => 'Byte order';

  @override
  String get calculationRange => 'Calculation range';

  @override
  String get payloadRange => 'Payload';

  @override
  String get frameExcludingChecksum => 'Frame excluding checksum field';

  @override
  String get invalidProtocol =>
      'Enter a protocol name and configure at least one valid frame rule.';

  @override
  String get newProtocolSegment => 'Add segment';

  @override
  String get editProtocolSegment => 'Edit segment';

  @override
  String get deleteProtocolSegment => 'Delete segment';

  @override
  String get noProtocolSegments => 'No segments configured yet.';

  @override
  String get segmentType => 'Segment type';

  @override
  String get segmentLabel => 'Segment label';

  @override
  String get fixedHexSegment => 'Fixed HEX';

  @override
  String get payloadSegment => 'Payload';

  @override
  String get invalidProtocolSegment => 'Enter a valid segment configuration.';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get scriptProtocolMode => 'Script protocol';

  @override
  String get editScriptConfig => 'Edit scripts';

  @override
  String get scriptEnabled => 'Enable script protocol mode';

  @override
  String get scriptEngineReady =>
      'JavaScript runtime is available on this platform';

  @override
  String get scriptEngineUnavailable =>
      'This platform only supports editing scripts';

  @override
  String get beforeSendScript => 'Before-send script';

  @override
  String get afterReceiveScript => 'After-receive script';

  @override
  String get loadProtocolSample => 'Load sample protocol scripts';

  @override
  String get scriptRuntime => 'Script runtime';

  @override
  String get enabledState => 'Enabled';

  @override
  String get disabledState => 'Disabled';
}
