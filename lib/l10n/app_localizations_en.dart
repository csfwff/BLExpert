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
  String get newWorkspace => 'New workspace';

  @override
  String get deleteWorkspace => 'Delete workspace';

  @override
  String deleteWorkspaceConfirm(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get deleteWorkspaceLast => 'At least one workspace must remain.';

  @override
  String get workspaceSaved => 'Workspace saved.';

  @override
  String get importWorkspace => 'Import workspace';

  @override
  String get exportWorkspace => 'Export workspace';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get settings => 'Settings';

  @override
  String get debug => 'Debug';

  @override
  String get configure => 'Configure';

  @override
  String get records => 'Records';

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
  String get selectDeviceFirst => 'Select a device first';

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
  String get allFilter => 'All';

  @override
  String get txFilter => 'TX';

  @override
  String get rxFilter => 'RX';

  @override
  String get systemFilter => 'SYS';

  @override
  String get errorFilter => 'ERR';

  @override
  String get filterLogs => 'Filter logs';

  @override
  String get searchLogs => 'Search logs, HEX, source or command';

  @override
  String get noMatchingLogs => 'No matching logs';

  @override
  String get backToLatest => 'Back to latest';

  @override
  String get exportLogs => 'Export logs';

  @override
  String retainedLogs(int retained, int discarded) {
    return '$retained retained / $discarded discarded';
  }

  @override
  String get clear => 'Clear';

  @override
  String get autoScroll => 'Auto-scroll';

  @override
  String get sendData => 'Send data';

  @override
  String sendUnavailable(String reason) {
    return 'Sending unavailable: $reason';
  }

  @override
  String get noWriteTargetSelected => 'No writable characteristic selected';

  @override
  String get inputPlaceholder => 'Enter data to send...';

  @override
  String get emptyInput => 'Enter data to send';

  @override
  String get invalidHexInput => 'Invalid HEX data';

  @override
  String payloadLength(int length) {
    return 'Payload $length bytes';
  }

  @override
  String finalFramePreview(int length, String frame) {
    return 'Final frame $length bytes: $frame';
  }

  @override
  String get scriptPreviewUnavailable =>
      'Script mode: final frame is generated before sending';

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
  String get filterCharacteristics => 'Filter characteristic or UUID';

  @override
  String get operableOnly => 'Show operable characteristics only';

  @override
  String get noMatchingCharacteristics => 'No matching characteristics.';

  @override
  String get service => 'Service';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get writeTarget => 'Write target';

  @override
  String get selectedLog => 'Selected log';

  @override
  String get viewLogDetails => 'View log details';

  @override
  String get source => 'Source';

  @override
  String get length => 'Length';

  @override
  String get transaction => 'Transaction';

  @override
  String get noSource => 'No source';

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
  String get configurationErrors => 'Fix these issues before saving:';

  @override
  String requiredField(String field) {
    return '$field is required';
  }

  @override
  String get invalidHexPayload => 'HEX payload must contain complete bytes.';

  @override
  String get invalidCommandParameters =>
      'Each parameter key must exist and be used in the payload.';

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

  @override
  String get standardProtocol => 'Standard protocol';

  @override
  String get standardProtocolHint =>
      'Use for protocols described by fixed HEX, payload, length, sequence, and checksum fields. Configure ordered segments separately for send and receive.';

  @override
  String get scriptProtocolHint =>
      'Use for encryption, escaping, dynamic CRC, TLV, or custom framing. Scripts take ownership of full-frame encoding and decoding.';

  @override
  String get scriptMethods => 'Required methods';

  @override
  String get beforeSendContract =>
      'Called before sending. Accepts business payload HEX and returns the complete frame HEX to write.';

  @override
  String get afterReceiveContract =>
      'Called after receiving. Accepts a complete received frame HEX and returns decoded payload and validation state.';

  @override
  String get scriptBuiltins => 'Built-in script tools';

  @override
  String get scriptBuiltinsHint =>
      'Injected automatically by the runtime. Checksums return unsigned integers, hashes return uppercase HEX; value accepts HEX text or byte arrays.';

  @override
  String get dataMappings => 'Data mappings';

  @override
  String get addResponseMapping => 'Add response mapping';

  @override
  String get dataMappingHint =>
      'After protocol or script decoding produces CMD and DATA, field offsets begin at DATA byte 0.';

  @override
  String get noResponseMappings => 'No response mappings configured.';

  @override
  String mappingFieldCount(String command, int count) {
    return 'CMD $command | $count fields';
  }

  @override
  String get newResponseMapping => 'New response mapping';

  @override
  String get editResponseMapping => 'Edit response mapping';

  @override
  String get deleteResponseMapping => 'Delete response mapping';

  @override
  String get responseName => 'Response name';

  @override
  String get responseCommandHex => 'Response CMD HEX';

  @override
  String get responseFieldsHint => 'Fields (offsets are relative to DATA)';

  @override
  String get addDataField => 'Add field';

  @override
  String get responseAsciiLog => 'ASCII log decoding';

  @override
  String get responseAsciiLogHint =>
      'When this response matches, append printable ASCII with NUL and control bytes removed.';

  @override
  String get invalidResponseMapping =>
      'Enter a response name, one CMD byte, and field keys.';

  @override
  String asciiDecodedLog(String name, String value) {
    return 'ASCII $name: $value';
  }

  @override
  String get fieldKey => 'Field key';

  @override
  String get fieldLabel => 'Field label';

  @override
  String get deleteDataField => 'Delete field';

  @override
  String get dataOffset => 'DATA offset';

  @override
  String get dataFieldType => 'Field type';

  @override
  String get numericScale => 'Scale';

  @override
  String get numericOffset => 'Numeric offset';

  @override
  String get unit => 'Unit';

  @override
  String get bitNumber => 'Bit number';

  @override
  String get bitNumberHint => 'Zero-based';

  @override
  String get enumValues => 'Enum values';

  @override
  String get enumValuesHint => 'value=display name, separated by commas';

  @override
  String get commandsAndData => 'Commands & data';

  @override
  String get mappedData => 'Mapped data';

  @override
  String get noMappedFields => 'No mapped fields selected for display.';

  @override
  String get showInDataPanel => 'Show in data panel';

  @override
  String commandLog(String name, String parameters) {
    return 'Command $name: $parameters';
  }

  @override
  String responseLog(String name, String command, String values) {
    return 'Response $name (CMD $command): $values';
  }
}
