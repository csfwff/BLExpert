import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'app/design/tool_alert_dialog.dart';
import 'app/design/tool_select.dart';
import 'app/design/tool_text_field.dart';
import 'l10n/app_localizations.dart';
import 'models/workspace.dart';
import 'models/command_definition.dart';
import 'models/data_mapping.dart';
import 'models/device_profile.dart';
import 'models/device_safety_policy.dart';
import 'models/protocol_profile.dart';
import 'models/script_config.dart';
import 'models/session_log_record.dart';
import 'services/bluetooth_service.dart';
import 'services/script_engine.dart';
import 'services/send_safety_policy.dart';
import 'services/command_payload_encoder.dart';
import 'services/packet_encoder.dart';
import 'services/packet_decoder.dart';
import 'services/data_mapper.dart';
import 'services/device_send_policy.dart';
import 'services/workspace_manager.dart';
import 'services/session_log_store.dart';
import 'utils/ascii_utils.dart';
import 'utils/web_service_uuid_parser.dart';

part 'app/app_theme.dart';
part 'app/app_shortcuts.dart';
part 'widgets/app_workspace_shell.dart';
part 'features/debug/console_filter_bar.dart';
part 'features/debug/inspector_panel.dart';
part 'features/configuration/configuration_workspace.dart';
part 'features/records/record_workspace.dart';

void main() => runApp(const BlexpertApp());

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
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
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

class _WorkspaceImportDecision {
  const _WorkspaceImportDecision({
    required this.jsonText,
    required this.mode,
    required this.conflictPolicy,
  });

  final String jsonText;
  final WorkspaceImportMode mode;
  final WorkspaceConflictPolicy conflictPolicy;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    this.bluetoothService,
  });

  final ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final BluetoothService? bluetoothService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _maxConsoleLogs = SessionLogStore.maxRecords;
  static const int _maxPendingReceiveEvents = 64;
  late final WorkspaceManager _workspaceManager;
  late final SessionLogStore _sessionLogStore;
  late final BluetoothService _bluetoothService;
  late final ScriptEngineService _scriptEngine;
  final PacketEncoder _packetEncoder = PacketEncoder();
  final PacketDecoder _packetDecoder = PacketDecoder();
  final ScriptSendRateLimiter _scriptSendRateLimiter = ScriptSendRateLimiter();
  late final StreamSubscription<List<BluetoothDeviceInfo>> _scanSubscription;
  late final StreamSubscription<BluetoothServiceEvent>
  _serviceEventSubscription;
  StreamSubscription<BluetoothIncomingData>? _dataSubscription;
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _consoleSearchController =
      TextEditingController();
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'console-input');

  List<BluetoothDeviceInfo> _devices = <BluetoothDeviceInfo>[];
  List<BluetoothCharacteristicInfo> _characteristics =
      <BluetoothCharacteristicInfo>[];
  final List<SessionLogRecord> _logs = <SessionLogRecord>[];
  SessionLogRecord? _selectedLog;
  int _discardedLogCount = 0;
  _ConsoleLogFilter _consoleLogFilter = _ConsoleLogFilter.all;
  final Map<String, _MonitoredFieldValue> _monitoredValues =
      <String, _MonitoredFieldValue>{};
  String? _selectedDeviceId;
  bool _scanning = false;
  bool _connecting = false;
  bool _hexMode = true;
  bool _autoScroll = true;
  _AppMode _mode = _AppMode.debug;
  bool _inspectorOpen = true;
  List<String> _webOptionalServices = <String>[];
  Future<void> _saveWorkspaceChain = Future<void>.value();
  Future<void> _saveSessionLogsChain = Future<void>.value();
  final List<BluetoothIncomingData> _pendingReceiveEvents =
      <BluetoothIncomingData>[];
  bool _processingReceiveEvents = false;
  String? _pendingTransactionId;
  DateTime? _pendingTransactionStartedAt;

  @override
  void initState() {
    super.initState();
    _workspaceManager = WorkspaceManager();
    unawaited(_restoreWorkspaces());
    _sessionLogStore = SessionLogStore();
    unawaited(_restoreSessionLogs());
    _scriptEngine = ScriptEngineService();
    _bluetoothService =
        widget.bluetoothService ??
        (const bool.fromEnvironment('USE_MOCK_BLUETOOTH')
            ? MockBluetoothService()
            : UniversalBleService());
    _scanSubscription = _bluetoothService.watchScannedDevices().listen((
      devices,
    ) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (_selectedDeviceId == null && devices.isNotEmpty) {
          _selectedDeviceId = devices.first.id;
          unawaited(_watchSelectedIncomingData());
        }
      });
    });
    _serviceEventSubscription = _bluetoothService.watchEvents().listen((event) {
      if (!mounted || event.deviceId != _selectedDeviceId) return;
      if (event.isError) {
        _showBluetoothError(StateError(event.message));
      } else {
        _addSystemLog(event.message);
      }
    });
    // Web Bluetooth requires a user gesture before it may show the device
    // picker, so scanning always starts from the toolbar action.
    _scanning = false;
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _serviceEventSubscription.cancel();
    _dataSubscription?.cancel();
    _inputController.dispose();
    _consoleSearchController.dispose();
    _inputFocusNode.dispose();
    _scriptEngine.dispose();
    unawaited(_bluetoothService.dispose());
    super.dispose();
  }

  BluetoothDeviceInfo? get _selectedDevice {
    for (final device in _devices) {
      if (device.id == _selectedDeviceId) return device;
    }
    return null;
  }

  Future<void> _restoreWorkspaces() async {
    try {
      await _workspaceManager.load();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      _addSystemLog('工作区配置加载失败：$error');
    }
  }

  Future<void> _restoreSessionLogs() async {
    try {
      final List<SessionLogRecord> records = await _sessionLogStore.load();
      if (!mounted) return;
      setState(() {
        // Events can arrive while local records are loading. Keep those newer
        // in-memory entries before appending the previous session.
        _logs.addAll(records);
        if (_logs.length > _maxConsoleLogs) {
          _logs.removeRange(_maxConsoleLogs, _logs.length);
        }
      });
    } catch (error) {
      debugPrint('会话记录加载失败：$error');
    }
  }

  void _persistSessionLogs() {
    final List<SessionLogRecord> snapshot = List<SessionLogRecord>.from(_logs);
    _saveSessionLogsChain = _saveSessionLogsChain
        .then((_) => _sessionLogStore.save(snapshot))
        .catchError((Object error) => debugPrint('会话记录保存失败：$error'));
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _selectedLog = null;
      _discardedLogCount = 0;
    });
    _saveSessionLogsChain = _saveSessionLogsChain
        .then((_) => _sessionLogStore.clear())
        .catchError((Object error) => debugPrint('会话记录清除失败：$error'));
  }

  List<SessionLogRecord> get _visibleConsoleLogs {
    final String query = _consoleSearchController.text.trim().toLowerCase();
    return _logs
        .where((SessionLogRecord entry) {
          final bool matchesKind = switch (_consoleLogFilter) {
            _ConsoleLogFilter.all => true,
            _ConsoleLogFilter.tx => entry.kind == SessionLogKind.sent,
            _ConsoleLogFilter.rx => entry.kind == SessionLogKind.received,
            _ConsoleLogFilter.system => entry.kind == SessionLogKind.system,
            _ConsoleLogFilter.error => entry.kind == SessionLogKind.error,
          };
          if (!matchesKind || query.isEmpty) return matchesKind;
          final String haystack = <String?>[
            entry.message,
            entry.characteristicId,
            entry.commandName,
            entry.transactionId,
            entry.data.isEmpty ? null : _toHex(entry.data),
          ].whereType<String>().join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _toggleSessionLogBookmark(SessionLogRecord record) {
    final int index = _logs.indexOf(record);
    if (index < 0) return;
    setState(() {
      _logs[index] = record.copyWith(bookmarked: !record.bookmarked);
      _persistSessionLogs();
    });
  }

  String _beginSessionTransaction() {
    final DateTime now = DateTime.now();
    final String transactionId =
        'tx-${now.microsecondsSinceEpoch.toRadixString(16)}';
    _pendingTransactionId = transactionId;
    _pendingTransactionStartedAt = now;
    return transactionId;
  }

  String? _consumePendingTransaction() {
    final String? transactionId = _pendingTransactionId;
    final DateTime? startedAt = _pendingTransactionStartedAt;
    _pendingTransactionId = null;
    _pendingTransactionStartedAt = null;
    if (transactionId == null || startedAt == null) return null;
    return DateTime.now().difference(startedAt) <= const Duration(seconds: 5)
        ? transactionId
        : null;
  }

  void _discardPendingTransaction() {
    _pendingTransactionId = null;
    _pendingTransactionStartedAt = null;
  }

  void _persistWorkspaces() {
    _saveWorkspaceChain = _saveWorkspaceChain
        .then((_) => _workspaceManager.save())
        .catchError((Object error) {
          if (mounted) {
            _addSystemLog('工作区配置保存失败：$error');
          }
        });
  }

  void _upsertWorkspace(Workspace workspace) {
    _workspaceManager.upsertWorkspace(workspace);
    _persistWorkspaces();
  }

  Future<void> _watchSelectedIncomingData() async {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) {
      return;
    }
    await _dataSubscription?.cancel();
    _dataSubscription = _bluetoothService.watchIncomingData(deviceId).listen((
      BluetoothIncomingData event,
    ) {
      if (!mounted) {
        return;
      }
      _enqueueIncomingData(event);
    });
  }

  void _enqueueIncomingData(BluetoothIncomingData event) {
    if (_pendingReceiveEvents.length >= _maxPendingReceiveEvents) {
      final String? transactionId = _consumePendingTransaction();
      setState(() {
        _logs.insert(
          0,
          SessionLogRecord(
            kind: SessionLogKind.received,
            timestamp: DateTime.now(),
            data: event.bytes,
            characteristicId: event.sourceKey,
            transactionId: transactionId,
          ),
        );
        _logs.insert(
          0,
          SessionLogRecord.system(
            timestamp: DateTime.now(),
            message: 'RX 处理队列已满，已保留原始数据并跳过协议/脚本处理。',
            characteristicId: event.sourceKey,
            transactionId: transactionId,
          ),
        );
        _trimLogs();
      });
      return;
    }
    _pendingReceiveEvents.add(event);
    if (!_processingReceiveEvents) unawaited(_drainReceiveQueue());
  }

  Future<void> _drainReceiveQueue() async {
    _processingReceiveEvents = true;
    try {
      while (mounted && _pendingReceiveEvents.isNotEmpty) {
        final BluetoothIncomingData event = _pendingReceiveEvents.removeAt(0);
        await _handleIncomingData(event.bytes, sourceKey: event.sourceKey);
      }
    } finally {
      _processingReceiveEvents = false;
    }
  }

  Future<void> _handleIncomingData(
    List<int> payload, {
    String sourceKey = 'read',
  }) async {
    final String? transactionId = _consumePendingTransaction();
    final Workspace workspace = _workspaceManager.activeWorkspace;
    try {
      final bool hasStandardProtocol =
          !workspace.scriptConfig.enabled &&
          workspace.protocol.receiveSegments.isNotEmpty;
      final List<PacketDecodeEvent> decodedEvents = hasStandardProtocol
          ? _packetDecoder.add(
              '${_selectedDeviceId ?? 'default'}/$sourceKey',
              payload,
              workspace.protocol,
            )
          : <PacketDecodeEvent>[];
      final List<PacketDecodeEvent> frameEvents = decodedEvents
          .where(
            (PacketDecodeEvent event) =>
                event.status == PacketDecodeStatus.frame,
          )
          .toList(growable: false);
      if (hasStandardProtocol && frameEvents.isEmpty) {
        for (final PacketDecodeEvent event in decodedEvents.where(
          (PacketDecodeEvent event) =>
              event.status == PacketDecodeStatus.invalid ||
              event.status == PacketDecodeStatus.configurationError,
        )) {
          _addSystemLog(
            'RX 解码失败：${event.message}',
            characteristicId: sourceKey,
            transactionId: transactionId,
          );
        }
        if (mounted) {
          setState(() {
            _logs.insert(
              0,
              SessionLogRecord(
                kind: SessionLogKind.received,
                timestamp: DateTime.now(),
                data: payload,
                characteristicId: sourceKey,
                transactionId: transactionId,
              ),
            );
            _trimLogs();
          });
        }
        return;
      }
      final List<ScriptEngineResult> results = hasStandardProtocol
          ? frameEvents
                .map(
                  (PacketDecodeEvent event) => ScriptEngineResult(
                    bytes: event.payload,
                    logs: <String>['标准解帧：${_toHex(event.frame)}'],
                  ),
                )
                .toList(growable: false)
          : <ScriptEngineResult>[
              await _scriptEngine.afterReceive(workspace.scriptConfig, payload),
            ];
      if (!mounted) return;
      final List<ParsedResponse> parsedResponses = <ParsedResponse>[];
      for (final ScriptEngineResult result in results) {
        final List<int> decodedPayload = result.bytes;
        final String? commandHex =
            result.cmdHex ??
            (decodedPayload.isEmpty
                ? null
                : decodedPayload.first.toRadixString(16).padLeft(2, '0'));
        final String dataHex =
            result.dataHex ??
            (decodedPayload.length < 2
                ? ''
                : _toHex(decodedPayload.sublist(1)));
        final ParsedResponse? parsed =
            result.valid == false || commandHex == null
            ? null
            : DataMapper.tryParse(
                mappings: workspace.responseMappings,
                commandHex: commandHex,
                dataHex: dataHex,
              );
        if (parsed != null) parsedResponses.add(parsed);
      }
      setState(() {
        _logs.insert(
          0,
          SessionLogRecord(
            kind: SessionLogKind.received,
            timestamp: DateTime.now(),
            data: payload,
            characteristicId: sourceKey,
            transactionId: transactionId,
          ),
        );
        for (final ScriptEngineResult result in results) {
          if (!hasStandardProtocol && !listEquals(result.bytes, payload)) {
            _logs.insert(
              0,
              SessionLogRecord.system(
                timestamp: DateTime.now(),
                message: '脚本解码：${_toHex(result.bytes)}',
                characteristicId: sourceKey,
                transactionId: transactionId,
              ),
            );
          }
          for (final String log in result.logs.reversed) {
            _logs.insert(
              0,
              SessionLogRecord.system(
                timestamp: DateTime.now(),
                message: log,
                characteristicId: sourceKey,
                transactionId: transactionId,
              ),
            );
          }
        }
        for (final ParsedResponse parsed in parsedResponses) {
          for (final ParsedDataValue value in parsed.values) {
            _monitoredValues[_monitorFieldId(
              parsed.mapping,
              value.key,
            )] = _MonitoredFieldValue(
              responseName: parsed.mapping.name,
              commandHex: parsed.commandHex,
              value: value,
              timestamp: parsed.timestamp,
            );
          }
          _logs.insert(
            0,
            SessionLogRecord.system(
              timestamp: DateTime.now(),
              message: _formatParsedResponseLog(
                parsed,
                AppLocalizations.of(context)!,
              ),
              characteristicId: sourceKey,
              transactionId: transactionId,
            ),
          );
          if (parsed.mapping.asciiLogEnabled) {
            final String ascii = printableAscii(
              _parseHex(parsed.dataHex) ?? const <int>[],
            );
            if (ascii.isNotEmpty) {
              _logs.insert(
                0,
                SessionLogRecord.system(
                  timestamp: DateTime.now(),
                  message: AppLocalizations.of(
                    context,
                  )!.asciiDecodedLog(parsed.mapping.name, ascii),
                  characteristicId: sourceKey,
                  transactionId: transactionId,
                ),
              );
            }
          }
        }
        _trimLogs();
      });
    } catch (error) {
      _showBluetoothError(error);
    }
  }

  void _selectDevice(String? deviceId) {
    if (deviceId == _selectedDeviceId) {
      return;
    }
    setState(() {
      _packetDecoder.reset();
      _pendingReceiveEvents.clear();
      _selectedDeviceId = deviceId;
      _characteristics = <BluetoothCharacteristicInfo>[];
    });
    unawaited(_watchSelectedIncomingData());
  }

  Future<void> _toggleScan() async {
    try {
      if (_scanning) {
        await _bluetoothService.stopScan();
      } else {
        await _bluetoothService.startScan(
          webOptionalServices: _webOptionalServices,
        );
      }
      if (mounted) {
        setState(() => _scanning = kIsWeb ? false : !_scanning);
      }
    } catch (error) {
      _showBluetoothError(error);
    }
  }

  Future<void> _configureWebServices() async {
    final TextEditingController controller = TextEditingController(
      text: _webOptionalServices.join('\n'),
    );
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<String>? services = await showToolDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        String? validationError;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              ToolAlertDialog(
                icon: Icons.bluetooth_searching_outlined,
                title: l10n.webServiceUuids,
                content: SizedBox(
                  width: 460,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.webServiceUuids,
                      hintText: l10n.webServiceUuidsHint,
                      errorText: validationError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final List<String>? parsed = parseWebServiceUuids(
                        controller.text,
                      );
                      if (parsed == null) {
                        setDialogState(
                          () => validationError = l10n.webServiceUuidsInvalid,
                        );
                        return;
                      }
                      Navigator.of(context).pop(parsed);
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
        );
      },
    );
    controller.dispose();
    if (services == null || !mounted) return;
    setState(() => _webOptionalServices = services);
  }

  void _createWorkspace() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() {
      _workspaceManager.createWorkspace(
        name: '${l10n.newWorkspace} ${_workspaceManager.workspaces.length + 1}',
      );
      _packetDecoder.reset();
      _scriptSendRateLimiter.reset();
      _pendingReceiveEvents.clear();
      _monitoredValues.clear();
      _mode = _AppMode.configure;
    });
    _persistWorkspaces();
  }

  Future<void> _deleteActiveWorkspace() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_workspaceManager.workspaces.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.deleteWorkspaceLast)));
      return;
    }
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final bool confirmed =
        await showToolDialog<bool>(
          context: context,
          builder: (BuildContext context) => ToolAlertDialog(
            icon: Icons.delete_outline,
            title: l10n.deleteWorkspace,
            content: Text(l10n.deleteWorkspaceConfirm(workspace.name)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.deleteWorkspace),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _workspaceManager.removeWorkspace(workspace.id);
      _packetDecoder.reset();
      _scriptSendRateLimiter.reset();
      _pendingReceiveEvents.clear();
      _monitoredValues.clear();
    });
    _persistWorkspaces();
  }

  void _saveWorkspaceDetails(Workspace workspace) {
    if (workspace.id != _workspaceManager.activeWorkspace.id) return;
    setState(() => _upsertWorkspace(workspace));
  }

  void _updateProtocol(ProtocolDefinition protocol) {
    _packetDecoder.reset();
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(protocol: protocol, updatedAt: DateTime.now()),
      ),
    );
  }

  Future<void> _updateScriptConfig(ScriptConfig scriptConfig) async {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    ScriptConfig accepted = scriptConfig;
    if (scriptConfig.enabled && !_scriptEngine.isRuntimeAvailable) {
      accepted = scriptConfig.copyWith(enabled: false);
      _addSystemLog('当前平台不支持可中断脚本执行，已保留脚本配置但保持禁用。');
    }
    if (accepted.enabled &&
        workspace.scriptConfig.trustState ==
            ScriptTrustState.importedUntrusted) {
      final bool confirmed =
          await showToolDialog<bool>(
            context: context,
            builder: (BuildContext context) => ToolAlertDialog(
              icon: Icons.warning_amber_outlined,
              title: '启用未信任脚本？',
              content: Text(
                '来源：${scriptConfig.source}\n'
                '代码规模：${scriptConfig.beforeSendScript.length + scriptConfig.afterReceiveScript.length} 字符\n\n'
                '脚本可修改发送到真实设备的 BLE 数据。仅在已审查脚本内容并信任来源时启用。',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('保持禁用'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('信任并启用'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) {
        if (mounted) setState(() {});
        return;
      }
      accepted = accepted.copyWith(trustState: ScriptTrustState.trustedByUser);
    }
    _packetDecoder.reset();
    _scriptSendRateLimiter.reset();
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(scriptConfig: accepted, updatedAt: DateTime.now()),
      ),
    );
  }

  Future<void> _editCommand([CommandDefinition? existing]) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController nameController = TextEditingController(
      text: existing?.name ?? '',
    );
    final TextEditingController groupController = TextEditingController(
      text: existing?.group ?? '',
    );
    final TextEditingController payloadController = TextEditingController(
      text: existing?.payload ?? '',
    );
    final TextEditingController notesController = TextEditingController(
      text: existing?.notes ?? '',
    );
    final CommandDefinition? command = await showToolDialog<CommandDefinition>(
      context: context,
      builder: (BuildContext context) {
        CommandPayloadFormat format =
            existing?.format ?? CommandPayloadFormat.hex;
        bool enabled = existing?.enabled ?? true;
        bool isQuickAccess = existing?.isQuickAccess ?? false;
        bool requiresConfirmation = existing?.requiresConfirmation ?? false;
        final List<CommandParameter> parameters = <CommandParameter>[
          ...?existing?.parameters,
        ];
        String? validationError;
        String? nameError;
        String? payloadError;
        String? parameterError;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              ToolAlertDialog(
                icon: Icons.terminal_outlined,
                title: existing == null ? l10n.newCommand : l10n.editCommand,
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (validationError != null)
                          Semantics(
                            liveRegion: true,
                            container: true,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${l10n.configurationErrors}\n$validationError',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ToolTextField(
                          key: const ValueKey<String>('command-name-field'),
                          controller: nameController,
                          autofocus: true,
                          label: l10n.commandName,
                          errorText: nameError,
                        ),
                        ToolTextField(
                          key: const ValueKey<String>('command-group-field'),
                          controller: groupController,
                          label: l10n.commandGroup,
                        ),
                        const SizedBox(height: 12),
                        ToolSelect<CommandPayloadFormat>(
                          key: const ValueKey<String>('command-format-select'),
                          value: format,
                          label: l10n.commandFormat,
                          options: <ToolSelectOption<CommandPayloadFormat>>[
                            ToolSelectOption(
                              value: CommandPayloadFormat.hex,
                              label: l10n.commandHex,
                            ),
                            ToolSelectOption(
                              value: CommandPayloadFormat.text,
                              label: l10n.commandText,
                            ),
                          ],
                          onChanged: (CommandPayloadFormat value) {
                            setDialogState(() => format = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        ToolTextField(
                          key: const ValueKey<String>('command-payload-field'),
                          controller: payloadController,
                          minLines: 2,
                          maxLines: 4,
                          label: l10n.commandPayload,
                          errorText: payloadError,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text('参数（在 HEX 中使用 {{key}}）'),
                            ),
                            IconButton(
                              tooltip: '新增参数',
                              onPressed: () => setDialogState(
                                () => parameters.add(_newCommandParameter()),
                              ),
                              icon: const Icon(Icons.add, size: 19),
                            ),
                          ],
                        ),
                        for (int index = 0; index < parameters.length; index++)
                          _CommandParameterEditor(
                            parameter: parameters[index],
                            onChanged: (CommandParameter value) =>
                                setDialogState(() => parameters[index] = value),
                            onDelete: () => setDialogState(
                              () => parameters.removeAt(index),
                            ),
                          ),
                        ToolTextField(
                          key: const ValueKey<String>('command-notes-field'),
                          controller: notesController,
                          minLines: 1,
                          maxLines: 3,
                          label: l10n.commandNotes,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.commandEnabled),
                          value: enabled,
                          onChanged: (bool value) {
                            setDialogState(() => enabled = value);
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.quickAccess),
                          value: isQuickAccess,
                          onChanged: (bool value) {
                            setDialogState(() => isQuickAccess = value);
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('发送前始终确认'),
                          value: requiresConfirmation,
                          onChanged: (bool value) {
                            setDialogState(() => requiresConfirmation = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final String name = nameController.text.trim();
                      final String payload = payloadController.text.trim();
                      final String validationPayload = payload.replaceAll(
                        RegExp(r'\{\{\s*[A-Za-z_][A-Za-z0-9_]*\s*\}\}'),
                        '00',
                      );
                      final bool invalidName = name.isEmpty;
                      final bool invalidPayload =
                          payload.isEmpty ||
                          (format == CommandPayloadFormat.hex &&
                              _parseHex(validationPayload) == null);
                      final bool invalidParameters = parameters.any(
                        (CommandParameter parameter) =>
                            parameter.key.trim().isEmpty ||
                            !payload.contains('{{${parameter.key.trim()}}'),
                      );
                      if (invalidName || invalidPayload || invalidParameters) {
                        setDialogState(() {
                          nameError = invalidName
                              ? l10n.requiredField(l10n.commandName)
                              : null;
                          payloadError = invalidPayload
                              ? (payload.isEmpty
                                    ? l10n.requiredField(l10n.commandPayload)
                                    : l10n.invalidHexPayload)
                              : null;
                          parameterError = invalidParameters
                              ? l10n.invalidCommandParameters
                              : null;
                          validationError = <String>[
                            if (nameError != null) nameError!,
                            if (payloadError != null) payloadError!,
                            if (parameterError != null) parameterError!,
                          ].join('\n');
                        });
                        return;
                      }
                      Navigator.of(context).pop(
                        CommandDefinition(
                          id:
                              existing?.id ??
                              'command-${DateTime.now().microsecondsSinceEpoch}',
                          name: name,
                          group: groupController.text.trim(),
                          payload: payload,
                          format: format,
                          notes: notesController.text.trim(),
                          enabled: enabled,
                          isQuickAccess: isQuickAccess,
                          requiresConfirmation: requiresConfirmation,
                          parameters: parameters,
                        ),
                      );
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      groupController.dispose();
      payloadController.dispose();
      notesController.dispose();
    });
    if (command == null || !mounted) return;
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final List<CommandDefinition> commands = <CommandDefinition>[
      for (final CommandDefinition item in workspace.commands)
        if (item.id != command.id) item,
      command,
    ];
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(commands: commands, updatedAt: DateTime.now()),
      ),
    );
  }

  void _deleteCommand(CommandDefinition command) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          commands: workspace.commands
              .where((CommandDefinition item) => item.id != command.id)
              .toList(growable: false),
          allowedCommandIds: workspace.allowedCommandIds
              .where((String id) => id != command.id)
              .toList(growable: false),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _setCommandEnabled(CommandDefinition command, bool enabled) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          commands: workspace.commands
              .map(
                (CommandDefinition item) => item.id == command.id
                    ? item.copyWith(enabled: enabled)
                    : item,
              )
              .toList(growable: false),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _setCommandQuickAccess(CommandDefinition command, bool enabled) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          commands: workspace.commands
              .map(
                (CommandDefinition item) => item.id == command.id
                    ? item.copyWith(isQuickAccess: enabled)
                    : item,
              )
              .toList(growable: false),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _setCommandWhitelist(List<String> commandIds) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final Set<String> existingIds = workspace.commands
        .map((CommandDefinition command) => command.id)
        .toSet();
    final List<String> sanitizedIds = commandIds
        .where(existingIds.contains)
        .toSet()
        .toList(growable: false);
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          allowedCommandIds: sanitizedIds,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _sendCommandDefinition(
    CommandDefinition command,
    Map<String, String> values,
  ) async {
    try {
      final Workspace workspace = _workspaceManager.activeWorkspace;
      if (!workspace.allowsConfiguredCommand(command.id)) {
        const String message = '工作区命令白名单已拒绝该指令发送。';
        _addSystemLog(
          '$message 指令：${command.name}',
          characteristicId: _currentWriteTargetUuid,
          commandName: command.name,
        );
        _showBluetoothError(StateError(message));
        return;
      }
      final List<int> bytes = CommandPayloadEncoder.encode(command, values);
      _addSystemLog(
        _formatCommandSendLog(command, values, AppLocalizations.of(context)!),
        characteristicId: _currentWriteTargetUuid,
        commandName: command.name,
      );
      await _send(
        bytes,
        commandName: command.name,
        commandRequiresConfirmation: command.requiresConfirmation,
      );
    } catch (error) {
      _showBluetoothError(error);
    }
  }

  Future<void> _editResponseMapping([ResponseMapping? existing]) async {
    final TextEditingController nameController = TextEditingController(
      text: existing?.name ?? '',
    );
    final TextEditingController commandController = TextEditingController(
      text: existing?.commandHex ?? '',
    );
    final ResponseMapping? mapping = await showToolDialog<ResponseMapping>(
      context: context,
      builder: (BuildContext context) {
        final List<DataField> fields = <DataField>[...?existing?.fields];
        bool asciiLogEnabled = existing?.asciiLogEnabled ?? false;
        String? validationError;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              ToolAlertDialog(
                icon: Icons.data_object_outlined,
                title: existing == null
                    ? AppLocalizations.of(context)!.newResponseMapping
                    : AppLocalizations.of(context)!.editResponseMapping,
                content: SizedBox(
                  width: 640,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            )!.responseName,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: commandController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            )!.responseCommandHex,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.responseFieldsHint,
                              ),
                            ),
                            IconButton(
                              tooltip: AppLocalizations.of(
                                context,
                              )!.addDataField,
                              onPressed: () => setDialogState(
                                () => fields.add(_newDataField(fields.length)),
                              ),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        for (int index = 0; index < fields.length; index++)
                          _MappingFieldEditor(
                            field: fields[index],
                            onChanged: (DataField value) =>
                                setDialogState(() => fields[index] = value),
                            onDelete: () =>
                                setDialogState(() => fields.removeAt(index)),
                          ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            AppLocalizations.of(context)!.responseAsciiLog,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.responseAsciiLogHint,
                          ),
                          value: asciiLogEnabled,
                          onChanged: (bool value) =>
                              setDialogState(() => asciiLogEnabled = value),
                        ),
                        if (validationError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              validationError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final String commandHex = commandController.text
                          .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
                      if (nameController.text.trim().isEmpty ||
                          commandHex.length != 2 ||
                          fields.any(
                            (DataField field) => field.key.trim().isEmpty,
                          )) {
                        setDialogState(
                          () => validationError = AppLocalizations.of(
                            context,
                          )!.invalidResponseMapping,
                        );
                        return;
                      }
                      Navigator.of(context).pop(
                        ResponseMapping(
                          id:
                              existing?.id ??
                              'mapping-${DateTime.now().microsecondsSinceEpoch}',
                          name: nameController.text.trim(),
                          commandHex: commandHex.toUpperCase(),
                          fields: fields,
                          asciiLogEnabled: asciiLogEnabled,
                        ),
                      );
                    },
                    child: Text(AppLocalizations.of(context)!.save),
                  ),
                ],
              ),
        );
      },
    );
    nameController.dispose();
    commandController.dispose();
    if (mapping == null || !mounted) return;
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          responseMappings: <ResponseMapping>[
            for (final ResponseMapping item in workspace.responseMappings)
              if (item.id != mapping.id) item,
            mapping,
          ],
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _deleteResponseMapping(ResponseMapping mapping) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          responseMappings: workspace.responseMappings
              .where((ResponseMapping item) => item.id != mapping.id)
              .toList(growable: false),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _toggleConnection() async {
    final device = _selectedDevice;
    if (device == null) {
      _showBluetoothError(StateError('No Bluetooth device selected.'));
      return;
    }
    if (_connecting) {
      return;
    }
    _addSystemLog(
      device.connected
          ? AppLocalizations.of(context)!.disconnectingDevice(device.name)
          : AppLocalizations.of(context)!.connectingDevice(device.name),
    );
    setState(() => _connecting = true);
    try {
      if (device.connected) {
        await _bluetoothService.disconnect(device.id);
        if (mounted) {
          setState(() {
            _characteristics = <BluetoothCharacteristicInfo>[];
            _connecting = false;
          });
        }
      } else {
        await _bluetoothService.connect(device.id);
        final discovered = await _bluetoothService.discoverCharacteristics(
          device.id,
        );
        final characteristics = await _restoreConnectionDefaults(
          device.id,
          discovered,
        );
        if (mounted) {
          setState(() {
            _scanning = false;
            _connecting = false;
            _characteristics = characteristics;
          });
          _addSystemLog(
            AppLocalizations.of(context)!.connectedToDevice(device.name),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _connecting = false;
          _characteristics = <BluetoothCharacteristicInfo>[];
        });
      }
      _showBluetoothError(error);
    }
  }

  Future<void> _setWriteCharacteristic(
    BluetoothCharacteristicInfo characteristic,
  ) async {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) {
      return;
    }
    try {
      await _bluetoothService.setWriteCharacteristic(deviceId, characteristic);
    } catch (error) {
      _showBluetoothError(error);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _characteristics = _characteristics
          .map(
            (BluetoothCharacteristicInfo item) =>
                item.copyWith(isWriteTarget: item.key == characteristic.key),
          )
          .toList(growable: false);
    });
    _saveConnectionDefaults(write: characteristic);
  }

  Future<void> _setSubscription(
    BluetoothCharacteristicInfo characteristic,
    BluetoothSubscriptionMode mode,
    bool enabled,
  ) async {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) {
      return;
    }
    try {
      await _bluetoothService.setCharacteristicSubscription(
        deviceId,
        characteristic,
        enabled,
        mode: mode,
      );
    } catch (error) {
      _showBluetoothError(error);
      return;
    }
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _characteristics = _characteristics
          .map(
            (BluetoothCharacteristicInfo item) => item.key == characteristic.key
                ? item.copyWith(isSubscribed: enabled, subscriptionMode: mode)
                : item,
          )
          .toList(growable: false);
    });
    if (enabled) _saveConnectionDefaults(subscribe: characteristic);
    final String modeLabel = mode == BluetoothSubscriptionMode.indicate
        ? l10n.indicate
        : l10n.notify;
    _addSystemLog(
      enabled
          ? l10n.subscriptionEnabled(modeLabel)
          : l10n.subscriptionDisabled(modeLabel),
    );
  }

  Future<List<BluetoothCharacteristicInfo>> _restoreConnectionDefaults(
    String deviceId,
    List<BluetoothCharacteristicInfo> discovered,
  ) async {
    final DeviceProfile? profile = _workspaceManager.activeWorkspace.devices
        .cast<DeviceProfile?>()
        .firstWhere(
          (DeviceProfile? item) => item!.id == deviceId,
          orElse: () => null,
        );
    if (profile == null) return discovered;
    List<BluetoothCharacteristicInfo> restored = discovered;
    final BluetoothCharacteristicInfo? write = _findConfiguredCharacteristic(
      restored,
      profile.writeCharacteristicUuid,
      profile.serviceUuid,
    );
    if (profile.writeCharacteristicUuid?.isNotEmpty == true) {
      if (write == null ||
          (!write.canWrite && !write.canWriteWithoutResponse)) {
        _addSystemLog('默认写入特征不可用：${profile.writeCharacteristicUuid}');
      } else {
        await _bluetoothService.setWriteCharacteristic(deviceId, write);
        restored = restored
            .map(
              (BluetoothCharacteristicInfo item) =>
                  item.copyWith(isWriteTarget: item.key == write.key),
            )
            .toList(growable: false);
        _addSystemLog('已恢复默认写入特征：${write.characteristicId}');
      }
    }
    final BluetoothCharacteristicInfo? subscribe =
        _findConfiguredCharacteristic(
          restored,
          profile.subscribeCharacteristicUuid,
          profile.serviceUuid,
        );
    if (profile.subscribeCharacteristicUuid?.isNotEmpty == true) {
      if (subscribe == null || !subscribe.canSubscribe) {
        _addSystemLog('默认订阅特征不可用：${profile.subscribeCharacteristicUuid}');
      } else {
        final BluetoothSubscriptionMode mode =
            subscribe.canIndicate && !subscribe.canNotify
            ? BluetoothSubscriptionMode.indicate
            : BluetoothSubscriptionMode.notify;
        await _bluetoothService.setCharacteristicSubscription(
          deviceId,
          subscribe,
          true,
          mode: mode,
        );
        restored = restored
            .map(
              (BluetoothCharacteristicInfo item) => item.key == subscribe.key
                  ? item.copyWith(isSubscribed: true, subscriptionMode: mode)
                  : item,
            )
            .toList(growable: false);
        _addSystemLog('已恢复默认订阅特征：${subscribe.characteristicId}');
      }
    }
    return restored;
  }

  BluetoothCharacteristicInfo? _findConfiguredCharacteristic(
    List<BluetoothCharacteristicInfo> characteristics,
    String? characteristicUuid,
    String? serviceUuid,
  ) {
    if (characteristicUuid == null || characteristicUuid.isEmpty) return null;
    final String characteristic = characteristicUuid.toLowerCase();
    final String? service = serviceUuid?.toLowerCase();
    return characteristics.cast<BluetoothCharacteristicInfo?>().firstWhere(
      (BluetoothCharacteristicInfo? item) =>
          item!.characteristicId.toLowerCase() == characteristic &&
          (service == null ||
              service.isEmpty ||
              item.serviceId.toLowerCase() == service),
      orElse: () => null,
    );
  }

  void _saveConnectionDefaults({
    BluetoothCharacteristicInfo? write,
    BluetoothCharacteristicInfo? subscribe,
  }) {
    final BluetoothDeviceInfo? device = _selectedDevice;
    if (device == null) return;
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final DeviceProfile profile =
        workspace.devices.cast<DeviceProfile?>().firstWhere(
          (DeviceProfile? item) => item!.id == device.id,
          orElse: () => null,
        ) ??
        DeviceProfile(
          id: device.id,
          name: device.name,
          protocol: device.protocol,
          notes: '',
          commands: const <String>[],
          scriptConfig: ScriptConfig.empty(),
        );
    final DeviceProfile updated = profile.copyWith(
      serviceUuid: write?.serviceId ?? subscribe?.serviceId,
      writeCharacteristicUuid: write?.characteristicId,
      subscribeCharacteristicUuid: subscribe?.characteristicId,
      webServiceUuid: write?.serviceId ?? subscribe?.serviceId,
    );
    _upsertWorkspace(
      workspace.copyWith(
        devices: <DeviceProfile>[
          for (final DeviceProfile item in workspace.devices)
            if (item.id != updated.id) item,
          updated,
        ],
        updatedAt: DateTime.now(),
      ),
    );
  }

  DeviceProfile? get _selectedDeviceProfile {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) return null;
    return _workspaceManager.activeWorkspace.devices
        .cast<DeviceProfile?>()
        .firstWhere(
          (DeviceProfile? profile) => profile!.id == deviceId,
          orElse: () => null,
        );
  }

  DeviceSafetyPolicy get _selectedDeviceSafetyPolicy =>
      _selectedDeviceProfile?.safetyPolicy ?? const DeviceSafetyPolicy();

  Future<void> _editSelectedDeviceSafetyPolicy() async {
    final BluetoothDeviceInfo? device = _selectedDevice;
    if (device == null) return;
    final List<BluetoothCharacteristicInfo> writable = _characteristics
        .where(
          (BluetoothCharacteristicInfo characteristic) =>
              characteristic.canWrite || characteristic.canWriteWithoutResponse,
        )
        .toList(growable: false);
    if (writable.isEmpty) return;

    final DeviceSafetyPolicy existing = _selectedDeviceSafetyPolicy;
    final TextEditingController maxFrameController = TextEditingController(
      text: existing.maxFinalFrameBytes?.toString() ?? '',
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final Set<String> allowedKeys = existing.allowedWriteTargetKeys
        .where(
          (String key) => writable.any(
            (BluetoothCharacteristicInfo characteristic) =>
                characteristic.key.toLowerCase() == key.toLowerCase(),
          ),
        )
        .toSet();
    bool requireWriteWithResponse = existing.requireWriteWithResponse;
    final DeviceSafetyPolicy?
    updated = await showToolDialog<DeviceSafetyPolicy>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            ToolAlertDialog(
              icon: Icons.shield_outlined,
              title: '设备发送策略',
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('设备：${device.name}'),
                        const SizedBox(height: 12),
                        const Text('选择允许作为写入目标的特征；不选择表示不限制。'),
                        const SizedBox(height: 4),
                        for (final BluetoothCharacteristicInfo characteristic
                            in writable)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              characteristic.characteristicId,
                              softWrap: true,
                            ),
                            subtitle: Text(
                              characteristic.serviceId,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            value: allowedKeys.contains(characteristic.key),
                            onChanged: (bool? value) => setDialogState(() {
                              if (value ?? false) {
                                allowedKeys.add(characteristic.key);
                              } else {
                                allowedKeys.remove(characteristic.key);
                              }
                            }),
                          ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: maxFrameController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '最终帧最大字节数',
                            hintText: '留空表示不限制（全局上限 4096）',
                            border: OutlineInputBorder(),
                          ),
                          validator: (String? value) {
                            final String trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            final int? parsed = int.tryParse(trimmed);
                            if (parsed == null ||
                                parsed < 1 ||
                                parsed > ScriptEngineService.maxPacketBytes) {
                              return '请输入 1 到 ${ScriptEngineService.maxPacketBytes} 的整数。';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('只允许带响应写入'),
                          subtitle: const Text(
                            '仅支持 Write without response 的特征将被拒绝。',
                          ),
                          value: requireWriteWithResponse,
                          onChanged: (bool value) => setDialogState(
                            () => requireWriteWithResponse = value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final String limitText = maxFrameController.text.trim();
                    Navigator.pop(
                      context,
                      DeviceSafetyPolicy(
                        allowedWriteTargetKeys: allowedKeys.toList(
                          growable: false,
                        ),
                        maxFinalFrameBytes: limitText.isEmpty
                            ? null
                            : int.parse(limitText),
                        requireWriteWithResponse: requireWriteWithResponse,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maxFrameController.dispose(),
    );
    if (updated == null || !mounted) return;

    final Workspace workspace = _workspaceManager.activeWorkspace;
    final DeviceProfile profile =
        _selectedDeviceProfile ??
        DeviceProfile(
          id: device.id,
          name: device.name,
          protocol: device.protocol,
          notes: '',
          commands: const <String>[],
          scriptConfig: ScriptConfig.empty(),
        );
    final DeviceProfile updatedProfile = profile.copyWith(
      safetyPolicy: updated,
    );
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          devices: <DeviceProfile>[
            for (final DeviceProfile item in workspace.devices)
              if (item.id != updatedProfile.id) item,
            updatedProfile,
          ],
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _send(
    List<int> bytes, {
    String? commandName,
    bool commandRequiresConfirmation = false,
  }) async {
    final device = _selectedDevice;
    if (device == null || !_hasWriteTarget) return;
    String? transactionId;
    try {
      final Workspace workspace = _workspaceManager.activeWorkspace;
      final bool hasStandardProtocol =
          !workspace.scriptConfig.enabled &&
          workspace.protocol.sendSegments.isNotEmpty;
      final List<int> businessPayload = List<int>.unmodifiable(bytes);
      ScriptEngineResult result;
      if (hasStandardProtocol) {
        final PacketEncoderResult encoded = _packetEncoder.encode(
          workspace.protocol,
          businessPayload,
        );
        result = ScriptEngineResult(
          bytes: encoded.frame,
          logs: <String>[
            'standard protocol encoded ${encoded.frame.length} bytes',
          ],
          payloadHex: _formatHexForLog(encoded.payload),
        );
      } else {
        result = await _scriptEngine.beforeSend(
          workspace.scriptConfig,
          businessPayload,
        );
      }
      if (result.bytes.isEmpty) {
        throw const FormatException('最终发送帧不能为空。');
      }
      if (result.bytes.length > ScriptEngineService.maxPacketBytes) {
        throw const FormatException('最终发送帧超过 4096 字节上限。');
      }
      final BluetoothCharacteristicInfo? writeTarget = _characteristics
          .cast<BluetoothCharacteristicInfo?>()
          .firstWhere(
            (BluetoothCharacteristicInfo? item) => item!.isWriteTarget,
            orElse: () => null,
          );
      if (writeTarget == null) return;
      final DeviceSendPolicyDecision devicePolicyDecision =
          DeviceSendPolicy.evaluate(
            policy: _selectedDeviceSafetyPolicy,
            writeTargetKey: writeTarget.key,
            writeWithResponseAvailable: writeTarget.canWrite,
            finalFrameLength: result.bytes.length,
          );
      if (!devicePolicyDecision.allowed) {
        final String reason = _devicePolicyReason(devicePolicyDecision);
        _addSystemLog(
          '设备发送策略已拒绝：$reason',
          characteristicId: writeTarget.characteristicId,
          commandName: commandName,
        );
        throw StateError('设备发送策略已拒绝：$reason');
      }
      final SendSafetyDecision safetyDecision = SendSafetyPolicy.evaluate(
        businessPayload: businessPayload,
        finalFrame: result.bytes,
        scriptEnabled: workspace.scriptConfig.enabled,
        commandName: commandName,
        commandRequiresConfirmation: commandRequiresConfirmation,
      );
      if (safetyDecision.requiresConfirmation &&
          !await _confirmProtectedSend(
            safetyDecision: safetyDecision,
            businessPayload: businessPayload,
            finalFrame: result.bytes,
            commandName: commandName,
          )) {
        _addSystemLog(
          '已取消受保护发送。',
          characteristicId: _currentWriteTargetUuid,
          commandName: commandName,
        );
        return;
      }
      if (workspace.scriptConfig.enabled &&
          !_scriptSendRateLimiter.tryAcquire(DateTime.now())) {
        final Duration remaining =
            _scriptSendRateLimiter.remaining(DateTime.now()) ?? Duration.zero;
        _addSystemLog(
          '脚本发送速率限制：请在 ${remaining.inMilliseconds}ms 后重试。',
          characteristicId: _currentWriteTargetUuid,
          commandName: commandName,
        );
        return;
      }
      transactionId = _beginSessionTransaction();
      _addSystemLog(
        'TX payload: ${result.payloadHex ?? _formatHexForLog(businessPayload)} | '
        'frame: ${_formatHexForLog(result.bytes)}',
        characteristicId: _currentWriteTargetUuid,
        commandName: commandName,
        transactionId: transactionId,
      );
      await _bluetoothService.sendData(device.id, result.bytes);
      if (!mounted) return;
      setState(() {
        _logs.insert(
          0,
          SessionLogRecord(
            kind: SessionLogKind.sent,
            timestamp: DateTime.now(),
            data: result.bytes,
            characteristicId: _currentWriteTargetUuid,
            commandName: commandName,
            transactionId: transactionId,
          ),
        );
        for (final String log in result.logs.reversed) {
          _logs.insert(
            0,
            SessionLogRecord.system(
              timestamp: DateTime.now(),
              message: log,
              characteristicId: _currentWriteTargetUuid,
              commandName: commandName,
              transactionId: transactionId,
            ),
          );
        }
        _trimLogs();
      });
      _addSystemLog(
        AppLocalizations.of(context)!.dataSent(result.bytes.length),
        characteristicId: _currentWriteTargetUuid,
        commandName: commandName,
        transactionId: transactionId,
      );
    } catch (error) {
      if (_pendingTransactionId == transactionId) {
        _discardPendingTransaction();
      }
      _showBluetoothError(error);
    }
  }

  String _devicePolicyReason(DeviceSendPolicyDecision decision) => decision
      .reasons
      .map(
        (DeviceSendPolicyReason reason) => switch (reason) {
          DeviceSendPolicyReason.writeTargetNotAllowed => '当前写入特征不在允许列表中',
          DeviceSendPolicyReason.writeWithResponseRequired => '当前特征不支持带响应写入',
          DeviceSendPolicyReason.finalFrameTooLarge => '最终帧超过设备配置的字节上限',
        },
      )
      .join('；');

  Future<bool> _confirmProtectedSend({
    required SendSafetyDecision safetyDecision,
    required List<int> businessPayload,
    required List<int> finalFrame,
    String? commandName,
  }) async {
    final List<String> reasons = safetyDecision.reasons
        .map(
          (SendSafetyReason reason) => switch (reason) {
            SendSafetyReason.scriptTransformed => '脚本已改写业务载荷。',
            SendSafetyReason.potentiallyDangerousCommand =>
              '指令名称可能涉及重置、擦除、升级或认证操作。',
            SendSafetyReason.explicitCommandPolicy => '该工作区将此指令标记为每次发送都需要确认。',
          },
        )
        .toList(growable: false);
    final String? target = _currentWriteTargetUuid;
    return await showToolDialog<bool>(
          context: context,
          builder: (BuildContext context) => ToolAlertDialog(
            icon: Icons.warning_amber_outlined,
            title: '确认受保护发送',
            content: SizedBox(
              width: 560,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: SelectableText(
                    <String>[
                      if (commandName != null && commandName.isNotEmpty)
                        '指令：$commandName',
                      '写入特征：${target ?? '未知'}',
                      '原因：${reasons.join('\n')}',
                      '',
                      '业务载荷：${_formatHexForLog(businessPayload)}',
                      '最终帧：${_formatHexForLog(finalFrame)}',
                    ].join('\n'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认发送'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String? get _currentWriteTargetUuid {
    for (final BluetoothCharacteristicInfo characteristic in _characteristics) {
      if (characteristic.isWriteTarget) return characteristic.characteristicId;
    }
    return null;
  }

  String _formatHexForLog(List<int> bytes) => bytes
      .map((int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  Future<void> _readCharacteristic(
    BluetoothCharacteristicInfo characteristic,
  ) async {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) return;
    final String transactionId = _beginSessionTransaction();
    try {
      final List<int> value = await _bluetoothService.readData(
        deviceId,
        characteristic,
      );
      await _handleIncomingData(value, sourceKey: characteristic.key);
      if (!mounted) return;
      _addSystemLog(
        AppLocalizations.of(context)!.dataRead(value.length),
        characteristicId: characteristic.key,
        transactionId: transactionId,
      );
    } catch (error) {
      _discardPendingTransaction();
      _showBluetoothError(error);
    }
  }

  void _showBluetoothError(Object error) {
    if (!mounted) {
      return;
    }
    final String message = _bluetoothErrorMessage(error);
    setState(() {
      _logs.insert(
        0,
        SessionLogRecord.error(
          timestamp: DateTime.now(),
          message: '$message\n${error.toString()}',
        ),
      );
      _trimLogs();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addSystemLog(
    String message, {
    String? characteristicId,
    String? commandName,
    String? transactionId,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.insert(
        0,
        SessionLogRecord.system(
          timestamp: DateTime.now(),
          message: message,
          characteristicId: characteristicId,
          commandName: commandName,
          transactionId: transactionId,
        ),
      );
      _trimLogs();
    });
  }

  void _trimLogs() {
    if (_logs.length > _maxConsoleLogs) {
      _discardedLogCount += _logs.length - _maxConsoleLogs;
      _logs.removeRange(_maxConsoleLogs, _logs.length);
    }
    _persistSessionLogs();
  }

  String _bluetoothErrorMessage(Object error) {
    final String text = error.toString();
    if (text.contains('no longer available')) {
      return AppLocalizations.of(context)!.deviceUnavailable;
    }
    return AppLocalizations.of(context)!.bluetoothOperationFailed(text);
  }

  bool get _hasWriteTarget => _characteristics.any(
    (BluetoothCharacteristicInfo item) => item.isWriteTarget,
  );

  String? _consoleSendDisabledReason(AppLocalizations l10n) {
    if (_selectedDevice == null) return l10n.noDevice;
    if (_selectedDevice?.connected != true) return l10n.disconnected;
    if (!_hasWriteTarget) return l10n.noWriteTargetSelected;
    return null;
  }

  _ConsoleSendPreview _previewConsoleSend(
    String input,
    bool hexMode,
    AppLocalizations l10n,
  ) {
    final String value = input.trim();
    if (value.isEmpty) {
      return _ConsoleSendPreview(error: l10n.emptyInput);
    }
    final List<int>? bytes = hexMode ? _parseHex(value) : utf8.encode(value);
    if (bytes == null) {
      return _ConsoleSendPreview(error: l10n.invalidHexInput);
    }
    final Workspace workspace = _workspaceManager.activeWorkspace;
    if (workspace.scriptConfig.enabled) {
      return _ConsoleSendPreview(
        payloadLength: bytes.length,
        scriptPending: true,
      );
    }
    if (workspace.protocol.sendSegments.isEmpty) {
      return _ConsoleSendPreview(
        payloadLength: bytes.length,
        finalFrame: bytes,
      );
    }
    try {
      final PacketEncoderResult encoded = _packetEncoder.preview(
        workspace.protocol,
        bytes,
      );
      return _ConsoleSendPreview(
        payloadLength: bytes.length,
        finalFrame: encoded.frame,
      );
    } on FormatException catch (error) {
      return _ConsoleSendPreview(error: error.message);
    }
  }

  void _sendInput() {
    final value = _inputController.text.trim();
    if (value.isEmpty) return;
    final bytes = _hexMode ? _parseHex(value) : utf8.encode(value);
    if (bytes == null) return;
    _inputController.clear();
    unawaited(_send(bytes));
  }

  void _exportWorkspaces() {
    final jsonText = _workspaceManager.exportWorkspaces();
    showToolDialog<void>(
      context: context,
      builder: (BuildContext context) => ToolAlertDialog(
        icon: Icons.upload_file_outlined,
        title: '导出工作区',
        content: SizedBox(
          width: 640,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonText,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonText));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('工作区 JSON 已复制。')));
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制 JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _importWorkspaces() async {
    final TextEditingController controller = TextEditingController();
    WorkspaceImportPreview? preview;
    String? validationError;
    WorkspaceImportMode mode = WorkspaceImportMode.replace;
    WorkspaceConflictPolicy conflictPolicy =
        WorkspaceConflictPolicy.replaceExisting;
    final _WorkspaceImportDecision?
    decision = await showToolDialog<_WorkspaceImportDecision>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => ToolAlertDialog(
          icon: Icons.download_outlined,
          title: '导入工作区',
          content: SizedBox(
            width: 640,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: controller,
                      minLines: 8,
                      maxLines: 16,
                      onChanged: (_) => setDialogState(() {
                        preview = null;
                        validationError = null;
                      }),
                      decoration: const InputDecoration(
                        labelText: '工作区 JSON',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 14),
                    Text('导入方式', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    SegmentedButton<WorkspaceImportMode>(
                      segments: const <ButtonSegment<WorkspaceImportMode>>[
                        ButtonSegment<WorkspaceImportMode>(
                          value: WorkspaceImportMode.replace,
                          icon: Icon(Icons.sync_disabled_outlined),
                          label: Text('完整替换'),
                        ),
                        ButtonSegment<WorkspaceImportMode>(
                          value: WorkspaceImportMode.merge,
                          icon: Icon(Icons.merge_type_outlined),
                          label: Text('合并导入'),
                        ),
                      ],
                      selected: <WorkspaceImportMode>{mode},
                      onSelectionChanged: (Set<WorkspaceImportMode> value) {
                        setDialogState(() => mode = value.first);
                      },
                    ),
                    if (validationError != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (preview != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        mode == WorkspaceImportMode.replace
                            ? '将替换当前 ${_workspaceManager.workspaces.length} 个工作区，导入 ${preview!.workspaces.length} 个工作区。'
                            : '将合并当前 ${_workspaceManager.workspaces.length} 个工作区，导入 ${preview!.workspaces.length} 个工作区。',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '版本 ${preview!.sourceVersion}${preview!.migrationApplied ? ' -> ${preview!.version}（已迁移）' : ''} | 脚本工作区 ${preview!.scriptedWorkspaceCount} 个（导入后保持禁用）。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (preview!
                          .conflictingWorkspaceIds
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'ID 冲突：${preview!.conflictingWorkspaceIds.join('、')}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (mode == WorkspaceImportMode.merge &&
                          preview!
                              .conflictingWorkspaceIds
                              .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          '冲突处理',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<WorkspaceConflictPolicy>(
                          segments:
                              const <ButtonSegment<WorkspaceConflictPolicy>>[
                                ButtonSegment<WorkspaceConflictPolicy>(
                                  value:
                                      WorkspaceConflictPolicy.replaceExisting,
                                  icon: Icon(Icons.sync_outlined),
                                  label: Text('覆盖当前'),
                                ),
                                ButtonSegment<WorkspaceConflictPolicy>(
                                  value: WorkspaceConflictPolicy.keepExisting,
                                  icon: Icon(Icons.shield_outlined),
                                  label: Text('保留当前'),
                                ),
                              ],
                          selected: <WorkspaceConflictPolicy>{conflictPolicy},
                          onSelectionChanged:
                              (Set<WorkspaceConflictPolicy> value) {
                                setDialogState(
                                  () => conflictPolicy = value.first,
                                );
                              },
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        preview!.workspaces
                            .map((Workspace workspace) => workspace.name)
                            .join('、'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            OutlinedButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () {
                      try {
                        final WorkspaceImportPreview nextPreview =
                            _workspaceManager.previewImport(controller.text);
                        setDialogState(() {
                          preview = nextPreview;
                          validationError = null;
                        });
                      } on FormatException catch (error) {
                        setDialogState(() {
                          preview = null;
                          validationError = error.message;
                        });
                      }
                    },
              child: const Text('检查导入'),
            ),
            FilledButton(
              onPressed: preview == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      _WorkspaceImportDecision(
                        jsonText: controller.text,
                        mode: mode,
                        conflictPolicy: conflictPolicy,
                      ),
                    ),
              child: Text(
                mode == WorkspaceImportMode.replace ? '确认替换' : '确认导入',
              ),
            ),
          ],
        ),
      ),
    );
    // showToolDialog completes before its exit animation disposes TextField.
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        controller.dispose,
      ),
    );
    if (decision == null || !mounted) return;
    try {
      _workspaceManager.importWorkspaces(
        decision.jsonText,
        mode: decision.mode,
        conflictPolicy: decision.conflictPolicy,
      );
      setState(() {
        _packetDecoder.reset();
        _scriptSendRateLimiter.reset();
        _pendingReceiveEvents.clear();
      });
      _persistWorkspaces();
      _addSystemLog(
        '${decision.mode == WorkspaceImportMode.replace ? '已替换' : '已合并'} ${_workspaceManager.workspaces.length} 个工作区；脚本保持未信任且禁用。',
      );
    } on FormatException catch (error) {
      _showBluetoothError(error);
    }
  }

  void _exportSessionLogs(List<SessionLogRecord> records) {
    final String jsonText = const JsonEncoder.withIndent('  ')
        .convert(<String, dynamic>{
          'version': 1,
          'records': records
              .take(SessionLogStore.maxRecords)
              .map((SessionLogRecord record) => record.toJson())
              .toList(growable: false),
        });
    showToolDialog<void>(
      context: context,
      builder: (BuildContext context) => ToolAlertDialog(
        icon: Icons.download_outlined,
        title: '导出会话记录',
        content: SizedBox(
          width: 640,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonText,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = _workspaceManager.activeWorkspace;
    final bool compactToolbar = MediaQuery.sizeOf(context).width < 680;
    return CallbackShortcuts(
      bindings: _appShortcutBindings(
        inputFocusNode: _inputFocusNode,
        onSend: _sendInput,
        onClearLogs: _clearLogs,
        onToggleInspector: () =>
            setState(() => _inspectorOpen = !_inspectorOpen),
      ),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 56,
            titleSpacing: 12,
            title: _AppIdentity(workspace: workspace),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
            actions: <Widget>[
              _WorkspaceSelector(
                workspace: workspace,
                workspaces: _workspaceManager.workspaces,
                compact: compactToolbar,
                onSelected: (String workspaceId) {
                  setState(() {
                    _packetDecoder.reset();
                    _scriptSendRateLimiter.reset();
                    _pendingReceiveEvents.clear();
                    _monitoredValues.clear();
                    _workspaceManager.setActiveWorkspace(workspaceId);
                    _persistWorkspaces();
                  });
                },
                onNew: _createWorkspace,
                onDelete: _deleteActiveWorkspace,
                onExport: _exportWorkspaces,
                onImport: _importWorkspaces,
                l10n: l10n,
              ),
              if (!compactToolbar) ...<Widget>[
                const SizedBox(width: 8),
                _ConnectionSelector(
                  devices: _devices,
                  selectedId: _selectedDeviceId,
                  connected: _selectedDevice?.connected ?? false,
                  connecting: _connecting,
                  onSelected: _selectDevice,
                  onToggleConnection: _toggleConnection,
                  l10n: l10n,
                ),
                const SizedBox(width: 12),
              ],
              if (compactToolbar)
                Tooltip(
                  message: _selectedDevice == null
                      ? l10n.selectDeviceFirst
                      : _selectedDevice?.connected == true
                      ? '${l10n.connected} · ${l10n.disconnectDevice}'
                      : l10n.connectDevice,
                  child: shad.IconButton(
                    key: const ValueKey<String>('connection-action-button'),
                    variance: _selectedDevice?.connected == true
                        ? shad.ButtonVariance.secondary
                        : shad.ButtonVariance.primary,
                    density: shad.ButtonDensity.iconDense,
                    size: shad.ButtonSize.small,
                    onPressed: _selectedDevice == null || _connecting
                        ? null
                        : _toggleConnection,
                    icon: Icon(
                      _connecting
                          ? Icons.sync_outlined
                          : _selectedDevice?.connected == true
                          ? Icons.link_off_outlined
                          : Icons.bluetooth_outlined,
                    ),
                  ),
                ),
              if (compactToolbar) const SizedBox(width: 4),
              if (compactToolbar)
                Tooltip(
                  message: _scanning ? l10n.stopScan : l10n.startScan,
                  child: shad.IconButton(
                    key: const ValueKey<String>('scan-button'),
                    variance: _scanning
                        ? shad.ButtonVariance.outline
                        : shad.ButtonVariance.primary,
                    density: shad.ButtonDensity.iconDense,
                    size: shad.ButtonSize.small,
                    onPressed: _toggleScan,
                    icon: Icon(
                      _scanning ? Icons.stop_circle_outlined : Icons.radar,
                    ),
                  ),
                )
              else
                _ScanButton(
                  scanning: _scanning,
                  onPressed: _toggleScan,
                  l10n: l10n,
                ),
              if (compactToolbar || kIsWeb)
                _AppOverflowMenu(
                  themeMode: widget.themeMode,
                  onThemeModeChanged: widget.onThemeModeChanged,
                  onLocaleChanged: widget.onLocaleChanged,
                  includeAppearance: compactToolbar,
                  onConfigureWebServices: kIsWeb ? _configureWebServices : null,
                  l10n: l10n,
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: _AppWorkspaceShell(
            mode: _mode,
            onModeChanged: (mode) => setState(() => _mode = mode),
            l10n: l10n,
            inspectorOpen: _inspectorOpen,
            onInspectorVisibilityChanged: (value) =>
                setState(() => _inspectorOpen = value),
            debugPane: _ConsoleArea(
              logs: _visibleConsoleLogs,
              discardedLogCount: _discardedLogCount,
              autoScroll: _autoScroll,
              onClear: _clearLogs,
              onAutoScrollChanged: (value) =>
                  setState(() => _autoScroll = value),
              inputController: _inputController,
              searchController: _consoleSearchController,
              inputFocusNode: _inputFocusNode,
              hexMode: _hexMode,
              onModeChanged: (value) => setState(() => _hexMode = value),
              onSend: _sendInput,
              canSend: _selectedDevice?.connected == true && _hasWriteTarget,
              sendDisabledReason: _consoleSendDisabledReason(l10n),
              sendPreview: (String input, bool hexMode) =>
                  _previewConsoleSend(input, hexMode, l10n),
              writeTarget: _characteristics
                  .where((item) => item.isWriteTarget)
                  .map((item) => item.characteristicId)
                  .firstOrNull,
              l10n: l10n,
              selectedLog: _selectedLog,
              onLogSelected: (SessionLogRecord record) =>
                  setState(() => _selectedLog = record),
              logFilter: _consoleLogFilter,
              onLogFilterChanged: (value) =>
                  setState(() => _consoleLogFilter = value),
              onSearchChanged: (_) => setState(() {}),
              onExport: _exportSessionLogs,
            ),
            devicePane: _DeviceToolsPanel(
              characteristics: _characteristics,
              connected: _selectedDevice?.connected == true,
              safetyPolicy: _selectedDeviceSafetyPolicy,
              onSelectWrite: _setWriteCharacteristic,
              onSubscriptionChanged: _setSubscription,
              onRead: _readCharacteristic,
              onEditSafetyPolicy: _editSelectedDeviceSafetyPolicy,
              l10n: l10n,
            ),
            inspectorPane: _InspectorPanel(
              characteristics: _characteristics,
              canSend: _hasWriteTarget,
              onSendCommand: _sendCommandDefinition,
              commands: workspace.commands,
              responseMappings: workspace.responseMappings,
              monitoredValues: _monitoredValues,
              selectedLog: _selectedLog,
              l10n: l10n,
            ),
            configurationPane: _ConfigurationWorkspace(
              workspace: workspace,
              runtimeAvailable: _scriptEngine.isRuntimeAvailable,
              onWorkspaceChanged: _saveWorkspaceDetails,
              onProtocolChanged: _updateProtocol,
              onScriptConfigChanged: _updateScriptConfig,
              onNewCommand: () => _editCommand(),
              onEditCommand: _editCommand,
              onDeleteCommand: _deleteCommand,
              onCommandEnabledChanged: _setCommandEnabled,
              onCommandQuickAccessChanged: _setCommandQuickAccess,
              onCommandWhitelistChanged: _setCommandWhitelist,
              onNewResponseMapping: () => _editResponseMapping(),
              onEditResponseMapping: _editResponseMapping,
              onDeleteResponseMapping: _deleteResponseMapping,
              l10n: l10n,
            ),
            recordPane: _RecordWorkspace(
              logs: _logs,
              l10n: l10n,
              onExport: _exportSessionLogs,
              onToggleBookmark: _toggleSessionLogBookmark,
            ),
            settingsPane: _SettingsWorkspace(
              themeMode: widget.themeMode,
              locale: widget.locale,
              onThemeModeChanged: widget.onThemeModeChanged,
              onLocaleChanged: widget.onLocaleChanged,
              l10n: l10n,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSelector extends StatelessWidget {
  const _WorkspaceSelector({
    required this.workspace,
    required this.workspaces,
    required this.compact,
    required this.onSelected,
    required this.onNew,
    required this.onDelete,
    required this.onExport,
    required this.onImport,
    required this.l10n,
  });
  final Workspace workspace;
  final List<Workspace> workspaces;
  final bool compact;
  final ValueChanged<String> onSelected;
  final VoidCallback onNew;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: l10n.selectWorkspace,
      onSelected: (Object value) {
        if (value is String) {
          onSelected(value);
          return;
        }
        switch (value) {
          case _WorkspaceMenuAction.newWorkspace:
            onNew();
          case _WorkspaceMenuAction.deleteWorkspace:
            onDelete();
          case _WorkspaceMenuAction.exportWorkspaces:
            onExport();
          case _WorkspaceMenuAction.importWorkspaces:
            onImport();
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<Object>>[
        ...workspaces.map(
          (Workspace item) => CheckedPopupMenuItem<Object>(
            value: item.id,
            checked: item.id == workspace.id,
            child: Text(item.name),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _WorkspaceMenuAction.newWorkspace,
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l10n.newWorkspace),
          ),
        ),
        PopupMenuItem<Object>(
          value: _WorkspaceMenuAction.deleteWorkspace,
          enabled: workspaces.length > 1,
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.deleteWorkspace),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _WorkspaceMenuAction.importWorkspaces,
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.importWorkspace),
          ),
        ),
        PopupMenuItem<Object>(
          value: _WorkspaceMenuAction.exportWorkspaces,
          child: ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.exportWorkspace),
          ),
        ),
      ],
      child: compact
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.folder_outlined),
            )
          : SizedBox(
              width: 180,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
    );
  }
}

enum _WorkspaceMenuAction {
  newWorkspace,
  deleteWorkspace,
  exportWorkspaces,
  importWorkspaces,
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.scanning,
    required this.onPressed,
    required this.l10n,
  });

  final bool scanning;
  final VoidCallback onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String label = scanning ? l10n.stopScan : l10n.startScan;
    return shad.Button(
      key: const ValueKey<String>('scan-button'),
      style: scanning
          ? const shad.ButtonStyle.outline(
              size: shad.ButtonSize.small,
              density: shad.ButtonDensity.dense,
            )
          : const shad.ButtonStyle.primary(
              size: shad.ButtonSize.small,
              density: shad.ButtonDensity.dense,
            ),
      onPressed: onPressed,
      leading: Icon(scanning ? Icons.stop_circle_outlined : Icons.radar),
      child: Text(label),
    );
  }
}

class _ConnectionSelector extends StatelessWidget {
  const _ConnectionSelector({
    required this.devices,
    required this.selectedId,
    required this.connected,
    required this.connecting,
    required this.onSelected,
    required this.onToggleConnection,
    required this.l10n,
  });
  final List<BluetoothDeviceInfo> devices;
  final String? selectedId;
  final bool connected;
  final bool connecting;
  final ValueChanged<String?> onSelected;
  final VoidCallback onToggleConnection;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final device = devices.where((item) => item.id == selectedId).firstOrNull;
    final String actionLabel = connecting
        ? l10n.connecting
        : device == null
        ? l10n.selectDeviceFirst
        : connected
        ? '${l10n.connected} · ${l10n.disconnectDevice}'
        : l10n.connectDevice;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: l10n.connection,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: device?.id,
              hint: Text(l10n.noDevice),
              items: devices
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: SizedBox(
                        width: 150,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onSelected,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: actionLabel,
          child: shad.Button(
            key: const ValueKey<String>('connection-action-button'),
            style: connected
                ? const shad.ButtonStyle.secondary(
                    size: shad.ButtonSize.small,
                    density: shad.ButtonDensity.dense,
                  )
                : const shad.ButtonStyle.primary(
                    size: shad.ButtonSize.small,
                    density: shad.ButtonDensity.dense,
                  ),
            onPressed: device == null || connecting ? null : onToggleConnection,
            leading: connecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    connected
                        ? Icons.link_off_outlined
                        : Icons.bluetooth_connected_outlined,
                  ),
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceOverview extends StatefulWidget {
  const _WorkspaceOverview({
    required this.workspace,
    required this.onChanged,
    required this.l10n,
  });

  final Workspace workspace;
  final ValueChanged<Workspace> onChanged;
  final AppLocalizations l10n;

  @override
  State<_WorkspaceOverview> createState() => _WorkspaceOverviewState();
}

class _WorkspaceOverviewState extends State<_WorkspaceOverview> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _deviceModelController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _deviceModelController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _WorkspaceOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id ||
        oldWidget.workspace.updatedAt != widget.workspace.updatedAt) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deviceModelController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _nameController.text = widget.workspace.name;
    _deviceModelController.text = widget.workspace.deviceModel;
    _descriptionController.text = widget.workspace.description;
    _tagsController.text = widget.workspace.tags.join(', ');
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final Workspace updated = widget.workspace.copyWith(
      name: _nameController.text.trim(),
      deviceModel: _deviceModelController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: _tagsController.text
          .split(',')
          .map((String tag) => tag.trim())
          .where((String tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );
    widget.onChanged(updated);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(widget.l10n.workspaceSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.folder_outlined, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.l10n.workspaceSettings,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey<String>('workspace-name-field'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: widget.l10n.workspace),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return widget.l10n.requiredField(widget.l10n.workspace);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey<String>('workspace-device-model-field'),
                  controller: _deviceModelController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: widget.l10n.deviceModel,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey<String>('workspace-description-field'),
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: widget.l10n.description,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey<String>('workspace-tags-field'),
                  controller: _tagsController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: widget.l10n.tags),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.devices_other_outlined,
                      size: 20,
                      color: colors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.l10n.workspaceDevices),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.workspace.devices.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(widget.l10n.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceField extends StatelessWidget {
  const _WorkspaceField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value),
        ],
      ),
    );
  }
}

enum _ProtocolMode { standard, script }

class _ProtocolConfigurationPanel extends StatefulWidget {
  const _ProtocolConfigurationPanel({
    required this.protocol,
    required this.scriptConfig,
    required this.onProtocolChanged,
    required this.onScriptConfigChanged,
    required this.runtimeAvailable,
    required this.l10n,
  });

  final ProtocolDefinition protocol;
  final ScriptConfig scriptConfig;
  final ValueChanged<ProtocolDefinition> onProtocolChanged;
  final ValueChanged<ScriptConfig> onScriptConfigChanged;
  final bool runtimeAvailable;
  final AppLocalizations l10n;

  @override
  State<_ProtocolConfigurationPanel> createState() =>
      _ProtocolConfigurationPanelState();
}

class _ProtocolConfigurationPanelState
    extends State<_ProtocolConfigurationPanel> {
  late final TextEditingController _protocolNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _beforeSendController;
  late final TextEditingController _afterReceiveController;
  late _ProtocolMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.scriptConfig.enabled
        ? _ProtocolMode.script
        : _ProtocolMode.standard;
    _protocolNameController = TextEditingController(text: widget.protocol.name);
    _descriptionController = TextEditingController(
      text: widget.protocol.description,
    );
    _beforeSendController = TextEditingController(
      text: widget.scriptConfig.beforeSendScript,
    );
    _afterReceiveController = TextEditingController(
      text: widget.scriptConfig.afterReceiveScript,
    );
  }

  @override
  void didUpdateWidget(covariant _ProtocolConfigurationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.protocol != widget.protocol) {
      _protocolNameController.text = widget.protocol.name;
      _descriptionController.text = widget.protocol.description;
    }
    if (oldWidget.scriptConfig != widget.scriptConfig) {
      _beforeSendController.text = widget.scriptConfig.beforeSendScript;
      _afterReceiveController.text = widget.scriptConfig.afterReceiveScript;
    }
  }

  @override
  void dispose() {
    _protocolNameController.dispose();
    _descriptionController.dispose();
    _beforeSendController.dispose();
    _afterReceiveController.dispose();
    super.dispose();
  }

  void _updateProtocol({
    List<ProtocolSegment>? sendSegments,
    List<ProtocolSegment>? receiveSegments,
  }) {
    widget.onProtocolChanged(
      widget.protocol.copyWith(
        name: _protocolNameController.text.trim(),
        description: _descriptionController.text.trim(),
        sendSegments: sendSegments,
        receiveSegments: receiveSegments,
      ),
    );
  }

  void _updateScript({bool? enabled}) {
    widget.onScriptConfigChanged(
      widget.scriptConfig.copyWith(
        enabled: enabled,
        beforeSendScript: _beforeSendController.text,
        afterReceiveScript: _afterReceiveController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Text(
          l10n.protocolProfiles,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _protocolNameController,
          onChanged: (_) => _updateProtocol(),
          decoration: InputDecoration(labelText: l10n.protocolName),
        ),
        TextField(
          controller: _descriptionController,
          onChanged: (_) => _updateProtocol(),
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.description),
        ),
        const SizedBox(height: 14),
        SegmentedButton<_ProtocolMode>(
          segments: <ButtonSegment<_ProtocolMode>>[
            ButtonSegment(
              value: _ProtocolMode.standard,
              icon: const Icon(Icons.account_tree_outlined),
              label: Text(l10n.standardProtocol),
            ),
            ButtonSegment(
              value: _ProtocolMode.script,
              icon: const Icon(Icons.code_outlined),
              label: Text(l10n.scriptProtocolMode),
            ),
          ],
          selected: <_ProtocolMode>{_mode},
          onSelectionChanged: (Set<_ProtocolMode> value) {
            final _ProtocolMode mode = value.first;
            setState(() => _mode = mode);
            _updateScript(
              enabled: mode == _ProtocolMode.script && widget.runtimeAvailable,
            );
          },
        ),
        const SizedBox(height: 12),
        _ProtocolModeNote(mode: _mode, l10n: l10n),
        const SizedBox(height: 18),
        if (_mode == _ProtocolMode.standard)
          _StandardProtocolEditor(
            protocol: widget.protocol,
            onProtocolChanged: _updateProtocol,
            l10n: l10n,
          )
        else
          _ScriptProtocolEditor(
            config: widget.scriptConfig,
            beforeSendController: _beforeSendController,
            afterReceiveController: _afterReceiveController,
            runtimeAvailable: widget.runtimeAvailable,
            onChanged: _updateScript,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _ProtocolModeNote extends StatelessWidget {
  const _ProtocolModeNote({required this.mode, required this.l10n});

  final _ProtocolMode mode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool standard = mode == _ProtocolMode.standard;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: standard
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
      ),
      child: Text(
        standard ? l10n.standardProtocolHint : l10n.scriptProtocolHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _StandardProtocolEditor extends StatelessWidget {
  const _StandardProtocolEditor({
    required this.protocol,
    required this.onProtocolChanged,
    required this.l10n,
  });

  final ProtocolDefinition protocol;
  final void Function({
    List<ProtocolSegment>? sendSegments,
    List<ProtocolSegment>? receiveSegments,
  })
  onProtocolChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _InlineProtocolSegmentSection(
          title: l10n.sendFrame,
          segments: protocol.sendSegments,
          l10n: l10n,
          onChanged: (List<ProtocolSegment> value) =>
              onProtocolChanged(sendSegments: value),
        ),
        const Divider(height: 30),
        _InlineProtocolSegmentSection(
          title: l10n.receiveFrame,
          segments: protocol.receiveSegments,
          l10n: l10n,
          onChanged: (List<ProtocolSegment> value) =>
              onProtocolChanged(receiveSegments: value),
        ),
      ],
    );
  }
}

class _ScriptProtocolEditor extends StatelessWidget {
  const _ScriptProtocolEditor({
    required this.config,
    required this.beforeSendController,
    required this.afterReceiveController,
    required this.runtimeAvailable,
    required this.onChanged,
    required this.l10n,
  });

  final ScriptConfig config;
  final TextEditingController beforeSendController;
  final TextEditingController afterReceiveController;
  final bool runtimeAvailable;
  final void Function({bool? enabled}) onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _WorkspaceField(
          label: l10n.scriptRuntime,
          value: runtimeAvailable
              ? l10n.scriptEngineReady
              : l10n.scriptEngineUnavailable,
        ),
        Text(l10n.scriptMethods, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _ScriptMethodContract(
          title: 'beforeSend(context)',
          details: l10n.beforeSendContract,
          signature: 'context.payloadHex -> { frameHex, logs? }',
        ),
        const SizedBox(height: 8),
        _ScriptMethodContract(
          title: 'afterReceive(context)',
          details: l10n.afterReceiveContract,
          signature:
              'context.frameHex -> { payloadHex, cmdHex?, dataHex?, valid?, logs? }',
        ),
        const SizedBox(height: 12),
        _ScriptBuiltinLibrary(l10n: l10n),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () {
              beforeSendController.text = _defaultBeforeSendScript;
              afterReceiveController.text = _defaultAfterReceiveScript;
              onChanged();
            },
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: Text(l10n.loadProtocolSample),
          ),
        ),
        TextField(
          controller: beforeSendController,
          minLines: 16,
          maxLines: 28,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: l10n.beforeSendScript,
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: afterReceiveController,
          minLines: 16,
          maxLines: 28,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: l10n.afterReceiveScript,
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}

class _ScriptMethodContract extends StatelessWidget {
  const _ScriptMethodContract({
    required this.title,
    required this.details,
    required this.signature,
  });

  final String title;
  final String details;
  final String signature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 3),
          Text(details, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Text(
            signature,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _ScriptBuiltinLibrary extends StatelessWidget {
  const _ScriptBuiltinLibrary({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<String> functions = <String>[
      'hexToBytes(value) / bytesToHex(value)',
      'uintToHex(value, byteLength, littleEndian)',
      'xorBytes(value, key)',
      'sum8(value)',
      'crc8(value, polynomial?, initial?)',
      'crc16Modbus(value)',
      'crc16Ccitt(value, initial?)',
      'crc32(value)',
      'md5Hex(value) / md5Text(value)',
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.scriptBuiltins,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.scriptBuiltinsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...functions.map(
            (String function) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                function,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineProtocolSegmentSection extends StatelessWidget {
  const _InlineProtocolSegmentSection({
    required this.title,
    required this.segments,
    required this.l10n,
    required this.onChanged,
  });

  final String title;
  final List<ProtocolSegment> segments;
  final AppLocalizations l10n;
  final ValueChanged<List<ProtocolSegment>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            PopupMenuButton<ProtocolSegmentType>(
              tooltip: l10n.newProtocolSegment,
              icon: const Icon(Icons.add, size: 18),
              onSelected: (ProtocolSegmentType type) {
                onChanged(<ProtocolSegment>[
                  ...segments,
                  _newProtocolSegment(type),
                ]);
              },
              itemBuilder: (BuildContext context) => ProtocolSegmentType.values
                  .map(
                    (ProtocolSegmentType type) =>
                        PopupMenuItem<ProtocolSegmentType>(
                          value: type,
                          child: Text(_segmentTypeLabel(type, l10n)),
                        ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (segments.isEmpty)
          Text(
            l10n.noProtocolSegments,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ...List<Widget>.generate(segments.length, (int index) {
            final ProtocolSegment segment = segments[index];
            return _InlineProtocolSegmentTile(
              segment: segment,
              canMoveUp: index > 0,
              canMoveDown: index < segments.length - 1,
              l10n: l10n,
              onMoveUp: () {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments);
                final ProtocolSegment item = updated.removeAt(index);
                updated.insert(index - 1, item);
                onChanged(updated);
              },
              onMoveDown: () {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments);
                final ProtocolSegment item = updated.removeAt(index);
                updated.insert(index + 1, item);
                onChanged(updated);
              },
              onDelete: () {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments)..removeAt(index);
                onChanged(updated);
              },
              onChanged: (ProtocolSegment updatedSegment) {
                final List<ProtocolSegment> updated =
                    List<ProtocolSegment>.from(segments);
                updated[index] = updatedSegment;
                onChanged(updated);
              },
            );
          }),
      ],
    );
  }
}

class _InlineProtocolSegmentTile extends StatelessWidget {
  const _InlineProtocolSegmentTile({
    required this.segment,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.l10n,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onChanged,
  });

  final ProtocolSegment segment;
  final bool canMoveUp;
  final bool canMoveDown;
  final AppLocalizations l10n;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<ProtocolSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_segmentTypeLabel(segment.type, l10n)),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: segment.label,
                  onChanged: (String value) =>
                      onChanged(segment.copyWith(label: value)),
                  decoration: InputDecoration(
                    labelText: l10n.segmentLabel,
                    isDense: true,
                  ),
                ),
                if (segment.type == ProtocolSegmentType.fixedHex)
                  TextFormField(
                    initialValue: segment.fixedHex,
                    onChanged: (String value) =>
                        onChanged(segment.copyWith(fixedHex: value)),
                    decoration: InputDecoration(
                      labelText: l10n.fixedHexSegment,
                      isDense: true,
                    ),
                  ),
                if (segment.type == ProtocolSegmentType.length ||
                    segment.type == ProtocolSegmentType.sequence)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          initialValue: '${segment.byteLength ?? 1}',
                          keyboardType: TextInputType.number,
                          onChanged: (String value) => onChanged(
                            segment.copyWith(
                              byteLength: int.tryParse(value) ?? 1,
                            ),
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.fieldByteLength,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<ProtocolByteOrder>(
                          initialValue:
                              segment.byteOrder ??
                              ProtocolByteOrder.littleEndian,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: l10n.byteOrder,
                            isDense: true,
                          ),
                          items: ProtocolByteOrder.values
                              .map(
                                (ProtocolByteOrder item) =>
                                    DropdownMenuItem<ProtocolByteOrder>(
                                      value: item,
                                      child: Text(_byteOrderLabel(item, l10n)),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (ProtocolByteOrder? value) {
                            if (value != null) {
                              onChanged(segment.copyWith(byteOrder: value));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                if (segment.type == ProtocolSegmentType.length ||
                    segment.type == ProtocolSegmentType.checksum)
                  DropdownButtonFormField<ProtocolCalculationRange>(
                    initialValue:
                        segment.calculationRange ??
                        ProtocolCalculationRange.payloadOnly,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: l10n.calculationRange,
                      isDense: true,
                    ),
                    items: ProtocolCalculationRange.values
                        .map(
                          (ProtocolCalculationRange item) =>
                              DropdownMenuItem<ProtocolCalculationRange>(
                                value: item,
                                child: Text(_calculationRangeLabel(item, l10n)),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (ProtocolCalculationRange? value) {
                      if (value != null) {
                        onChanged(segment.copyWith(calculationRange: value));
                      }
                    },
                  ),
                if (segment.type == ProtocolSegmentType.checksum) ...<Widget>[
                  DropdownButtonFormField<ProtocolChecksumAlgorithm>(
                    initialValue:
                        segment.checksumAlgorithm ??
                        ProtocolChecksumAlgorithm.crc16Modbus,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: l10n.checksumAlgorithm,
                      isDense: true,
                    ),
                    items: ProtocolChecksumAlgorithm.values
                        .map(
                          (ProtocolChecksumAlgorithm item) =>
                              DropdownMenuItem<ProtocolChecksumAlgorithm>(
                                value: item,
                                child: Text(_checksumLabel(item, l10n)),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (ProtocolChecksumAlgorithm? value) {
                      if (value != null) {
                        onChanged(segment.copyWith(checksumAlgorithm: value));
                      }
                    },
                  ),
                  DropdownButtonFormField<ProtocolByteOrder>(
                    initialValue:
                        segment.byteOrder ?? ProtocolByteOrder.littleEndian,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: l10n.byteOrder,
                      isDense: true,
                    ),
                    items: ProtocolByteOrder.values
                        .map(
                          (ProtocolByteOrder item) =>
                              DropdownMenuItem<ProtocolByteOrder>(
                                value: item,
                                child: Text(_byteOrderLabel(item, l10n)),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (ProtocolByteOrder? value) {
                      if (value != null) {
                        onChanged(segment.copyWith(byteOrder: value));
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.moveUp,
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            tooltip: l10n.moveDown,
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
          IconButton(
            tooltip: l10n.deleteProtocolSegment,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

String _checksumLabel(
  ProtocolChecksumAlgorithm algorithm,
  AppLocalizations l10n,
) => switch (algorithm) {
  ProtocolChecksumAlgorithm.xor => 'XOR',
  ProtocolChecksumAlgorithm.sum8 => 'SUM8',
  ProtocolChecksumAlgorithm.crc8 => 'CRC8',
  ProtocolChecksumAlgorithm.crc16Modbus => 'CRC16-MODBUS',
  ProtocolChecksumAlgorithm.crc16Ccitt => 'CRC16-CCITT',
  ProtocolChecksumAlgorithm.crc32 => 'CRC32',
};

String _byteOrderLabel(ProtocolByteOrder order, AppLocalizations l10n) =>
    order == ProtocolByteOrder.littleEndian ? 'Little-endian' : 'Big-endian';

String _calculationRangeLabel(
  ProtocolCalculationRange range,
  AppLocalizations l10n,
) => range == ProtocolCalculationRange.payloadOnly
    ? l10n.payloadRange
    : l10n.frameExcludingChecksum;

String _segmentTypeLabel(ProtocolSegmentType type, AppLocalizations l10n) =>
    switch (type) {
      ProtocolSegmentType.fixedHex => l10n.fixedHexSegment,
      ProtocolSegmentType.payload => l10n.payloadSegment,
      ProtocolSegmentType.length => l10n.lengthField,
      ProtocolSegmentType.sequence => l10n.sequenceField,
      ProtocolSegmentType.checksum => l10n.checksumField,
    };

ProtocolSegment _newProtocolSegment(ProtocolSegmentType type) {
  final String id = 'segment-${DateTime.now().microsecondsSinceEpoch}';
  return ProtocolSegment(
    id: id,
    type: type,
    label: '',
    byteLength:
        type == ProtocolSegmentType.length ||
            type == ProtocolSegmentType.sequence
        ? 1
        : null,
    byteOrder:
        type == ProtocolSegmentType.length ||
            type == ProtocolSegmentType.sequence ||
            type == ProtocolSegmentType.checksum
        ? ProtocolByteOrder.littleEndian
        : null,
    fixedHex: type == ProtocolSegmentType.fixedHex ? '00' : '',
    checksumAlgorithm: type == ProtocolSegmentType.checksum
        ? ProtocolChecksumAlgorithm.crc16Modbus
        : null,
    calculationRange:
        type == ProtocolSegmentType.length ||
            type == ProtocolSegmentType.checksum
        ? ProtocolCalculationRange.payloadOnly
        : null,
  );
}

class _CommandLibraryPanel extends StatelessWidget {
  const _CommandLibraryPanel({
    required this.commands,
    required this.allowedCommandIds,
    required this.onNewCommand,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onEnabledChanged,
    required this.onQuickAccessChanged,
    required this.onWhitelistChanged,
    required this.l10n,
  });

  final List<CommandDefinition> commands;
  final List<String> allowedCommandIds;
  final VoidCallback onNewCommand;
  final ValueChanged<CommandDefinition> onEditCommand;
  final ValueChanged<CommandDefinition> onDeleteCommand;
  final void Function(CommandDefinition, bool) onEnabledChanged;
  final void Function(CommandDefinition, bool) onQuickAccessChanged;
  final ValueChanged<List<String>> onWhitelistChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool whitelistEnabled = allowedCommandIds.isNotEmpty;
    final Map<String, List<CommandDefinition>> byGroup =
        <String, List<CommandDefinition>>{};
    for (final CommandDefinition command in commands) {
      byGroup
          .putIfAbsent(command.group.isEmpty ? '-' : command.group, () {
            return <CommandDefinition>[];
          })
          .add(command);
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.commandLibrary,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l10n.newCommand,
              onPressed: onNewCommand,
              icon: const Icon(Icons.add, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('仅允许已选指令发送'),
          subtitle: Text(
            whitelistEnabled
                ? '当前允许 ${allowedCommandIds.length} 条指令；手动控制台发送不受影响。'
                : '关闭时所有已启用指令都可发送；手动控制台发送不受影响。',
          ),
          value: whitelistEnabled,
          onChanged: commands.isEmpty
              ? null
              : (bool enabled) async {
                  if (!enabled) {
                    onWhitelistChanged(const <String>[]);
                    return;
                  }
                  final List<String>? selected = await _selectWhitelist(
                    context,
                    commands,
                    allowedCommandIds,
                  );
                  if (selected != null && selected.isNotEmpty) {
                    onWhitelistChanged(selected);
                  }
                },
        ),
        const SizedBox(height: 12),
        if (commands.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text(l10n.noCommands)),
          )
        else
          ...byGroup.entries.expand(
            (MapEntry<String, List<CommandDefinition>> entry) => <Widget>[
              if (entry.key != '-') ...<Widget>[
                const Divider(height: 24),
                Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
              ],
              ...entry.value.map(
                (CommandDefinition command) => _CommandLibraryTile(
                  command: command,
                  onEdit: () => onEditCommand(command),
                  onDelete: () => onDeleteCommand(command),
                  onEnabledChanged: (bool value) =>
                      onEnabledChanged(command, value),
                  onQuickAccessChanged: (bool value) =>
                      onQuickAccessChanged(command, value),
                  l10n: l10n,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<List<String>?> _selectWhitelist(
    BuildContext context,
    List<CommandDefinition> commands,
    List<String> currentIds,
  ) async {
    final Set<String> selectedIds = currentIds.isEmpty
        ? commands.map((CommandDefinition command) => command.id).toSet()
        : currentIds.toSet();
    return showToolDialog<List<String>>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            ToolAlertDialog(
              icon: Icons.verified_user_outlined,
              title: '选择允许发送的指令',
              content: SizedBox(
                width: 440,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('未选中的可复用指令将被拒绝，手动控制台发送不受影响。'),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: <Widget>[
                            for (final CommandDefinition command in commands)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(command.name),
                                subtitle: Text(
                                  command.group.isEmpty
                                      ? command.payload
                                      : command.group,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                value: selectedIds.contains(command.id),
                                onChanged: (bool? value) => setDialogState(() {
                                  if (value ?? false) {
                                    selectedIds.add(command.id);
                                  } else {
                                    selectedIds.remove(command.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          selectedIds.toList(growable: false),
                        ),
                  child: const Text('保存'),
                ),
              ],
            ),
      ),
    );
  }
}

class _CommandLibraryTile extends StatelessWidget {
  const _CommandLibraryTile({
    required this.command,
    required this.onEdit,
    required this.onDelete,
    required this.onEnabledChanged,
    required this.onQuickAccessChanged,
    required this.l10n,
  });

  final CommandDefinition command;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onQuickAccessChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(command.name),
                  const SizedBox(height: 3),
                  Text(
                    command.payload,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  if (command.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        command.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Tooltip(
            message: l10n.commandEnabled,
            child: Switch.adaptive(
              value: command.enabled,
              onChanged: onEnabledChanged,
            ),
          ),
          Tooltip(
            message: l10n.quickAccess,
            child: Checkbox(
              value: command.isQuickAccess,
              onChanged: (bool? value) => onQuickAccessChanged(value ?? false),
            ),
          ),
          IconButton(
            tooltip: l10n.editCommand,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: l10n.deleteCommand,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DataMappingLibraryPanel extends StatelessWidget {
  const _DataMappingLibraryPanel({
    required this.mappings,
    required this.onNew,
    required this.onEdit,
    required this.onDelete,
    required this.l10n,
  });

  final List<ResponseMapping> mappings;
  final VoidCallback onNew;
  final ValueChanged<ResponseMapping> onEdit;
  final ValueChanged<ResponseMapping> onDelete;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.dataMappings,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: l10n.addResponseMapping,
            onPressed: onNew,
            icon: const Icon(Icons.add, size: 19),
          ),
        ],
      ),
      Padding(
        padding: EdgeInsets.only(top: 4, bottom: 12),
        child: Text(l10n.dataMappingHint),
      ),
      if (mappings.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: Text(l10n.noResponseMappings)),
        )
      else
        ...mappings.map(
          (ResponseMapping mapping) => Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: () => onEdit(mapping),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(mapping.name),
                        const SizedBox(height: 3),
                        Text(
                          l10n.mappingFieldCount(
                            mapping.commandHex,
                            mapping.fields.length,
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.editResponseMapping,
                  onPressed: () => onEdit(mapping),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: l10n.deleteResponseMapping,
                  onPressed: () => onDelete(mapping),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _CommandParameterEditor extends StatelessWidget {
  const _CommandParameterEditor({
    required this.parameter,
    required this.onChanged,
    required this.onDelete,
  });
  final CommandParameter parameter;
  final ValueChanged<CommandParameter> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                initialValue: parameter.key,
                decoration: const InputDecoration(
                  labelText: 'key',
                  isDense: true,
                ),
                onChanged: (String value) =>
                    onChanged(parameter.copyWith(key: value.trim())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: parameter.label,
                decoration: const InputDecoration(
                  labelText: '名称',
                  isDense: true,
                ),
                onChanged: (String value) =>
                    onChanged(parameter.copyWith(label: value)),
              ),
            ),
            IconButton(
              tooltip: '删除参数',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<CommandParameterType>(
                initialValue: parameter.type,
                decoration: const InputDecoration(
                  labelText: '类型',
                  isDense: true,
                ),
                items: CommandParameterType.values
                    .map(
                      (CommandParameterType item) => DropdownMenuItem(
                        value: item,
                        child: Text(_commandParameterTypeLabel(item)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (CommandParameterType? value) {
                  if (value != null) onChanged(parameter.copyWith(type: value));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: parameter.defaultValue,
                decoration: const InputDecoration(
                  labelText: '默认值',
                  isDense: true,
                ),
                onChanged: (String value) =>
                    onChanged(parameter.copyWith(defaultValue: value)),
              ),
            ),
          ],
        ),
        if (parameter.type == CommandParameterType.enumValue) ...<Widget>[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: parameter.options
                .map(
                  (CommandParameterOption option) =>
                      '${option.label}=${option.value}',
                )
                .join(', '),
            decoration: const InputDecoration(
              labelText: '枚举选项',
              helperText: '名称=数值，多个选项以逗号分隔',
              isDense: true,
            ),
            onChanged: (String value) => onChanged(
              parameter.copyWith(options: _parseParameterOptions(value)),
            ),
          ),
        ],
      ],
    ),
  );
}

class _MappingFieldEditor extends StatelessWidget {
  const _MappingFieldEditor({
    required this.field,
    required this.onChanged,
    required this.onDelete,
  });
  final DataField field;
  final ValueChanged<DataField> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool isNumeric = switch (field.type) {
      DataFieldType.uint8 ||
      DataFieldType.int8 ||
      DataFieldType.uint16 ||
      DataFieldType.int16 ||
      DataFieldType.uint32 ||
      DataFieldType.int32 => true,
      _ => false,
    };
    final bool needsByteOrder = switch (field.type) {
      DataFieldType.uint16 ||
      DataFieldType.int16 ||
      DataFieldType.uint32 ||
      DataFieldType.int32 => true,
      _ => false,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  initialValue: field.key,
                  decoration: const InputDecoration(
                    labelText: 'key',
                    isDense: true,
                  ),
                  onChanged: (String value) =>
                      onChanged(field.copyWith(key: value.trim())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: field.label,
                  decoration: InputDecoration(
                    labelText: l10n.fieldLabel,
                    isDense: true,
                  ),
                  onChanged: (String value) =>
                      onChanged(field.copyWith(label: value)),
                ),
              ),
              IconButton(
                tooltip: l10n.deleteDataField,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  initialValue: field.offset.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.dataOffset,
                    isDense: true,
                  ),
                  onChanged: (String value) => onChanged(
                    field.copyWith(offset: int.tryParse(value) ?? 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: field.byteLength.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.fieldByteLength,
                    isDense: true,
                  ),
                  onChanged: (String value) => onChanged(
                    field.copyWith(byteLength: int.tryParse(value) ?? 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<DataFieldType>(
                  initialValue: field.type,
                  decoration: InputDecoration(
                    labelText: l10n.dataFieldType,
                    isDense: true,
                  ),
                  items: DataFieldType.values
                      .map(
                        (DataFieldType item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (DataFieldType? value) {
                    if (value != null) onChanged(field.copyWith(type: value));
                  },
                ),
              ),
            ],
          ),
          if (isNumeric) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    initialValue: field.scale.toString(),
                    decoration: InputDecoration(
                      labelText: l10n.numericScale,
                      isDense: true,
                    ),
                    onChanged: (String value) => onChanged(
                      field.copyWith(scale: double.tryParse(value) ?? 1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: field.offsetValue.toString(),
                    decoration: InputDecoration(
                      labelText: l10n.numericOffset,
                      isDense: true,
                    ),
                    onChanged: (String value) => onChanged(
                      field.copyWith(offsetValue: double.tryParse(value) ?? 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: field.unit,
                    decoration: InputDecoration(
                      labelText: l10n.unit,
                      isDense: true,
                    ),
                    onChanged: (String value) =>
                        onChanged(field.copyWith(unit: value)),
                  ),
                ),
              ],
            ),
          ],
          if (needsByteOrder) ...<Widget>[
            const SizedBox(height: 8),
            DropdownButtonFormField<ProtocolByteOrder>(
              initialValue: field.byteOrder,
              decoration: InputDecoration(
                labelText: l10n.byteOrder,
                isDense: true,
              ),
              items: ProtocolByteOrder.values
                  .map(
                    (ProtocolByteOrder item) => DropdownMenuItem(
                      value: item,
                      child: Text(_byteOrderLabel(item, l10n)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (ProtocolByteOrder? value) {
                if (value != null) onChanged(field.copyWith(byteOrder: value));
              },
            ),
          ],
          if (field.type == DataFieldType.bit ||
              field.type == DataFieldType.enumValue) ...<Widget>[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: field.type == DataFieldType.bit
                  ? (field.bit ?? 0).toString()
                  : field.enumValues.entries
                        .map(
                          (MapEntry<String, String> item) =>
                              '${item.key}=${item.value}',
                        )
                        .join(', '),
              decoration: InputDecoration(
                labelText: field.type == DataFieldType.bit
                    ? l10n.bitNumber
                    : l10n.enumValues,
                helperText: field.type == DataFieldType.bit
                    ? l10n.bitNumberHint
                    : l10n.enumValuesHint,
                isDense: true,
              ),
              onChanged: (String value) => onChanged(
                field.type == DataFieldType.bit
                    ? field.copyWith(bit: int.tryParse(value) ?? 0)
                    : field.copyWith(enumValues: _parseEnumValues(value)),
              ),
            ),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.showInDataPanel),
            value: field.visibleInDataPanel,
            onChanged: (bool value) =>
                onChanged(field.copyWith(visibleInDataPanel: value)),
          ),
        ],
      ),
    );
  }
}

List<CommandParameterOption> _parseParameterOptions(String value) => value
    .split(',')
    .map((String item) => item.trim().split('='))
    .where((List<String> pair) => pair.length == 2 && pair[0].trim().isNotEmpty)
    .map(
      (List<String> pair) =>
          CommandParameterOption(label: pair[0].trim(), value: pair[1].trim()),
    )
    .toList(growable: false);

Map<String, String> _parseEnumValues(String value) => <String, String>{
  for (final List<String> pair
      in value.split(',').map((String item) => item.trim().split('=')))
    if (pair.length == 2 && pair[0].trim().isNotEmpty)
      pair[0].trim(): pair[1].trim(),
};

CommandParameter _newCommandParameter() => const CommandParameter(
  key: 'value',
  label: '参数',
  type: CommandParameterType.uint8,
  defaultValue: '0',
  min: null,
  max: null,
  options: <CommandParameterOption>[],
);

DataField _newDataField(int index) => DataField(
  key: 'field$index',
  label: '字段 $index',
  offset: index,
  byteLength: 1,
  type: DataFieldType.uint8,
  byteOrder: ProtocolByteOrder.littleEndian,
  scale: 1,
  offsetValue: 0,
  unit: '',
  bit: null,
  enumValues: const <String, String>{},
);

String _commandParameterTypeLabel(CommandParameterType type) => switch (type) {
  CommandParameterType.uint8 => 'uint8',
  CommandParameterType.int8 => 'int8',
  CommandParameterType.uint16 => 'uint16',
  CommandParameterType.int16 => 'int16',
  CommandParameterType.uint32 => 'uint32',
  CommandParameterType.int32 => 'int32',
  CommandParameterType.hex => 'HEX',
  CommandParameterType.ascii => 'ASCII',
  CommandParameterType.utf8 => 'UTF-8',
  CommandParameterType.boolean => 'Boolean',
  CommandParameterType.enumValue => 'Enum',
  CommandParameterType.currentYear => '当前年（2 位）',
  CommandParameterType.currentMonth => '当前月',
  CommandParameterType.currentDay => '当前日',
  CommandParameterType.currentHour => '当前时',
  CommandParameterType.currentMinute => '当前分',
  CommandParameterType.currentSecond => '当前秒',
};

class _ConsoleSendPreview {
  const _ConsoleSendPreview({
    this.payloadLength,
    this.finalFrame,
    this.error,
    this.scriptPending = false,
  });

  final int? payloadLength;
  final List<int>? finalFrame;
  final String? error;
  final bool scriptPending;
}

class _ConsoleLogView extends StatefulWidget {
  const _ConsoleLogView({
    required this.logs,
    required this.autoScroll,
    required this.selectedLog,
    required this.onLogSelected,
    required this.onJumpToLatest,
    required this.l10n,
  });

  final List<SessionLogRecord> logs;
  final bool autoScroll;
  final SessionLogRecord? selectedLog;
  final ValueChanged<SessionLogRecord> onLogSelected;
  final VoidCallback onJumpToLatest;
  final AppLocalizations l10n;

  @override
  State<_ConsoleLogView> createState() => _ConsoleLogViewState();
}

class _ConsoleLogViewState extends State<_ConsoleLogView> {
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToLatest = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final bool shouldShow =
        _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels >
        32;
    if (shouldShow != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShow);
    }
  }

  @override
  void didUpdateWidget(covariant _ConsoleLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  void _scrollToLatest() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        Container(
          color: dark
              ? const Color(0xFF0A111B)
              : Theme.of(context).colorScheme.surface,
          child: widget.logs.isEmpty
              ? Center(child: Text(widget.l10n.noMatchingLogs))
              : ListView.builder(
                  key: const ValueKey<String>('console-log-list'),
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.all(14),
                  itemCount: widget.logs.length,
                  itemBuilder: (_, index) {
                    final SessionLogRecord entry =
                        widget.logs[widget.logs.length - index - 1];
                    return _LogLine(
                      entry: entry,
                      l10n: widget.l10n,
                      selected: identical(entry, widget.selectedLog),
                      onTap: () => widget.onLogSelected(entry),
                    );
                  },
                ),
        ),
        if (_showJumpToLatest)
          Positioned(
            right: 16,
            bottom: 16,
            child: Tooltip(
              message: widget.l10n.backToLatest,
              child: IconButton.filledTonal(
                key: const ValueKey<String>('console-jump-latest'),
                onPressed: () {
                  widget.onJumpToLatest();
                  _scrollToLatest();
                },
                icon: const Icon(Icons.vertical_align_bottom, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConsoleArea extends StatelessWidget {
  const _ConsoleArea({
    required this.logs,
    required this.discardedLogCount,
    required this.autoScroll,
    required this.onClear,
    required this.onAutoScrollChanged,
    required this.inputController,
    required this.searchController,
    required this.inputFocusNode,
    required this.hexMode,
    required this.onModeChanged,
    required this.onSend,
    required this.canSend,
    required this.sendDisabledReason,
    required this.sendPreview,
    required this.writeTarget,
    required this.l10n,
    required this.selectedLog,
    required this.onLogSelected,
    required this.logFilter,
    required this.onLogFilterChanged,
    required this.onSearchChanged,
    required this.onExport,
  });
  final List<SessionLogRecord> logs;
  final int discardedLogCount;
  final bool autoScroll;
  final VoidCallback onClear;
  final ValueChanged<bool> onAutoScrollChanged;
  final TextEditingController inputController;
  final TextEditingController searchController;
  final FocusNode inputFocusNode;
  final bool hexMode;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSend;
  final bool canSend;
  final String? sendDisabledReason;
  final _ConsoleSendPreview Function(String input, bool hexMode) sendPreview;
  final String? writeTarget;
  final AppLocalizations l10n;
  final SessionLogRecord? selectedLog;
  final ValueChanged<SessionLogRecord> onLogSelected;
  final _ConsoleLogFilter logFilter;
  final ValueChanged<_ConsoleLogFilter> onLogFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<List<SessionLogRecord>> onExport;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bool compactHeader = MediaQuery.sizeOf(context).width < 680;
    return Column(
      children: <Widget>[
        Container(
          height: 42,
          // Reserve space for the floating Inspector control at the top-right.
          padding: EdgeInsets.fromLTRB(12, 0, compactHeader ? 12 : 60, 0),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF101824) : colors.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.terminal_rounded, size: 18, color: colors.secondary),
              const SizedBox(width: 8),
              Text(
                l10n.console,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _ConsoleLogFilterBar(
                filter: logFilter,
                onChanged: onLogFilterChanged,
                l10n: l10n,
              ),
              const SizedBox(width: 2),
              if (!compactHeader) ...<Widget>[
                Flexible(
                  child: Text(
                    l10n.retainedLogs(logs.length, discardedLogCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  writeTarget == null
                      ? Icons.warning_amber_outlined
                      : Icons.output_outlined,
                  size: 15,
                  color: writeTarget == null ? colors.error : colors.tertiary,
                ),
                const SizedBox(width: 5),
                Text(
                  writeTarget == null
                      ? '未选择写入特征'
                      : '写入  ${_shortUuid(writeTarget!)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: writeTarget == null
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
              const Spacer(),
              Tooltip(
                message: l10n.autoScroll,
                child: Switch.adaptive(
                  value: autoScroll,
                  onChanged: onAutoScrollChanged,
                ),
              ),
              if (!compactHeader) ...<Widget>[
                Text(
                  l10n.autoScroll,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                tooltip: l10n.exportLogs,
                onPressed: logs.isEmpty ? null : () => onExport(logs),
                icon: const Icon(Icons.download_outlined, size: 19),
              ),
              IconButton(
                tooltip: l10n.clear,
                onPressed: onClear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 19),
              ),
            ],
          ),
        ),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF101824) : colors.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: TextField(
            key: const ValueKey<String>('console-search'),
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: l10n.searchLogs,
              prefixIcon: const Icon(Icons.search, size: 17),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.clear,
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close, size: 16),
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: _ConsoleLogView(
            logs: logs,
            autoScroll: autoScroll,
            selectedLog: selectedLog,
            onLogSelected: onLogSelected,
            onJumpToLatest: () => onAutoScrollChanged(true),
            l10n: l10n,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: inputController,
          builder: (BuildContext context, TextEditingValue input, _) {
            final _ConsoleSendPreview preview = sendPreview(
              input.text,
              hexMode,
            );
            final String? inputReason =
                preview.error ??
                (input.text.trim().isEmpty ? l10n.emptyInput : null);
            final String? disabledReason = sendDisabledReason ?? inputReason;
            final bool effectiveCanSend = canSend && inputReason == null;
            return Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF101824) : colors.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const ValueKey<String>('console-input'),
                          controller: inputController,
                          focusNode: inputFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => onSend(),
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: l10n.inputPlaceholder,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: FilledButton.icon(
                          key: const ValueKey<String>('console-send-button'),
                          onPressed: effectiveCanSend ? onSend : null,
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: Text(l10n.sendData),
                        ),
                      ),
                    ],
                  ),
                  if (disabledReason != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Semantics(
                      liveRegion: true,
                      container: true,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.info_outline,
                              size: 15,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                l10n.sendUnavailable(disabledReason),
                                key: const ValueKey<String>(
                                  'console-send-disabled-reason',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (preview.error == null &&
                      preview.payloadLength != null) ...<Widget>[
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 3,
                        children: <Widget>[
                          Text(
                            l10n.payloadLength(preview.payloadLength!),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            preview.scriptPending
                                ? l10n.scriptPreviewUnavailable
                                : l10n.finalFramePreview(
                                    preview.finalFrame!.length,
                                    _toHex(preview.finalFrame!),
                                  ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      SegmentedButton<bool>(
                        key: const ValueKey<String>('console-mode-toggle'),
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const WidgetStatePropertyAll<Size>(
                            Size(0, 36),
                          ),
                          padding: const WidgetStatePropertyAll<EdgeInsets>(
                            EdgeInsets.symmetric(horizontal: 10),
                          ),
                          shape: WidgetStatePropertyAll<OutlinedBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          side: WidgetStatePropertyAll<BorderSide>(
                            BorderSide(color: colors.outlineVariant),
                          ),
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color?>((states) {
                                return states.contains(WidgetState.selected)
                                    ? colors.secondaryContainer
                                    : colors.surface;
                              }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith<Color?>((states) {
                                return states.contains(WidgetState.selected)
                                    ? colors.onSecondaryContainer
                                    : colors.onSurfaceVariant;
                              }),
                        ),
                        segments: <ButtonSegment<bool>>[
                          ButtonSegment(value: true, label: Text(l10n.hexMode)),
                          ButtonSegment(
                            value: false,
                            label: Text(l10n.textMode),
                          ),
                        ],
                        selected: <bool>{hexMode},
                        onSelectionChanged: (Set<bool> value) =>
                            onModeChanged(value.first),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.lineEnding,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        key: const ValueKey<String>('console-line-ending'),
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButton<String>(
                          value: 'none',
                          isDense: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          borderRadius: BorderRadius.circular(6),
                          underline: const SizedBox(),
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'none',
                              child: Text(l10n.none),
                            ),
                            DropdownMenuItem(value: 'lf', child: Text(l10n.lf)),
                            DropdownMenuItem(
                              value: 'crlf',
                              child: Text(l10n.crlf),
                            ),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

String _serviceTitle(String serviceId, AppLocalizations l10n) {
  return switch (serviceId.toLowerCase()) {
    '00001800-0000-1000-8000-00805f9b34fb' =>
      '${l10n.genericAccess}  $serviceId',
    '00001801-0000-1000-8000-00805f9b34fb' =>
      '${l10n.genericAttribute}  $serviceId',
    _ => '${l10n.service} $serviceId',
  };
}

String? _characteristicTitle(String characteristicId, AppLocalizations l10n) {
  return switch (characteristicId.toLowerCase()) {
    '00002a00-0000-1000-8000-00805f9b34fb' => l10n.deviceName,
    '00002a05-0000-1000-8000-00805f9b34fb' => l10n.serviceChanged,
    _ => null,
  };
}

class _DeviceToolsPanel extends StatefulWidget {
  const _DeviceToolsPanel({
    required this.characteristics,
    required this.connected,
    required this.safetyPolicy,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onRead,
    required this.onEditSafetyPolicy,
    required this.l10n,
  });

  final List<BluetoothCharacteristicInfo> characteristics;
  final bool connected;
  final DeviceSafetyPolicy safetyPolicy;
  final Future<void> Function(BluetoothCharacteristicInfo) onSelectWrite;
  final Future<void> Function(
    BluetoothCharacteristicInfo,
    BluetoothSubscriptionMode,
    bool,
  )
  onSubscriptionChanged;
  final Future<void> Function(BluetoothCharacteristicInfo) onRead;
  final VoidCallback onEditSafetyPolicy;
  final AppLocalizations l10n;

  @override
  State<_DeviceToolsPanel> createState() => _DeviceToolsPanelState();
}

class _DeviceToolsPanelState extends State<_DeviceToolsPanel> {
  final TextEditingController _filterController = TextEditingController();
  bool _operableOnly = false;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dense = MediaQuery.sizeOf(context).width >= 680;
    final List<BluetoothCharacteristicInfo> filteredCharacteristics =
        _filteredCharacteristics(widget.characteristics, widget.l10n);
    final Map<String, List<BluetoothCharacteristicInfo>> byService =
        <String, List<BluetoothCharacteristicInfo>>{};
    for (final BluetoothCharacteristicInfo characteristic
        in filteredCharacteristics) {
      byService
          .putIfAbsent(
            characteristic.serviceId,
            () => <BluetoothCharacteristicInfo>[],
          )
          .add(characteristic);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.l10n.characteristics,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.connected
                    ? widget.l10n.connected
                    : widget.l10n.disconnected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Tooltip(
                message: '设备发送策略',
                child: shad.IconButton.ghost(
                  icon: Icon(
                    widget.safetyPolicy.allowedWriteTargetKeys.isNotEmpty ||
                            widget.safetyPolicy.maxFinalFrameBytes != null ||
                            widget.safetyPolicy.requireWriteWithResponse
                        ? Icons.shield
                        : Icons.shield_outlined,
                    size: 19,
                  ),
                  size: dense ? shad.ButtonSize.small : shad.ButtonSize.normal,
                  onPressed:
                      widget.connected && widget.characteristics.isNotEmpty
                      ? widget.onEditSafetyPolicy
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!widget.connected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(widget.l10n.connectToDiscoverCharacteristics),
            )
          else if (widget.characteristics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(widget.l10n.noCharacteristics),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('characteristic-filter'),
                    controller: _filterController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: widget.l10n.filterCharacteristics,
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: widget.l10n.operableOnly,
                  child: shad.SelectedButton(
                    key: const ValueKey<String>(
                      'operable-characteristics-filter',
                    ),
                    value: _operableOnly,
                    style: dense
                        ? const shad.ButtonStyle.ghost(
                            size: shad.ButtonSize.small,
                            density: shad.ButtonDensity.dense,
                          )
                        : const shad.ButtonStyle.ghost(),
                    selectedStyle: dense
                        ? const shad.ButtonStyle.secondary(
                            size: shad.ButtonSize.small,
                            density: shad.ButtonDensity.dense,
                          )
                        : const shad.ButtonStyle.secondary(),
                    onChanged: (bool value) =>
                        setState(() => _operableOnly = value),
                    child: const Text('R/W'),
                  ),
                ),
              ],
            ),
            if (filteredCharacteristics.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(widget.l10n.noMatchingCharacteristics),
              )
            else
              ...byService.entries.expand(
                (
                  MapEntry<String, List<BluetoothCharacteristicInfo>> entry,
                ) => <Widget>[
                  _ServiceTreeHeader(
                    serviceId: entry.key,
                    title: _serviceTitle(entry.key, widget.l10n),
                  ),
                  ...entry.value.map(
                    (BluetoothCharacteristicInfo characteristic) =>
                        _CharacteristicTile(
                          characteristic: characteristic,
                          onSelectWrite: widget.onSelectWrite,
                          onSubscriptionChanged: widget.onSubscriptionChanged,
                          onRead: widget.onRead,
                          l10n: widget.l10n,
                        ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  List<BluetoothCharacteristicInfo> _filteredCharacteristics(
    List<BluetoothCharacteristicInfo> source,
    AppLocalizations l10n,
  ) {
    final String query = _filterController.text.trim().toLowerCase();
    return source
        .where((BluetoothCharacteristicInfo characteristic) {
          final bool operable =
              characteristic.canRead ||
              characteristic.canWrite ||
              characteristic.canWriteWithoutResponse;
          if (_operableOnly && !operable) return false;
          if (query.isEmpty) return true;
          final String title =
              _characteristicTitle(characteristic.characteristicId, l10n) ?? '';
          return <String>[
            characteristic.serviceId,
            characteristic.characteristicId,
            title,
          ].any((String value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);
  }
}

class _ServiceTreeHeader extends StatelessWidget {
  const _ServiceTreeHeader({required this.serviceId, required this.title});

  final String serviceId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_tree_outlined,
            size: 15,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCommandsPanel extends StatelessWidget {
  const _QuickCommandsPanel({
    required this.canSend,
    required this.onSend,
    required this.commands,
    required this.l10n,
  });

  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>) onSend;
  final List<CommandDefinition> commands;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<CommandDefinition> quickCommands = commands
        .where(
          (CommandDefinition command) =>
              command.enabled && command.isQuickAccess,
        )
        .toList(growable: false);
    final Map<String, List<CommandDefinition>> byGroup =
        <String, List<CommandDefinition>>{};
    for (final CommandDefinition command in quickCommands) {
      byGroup
          .putIfAbsent(command.group.isEmpty ? '-' : command.group, () {
            return <CommandDefinition>[];
          })
          .add(command);
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.quickCommands,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (quickCommands.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text(l10n.noQuickCommands)),
          )
        else
          ...byGroup.entries.expand(
            (MapEntry<String, List<CommandDefinition>> entry) => <Widget>[
              if (entry.key != '-') ...<Widget>[
                const Divider(height: 24),
                Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
              ],
              ...entry.value.map(
                (CommandDefinition command) => _CommandTile(
                  command: command,
                  canSend: canSend,
                  onSend: onSend,
                  l10n: l10n,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CommandTile extends StatefulWidget {
  const _CommandTile({
    required this.command,
    required this.canSend,
    required this.onSend,
    required this.l10n,
  });

  final CommandDefinition command;
  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>) onSend;
  final AppLocalizations l10n;

  @override
  State<_CommandTile> createState() => _CommandTileState();
}

class _CommandTileState extends State<_CommandTile> {
  late final Map<String, TextEditingController> _controllers;
  late final ScrollController _frameScrollController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _frameScrollController = ScrollController();
    _controllers = <String, TextEditingController>{
      for (final CommandParameter parameter in widget.command.parameters)
        parameter.key: TextEditingController(text: parameter.defaultValue),
    };
  }

  @override
  void didUpdateWidget(covariant _CommandTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command.id == widget.command.id &&
        oldWidget.command.parameters == widget.command.parameters) {
      return;
    }
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    _controllers
      ..clear()
      ..addEntries(
        widget.command.parameters.map(
          (CommandParameter parameter) =>
              MapEntry<String, TextEditingController>(
                parameter.key,
                TextEditingController(text: parameter.defaultValue),
              ),
        ),
      );
    _validationError = null;
  }

  @override
  void dispose() {
    _frameScrollController.dispose();
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final Map<String, String> values = <String, String>{
      for (final MapEntry<String, TextEditingController> entry
          in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    try {
      CommandPayloadEncoder.encode(widget.command, values);
      setState(() => _validationError = null);
      await widget.onSend(widget.command, values);
    } on FormatException catch (error) {
      if (mounted) setState(() => _validationError = error.message);
    } catch (error) {
      if (mounted) setState(() => _validationError = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final CommandDefinition command = widget.command;
    final bool sendEnabled = widget.canSend && command.enabled;
    final bool hasParameters = command.parameters.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Semantics(
        label: '${command.name}：${command.payload}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Scrollbar(
                    controller: _frameScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _frameScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildFrameCells(
                          command,
                          showParameterLabels: hasParameters,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: '${widget.l10n.sendCommand} ${command.name}',
                  onPressed: sendEnabled ? _send : null,
                  icon: const Icon(Icons.send_outlined, size: 18),
                ),
              ],
            ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _validationError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFrameCells(
    CommandDefinition command, {
    required bool showParameterLabels,
  }) {
    if (command.format == CommandPayloadFormat.text) {
      return <Widget>[
        _RawFrameCell(
          value: command.payload,
          showParameterLabelSpace: showParameterLabels,
        ),
      ];
    }
    final Map<String, CommandParameter> parameters = <String, CommandParameter>{
      for (final CommandParameter parameter in command.parameters)
        parameter.key: parameter,
    };
    final RegExp placeholder = RegExp(
      r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}',
    );
    final List<Widget> cells = <Widget>[];
    int position = 0;
    for (final RegExpMatch match in placeholder.allMatches(command.payload)) {
      cells.addAll(
        _fixedHexCells(
          command.payload.substring(position, match.start),
          showParameterLabelSpace: showParameterLabels,
        ),
      );
      final CommandParameter? parameter = parameters[match.group(1)!];
      if (parameter != null) cells.add(_buildParameterInput(parameter));
      position = match.end;
    }
    cells.addAll(
      _fixedHexCells(
        command.payload.substring(position),
        showParameterLabelSpace: showParameterLabels,
      ),
    );
    return cells.isEmpty
        ? <Widget>[
            _RawFrameCell(
              value: command.payload,
              showParameterLabelSpace: showParameterLabels,
            ),
          ]
        : cells;
  }

  List<Widget> _fixedHexCells(
    String source, {
    required bool showParameterLabelSpace,
  }) {
    final String compact = source.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    return <Widget>[
      for (int index = 0; index + 1 < compact.length; index += 2)
        _FixedFrameCell(
          value: compact.substring(index, index + 2).toUpperCase(),
          showParameterLabelSpace: showParameterLabelSpace,
        ),
    ];
  }

  Widget _buildParameterInput(CommandParameter parameter) {
    final String label = parameter.label.isEmpty
        ? parameter.key
        : parameter.label;
    final bool isChoice =
        parameter.type == CommandParameterType.enumValue &&
        parameter.options.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: isChoice ? 76 : _parameterInputWidth(parameter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Tooltip(
              message: label,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            const SizedBox(height: 2),
            if (isChoice)
              DropdownButtonFormField<String>(
                initialValue:
                    parameter.options.any(
                      (CommandParameterOption option) =>
                          option.value == _controllers[parameter.key]!.text,
                    )
                    ? _controllers[parameter.key]!.text
                    : null,
                isDense: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                ),
                items: parameter.options
                    .map(
                      (CommandParameterOption option) =>
                          DropdownMenuItem<String>(
                            value: option.value,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value != null) _controllers[parameter.key]!.text = value;
                },
              )
            else
              Semantics(
                label: label,
                textField: true,
                child: TextField(
                  controller: _controllers[parameter.key],
                  keyboardType: _usesNumericKeyboard(parameter.type)
                      ? TextInputType.number
                      : TextInputType.text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _parameterInputWidth(CommandParameter parameter) =>
      switch (parameter.type) {
        CommandParameterType.uint32 || CommandParameterType.int32 => 62,
        CommandParameterType.uint16 || CommandParameterType.int16 => 52,
        CommandParameterType.ascii || CommandParameterType.utf8 => 88,
        CommandParameterType.hex => 52,
        _ => 38,
      };
}

class _FixedFrameCell extends StatelessWidget {
  const _FixedFrameCell({
    required this.value,
    required this.showParameterLabelSpace,
  });

  final String value;
  final bool showParameterLabelSpace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showParameterLabelSpace) ...<Widget>[
              const SizedBox(height: 16),
              const SizedBox(height: 2),
            ],
            SizedBox(
              height: 38,
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawFrameCell extends StatelessWidget {
  const _RawFrameCell({
    required this.value,
    required this.showParameterLabelSpace,
  });

  final String value;
  final bool showParameterLabelSpace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showParameterLabelSpace) ...<Widget>[
          const SizedBox(height: 16),
          const SizedBox(height: 2),
        ],
        SizedBox(
          height: 38,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _usesNumericKeyboard(CommandParameterType type) => switch (type) {
  CommandParameterType.uint8 ||
  CommandParameterType.int8 ||
  CommandParameterType.uint16 ||
  CommandParameterType.int16 ||
  CommandParameterType.uint32 ||
  CommandParameterType.int32 => true,
  _ => false,
};

class _MonitoredFieldDefinition {
  const _MonitoredFieldDefinition({required this.mapping, required this.field});
  final ResponseMapping mapping;
  final DataField field;
}

class _MonitoredFieldValue {
  const _MonitoredFieldValue({
    required this.responseName,
    required this.commandHex,
    required this.value,
    required this.timestamp,
  });
  final String responseName;
  final String commandHex;
  final ParsedDataValue value;
  final DateTime timestamp;
}

String _monitorFieldId(ResponseMapping mapping, String fieldKey) =>
    '${mapping.id}:$fieldKey';

String _formatCommandSendLog(
  CommandDefinition command,
  Map<String, String> values,
  AppLocalizations l10n,
) {
  final String parameters = command.parameters
      .map((CommandParameter parameter) {
        final String label = parameter.label.isEmpty
            ? parameter.key
            : parameter.label;
        final String value = values[parameter.key] ?? parameter.defaultValue;
        return '$label=$value';
      })
      .join(', ');
  return l10n.commandLog(command.name, parameters.isEmpty ? '--' : parameters);
}

String _formatParsedResponseLog(
  ParsedResponse response,
  AppLocalizations l10n,
) {
  final String values = response.values
      .map(
        (ParsedDataValue value) =>
            '${value.label}=${value.displayValue}${value.unit.isEmpty ? '' : value.unit}',
      )
      .join(', ');
  return l10n.responseLog(
    response.mapping.name,
    response.commandHex,
    values.isEmpty ? '--' : values,
  );
}

class _CommandsAndDataPanel extends StatelessWidget {
  const _CommandsAndDataPanel({
    required this.canSend,
    required this.onSend,
    required this.commands,
    required this.responseMappings,
    required this.monitoredValues,
    required this.l10n,
  });
  final bool canSend;
  final Future<void> Function(CommandDefinition, Map<String, String>) onSend;
  final List<CommandDefinition> commands;
  final List<ResponseMapping> responseMappings;
  final Map<String, _MonitoredFieldValue> monitoredValues;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _QuickCommandsPanel(
            canSend: canSend,
            onSend: onSend,
            commands: commands,
            l10n: l10n,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 4,
          child: _MappedDataPanel(
            mappings: responseMappings,
            monitoredValues: monitoredValues,
            l10n: l10n,
          ),
        ),
      ],
    );
  }
}

class _MappedDataPanel extends StatelessWidget {
  const _MappedDataPanel({
    required this.mappings,
    required this.monitoredValues,
    required this.l10n,
  });
  final List<ResponseMapping> mappings;
  final Map<String, _MonitoredFieldValue> monitoredValues;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<_MonitoredFieldDefinition> fields = <_MonitoredFieldDefinition>[
      for (final ResponseMapping mapping in mappings)
        for (final DataField field in mapping.fields)
          if (field.visibleInDataPanel)
            _MonitoredFieldDefinition(mapping: mapping, field: field),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.mappedData,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (fields.isEmpty)
            Expanded(child: Center(child: Text(l10n.noMappedFields)))
          else
            Expanded(
              child: ListView.separated(
                itemCount: fields.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final _MonitoredFieldDefinition definition = fields[index];
                  final _MonitoredFieldValue? latest =
                      monitoredValues[_monitorFieldId(
                        definition.mapping,
                        definition.field.key,
                      )];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                definition.field.label.isEmpty
                                    ? definition.field.key
                                    : definition.field.label,
                              ),
                              Text(
                                '${definition.mapping.name} | CMD ${definition.mapping.commandHex}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          latest == null
                              ? '--'
                              : '${latest.value.displayValue}${latest.value.unit.isEmpty ? '' : ' ${latest.value.unit}'}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CharacteristicTile extends StatelessWidget {
  const _CharacteristicTile({
    required this.characteristic,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onRead,
    required this.l10n,
  });

  final BluetoothCharacteristicInfo characteristic;
  final Future<void> Function(BluetoothCharacteristicInfo) onSelectWrite;
  final Future<void> Function(
    BluetoothCharacteristicInfo,
    BluetoothSubscriptionMode,
    bool,
  )
  onSubscriptionChanged;
  final Future<void> Function(BluetoothCharacteristicInfo) onRead;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool dense = MediaQuery.sizeOf(context).width >= 680;
    final shad.AbstractButtonStyle actionStyle = dense
        ? const shad.ButtonStyle.ghost(
            size: shad.ButtonSize.small,
            density: shad.ButtonDensity.dense,
          )
        : const shad.ButtonStyle.ghost();
    final shad.AbstractButtonStyle selectedActionStyle = dense
        ? const shad.ButtonStyle.secondary(
            size: shad.ButtonSize.small,
            density: shad.ButtonDensity.dense,
          )
        : const shad.ButtonStyle.secondary();
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                characteristic.isSubscribed
                    ? Icons.sensors_outlined
                    : Icons.memory_outlined,
                size: 16,
                color: characteristic.isSubscribed
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _characteristicTitle(characteristic.characteristicId, l10n) ??
                      _shortUuid(characteristic.characteristicId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Text(
            characteristic.characteristicId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              if (characteristic.canWrite)
                _CapabilityChip(code: 'W', label: l10n.writeWithResponse),
              if (characteristic.canWriteWithoutResponse)
                _CapabilityChip(code: 'NR', label: l10n.writeWithoutResponse),
              if (characteristic.canRead)
                _CapabilityChip(code: 'R', label: l10n.read),
              if (characteristic.canNotify)
                _CapabilityChip(code: 'N', label: l10n.notify),
              if (characteristic.canIndicate)
                _CapabilityChip(code: 'I', label: l10n.indicate),
            ],
          ),
          if (characteristic.canRead ||
              characteristic.canWrite ||
              characteristic.canWriteWithoutResponse ||
              characteristic.canSubscribe)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  if (characteristic.canRead)
                    Tooltip(
                      message: l10n.readValue,
                      child: shad.IconButton.ghost(
                        key: ValueKey<String>(
                          'characteristic-read-${characteristic.key}',
                        ),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        size: dense
                            ? shad.ButtonSize.small
                            : shad.ButtonSize.normal,
                        onPressed: () => onRead(characteristic),
                      ),
                    ),
                  if (characteristic.canWrite ||
                      characteristic.canWriteWithoutResponse)
                    shad.SelectedButton(
                      key: ValueKey<String>(
                        'characteristic-write-target-${characteristic.key}',
                      ),
                      value: characteristic.isWriteTarget,
                      style: actionStyle,
                      selectedStyle: selectedActionStyle,
                      onChanged: (_) => onSelectWrite(characteristic),
                      child: Text(l10n.writeTarget),
                    ),
                  if (characteristic.canNotify)
                    shad.SelectedButton(
                      key: ValueKey<String>(
                        'characteristic-notify-${characteristic.key}',
                      ),
                      value:
                          characteristic.isSubscribed &&
                          characteristic.subscriptionMode ==
                              BluetoothSubscriptionMode.notify,
                      style: actionStyle,
                      selectedStyle: selectedActionStyle,
                      onChanged: (bool selected) => onSubscriptionChanged(
                        characteristic,
                        BluetoothSubscriptionMode.notify,
                        selected,
                      ),
                      child: Text(l10n.notify),
                    ),
                  if (characteristic.canIndicate)
                    shad.SelectedButton(
                      key: ValueKey<String>(
                        'characteristic-indicate-${characteristic.key}',
                      ),
                      value:
                          characteristic.isSubscribed &&
                          characteristic.subscriptionMode ==
                              BluetoothSubscriptionMode.indicate,
                      style: actionStyle,
                      selectedStyle: selectedActionStyle,
                      onChanged: (bool selected) => onSubscriptionChanged(
                        characteristic,
                        BluetoothSubscriptionMode.indicate,
                        selected,
                      ),
                      child: Text(l10n.indicate),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.code, required this.label});
  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: shad.SecondaryBadge(
          style: const shad.ButtonStyle.secondary(
            size: shad.ButtonSize.xSmall,
            density: shad.ButtonDensity.dense,
          ),
          child: Text(code, style: const TextStyle(fontSize: 10)),
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({
    required this.entry,
    required this.l10n,
    this.selected = false,
    this.onTap,
    this.onToggleBookmark,
  });
  final SessionLogRecord entry;
  final AppLocalizations l10n;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<SessionLogRecord>? onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color color = switch (entry.kind) {
      SessionLogKind.received => colors.tertiary,
      SessionLogKind.sent => colors.primary,
      SessionLogKind.system => Theme.of(context).colorScheme.secondary,
      SessionLogKind.error => Theme.of(context).colorScheme.error,
    };
    final String payload = entry.message ?? _toHex(entry.data);
    final String timestamp = entry.timestamp.toIso8601String().split('T').last;
    final Widget? bookmarkButton = onToggleBookmark == null
        ? null
        : IconButton(
            tooltip: entry.bookmarked ? '取消书签' : '添加书签',
            onPressed: () => onToggleBookmark!(entry),
            icon: Icon(
              entry.bookmarked ? Icons.bookmark : Icons.bookmark_outline,
              size: 19,
            ),
            color: entry.bookmarked ? colors.primary : null,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            visualDensity: VisualDensity.compact,
          );
    final Widget? detailsButton = onTap == null
        ? null
        : IconButton(
            tooltip: l10n.viewLogDetails,
            onPressed: onTap,
            icon: const Icon(Icons.subject_outlined, size: 18),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            visualDensity: VisualDensity.compact,
          );
    return Semantics(
      label: '${entry.directionLabel(l10n)} $timestamp，$payload',
      child: GestureDetector(
        key: ValueKey<String>('console-log-${entry.kind.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.45)
                : null,
            border: Border(left: BorderSide(color: color, width: 2)),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 520;
              final Widget direction = Container(
                width: 34,
                padding: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  entry.shortDirection,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              final Widget content = SelectableText(
                payload,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  color: entry.kind == SessionLogKind.error ? color : null,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          timestamp,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: colors.outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        direction,
                        if (entry.characteristicId != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _shortUuid(entry.characteristicId!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        if (entry.data.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            '${entry.data.length} B',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                        if (bookmarkButton != null) ...<Widget>[
                          const Spacer(),
                          ?detailsButton,
                          bookmarkButton,
                        ] else if (detailsButton != null) ...<Widget>[
                          const Spacer(),
                          detailsButton,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    content,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 90,
                    child: Text(
                      timestamp,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colors.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  direction,
                  if (entry.characteristicId != null) ...<Widget>[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 66,
                      child: Text(
                        _shortUuid(entry.characteristicId!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  if (entry.data.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${entry.data.length} B',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(child: content),
                  ?detailsButton,
                  ?bookmarkButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

extension _SessionLogRecordLabels on SessionLogRecord {
  String directionLabel(AppLocalizations l10n) => switch (kind) {
    SessionLogKind.received => l10n.received,
    SessionLogKind.sent => l10n.sendData,
    SessionLogKind.system => l10n.system,
    SessionLogKind.error => l10n.error,
  };

  String get shortDirection => switch (kind) {
    SessionLogKind.received => 'RX',
    SessionLogKind.sent => 'TX',
    SessionLogKind.system => 'SYS',
    SessionLogKind.error => 'ERR',
  };
}

List<int>? _parseHex(String value) {
  final compact = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (compact.isEmpty || compact.length.isOdd) return null;
  return <int>[
    for (var i = 0; i < compact.length; i += 2)
      int.parse(compact.substring(i, i + 2), radix: 16),
  ];
}

IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};

String _toHex(List<int> bytes) => bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');

const String _defaultBeforeSendScript = '''
function hexToBytes(hex) {
  var compact = (hex || '').replace(/[^0-9a-fA-F]/g, '');
  var out = [];
  for (var i = 0; i < compact.length; i += 2) {
    out.push(parseInt(compact.substring(i, i + 2), 16));
  }
  return out;
}

function bytesToHex(bytes) {
  return bytes.map(function(b) {
    return b.toString(16).padStart(2, '0').toUpperCase();
  }).join(' ');
}

function nextIndex() {
  while (true) {
    var value = Math.floor(Math.random() * 256) & 0xFF;
    if (value !== 0x0D) {
      return value;
    }
  }
}

function seed(index, proof) {
  var r = (index ^ proof) & 0xFF;
  if (r === 0x00) return 0x44;
  if (r === 0xFF) return 0x7F;
  return r;
}

function beforeSend(context) {
  var payload = hexToBytes(context.payloadHex);
  if (payload.length === 0) {
    return { frameHex: '', logs: ['beforeSend: empty payload'] };
  }
  var index = nextIndex();
  var crc = index;
  for (var i = 0; i < payload.length; i += 1) {
    crc = (crc + payload[i]) & 0xFF;
  }
  var plain = payload.concat([crc]);
  var escaped = [];
  for (var j = 0; j < plain.length; j += 1) {
    escaped.push(plain[j]);
    if (plain[j] === 0x0D) escaped.push(0x0D);
  }
  var s = seed(index, 0xB0);
  var encrypted = escaped.map(function(b) { return (b ^ s) & 0xFF; });
  var frame = [0x0D, 0xEF, index].concat(encrypted).concat([0x0D, 0xFE]);
  return {
    frameHex: bytesToHex(frame),
    logs: ['beforeSend index=' + index.toString(16).padStart(2, '0').toUpperCase(), 'beforeSend crc=' + crc.toString(16).padStart(2, '0').toUpperCase()]
  };
}
''';

const String _defaultAfterReceiveScript = '''
function hexToBytes(hex) {
  var compact = (hex || '').replace(/[^0-9a-fA-F]/g, '');
  var out = [];
  for (var i = 0; i < compact.length; i += 2) {
    out.push(parseInt(compact.substring(i, i + 2), 16));
  }
  return out;
}

function bytesToHex(bytes) {
  return bytes.map(function(b) {
    return b.toString(16).padStart(2, '0').toUpperCase();
  }).join(' ');
}

function seed(index, proof) {
  var r = (index ^ proof) & 0xFF;
  if (r === 0x00) return 0x44;
  if (r === 0xFF) return 0x7F;
  return r;
}

function afterReceive(context) {
  var frame = hexToBytes(context.frameHex);
  if (frame.length < 5) {
    return { valid: false, logs: ['afterReceive: frame too short'] };
  }
  var index = frame[2];
  var encrypted = frame.slice(3, frame.length - 2);
  var s = seed(index, 0xA0);
  var decoded = encrypted.map(function(b) { return (b ^ s) & 0xFF; });
  var plain = [];
  for (var i = 0; i < decoded.length; i += 1) {
    if (decoded[i] === 0x0D && decoded[i + 1] === 0x0D) {
      plain.push(0x0D);
      i += 1;
    } else {
      plain.push(decoded[i]);
    }
  }
  if (plain.length < 2) {
    return { valid: false, logs: ['afterReceive: payload too short'] };
  }
  var crc = plain[plain.length - 1];
  var payload = plain.slice(0, plain.length - 1);
  var calc = index;
  for (var j = 0; j < payload.length; j += 1) {
    calc = (calc + payload[j]) & 0xFF;
  }
  var valid = calc === crc;
  return {
    valid: valid,
    payloadHex: bytesToHex(payload),
    cmdHex: payload.length > 0 ? bytesToHex([payload[0]]) : '',
    dataHex: payload.length > 1 ? bytesToHex(payload.slice(1)) : '',
    logs: ['afterReceive index=' + index.toString(16).padStart(2, '0').toUpperCase(), 'afterReceive crc=' + crc.toString(16).padStart(2, '0').toUpperCase(), 'afterReceive valid=' + valid]
  };
}
''';
