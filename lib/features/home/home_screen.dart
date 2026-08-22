import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../../app/app_theme.dart';
import '../../app/app_version.dart';
import '../../app/design/app_icons.dart';
import '../../app/design/tool_alert_dialog.dart';
import '../../app/design/tool_button.dart';
import '../../app/design/tool_clickable.dart';
import '../../app/design/tool_select.dart';
import '../../app/design/tool_text_field.dart';
import '../../app/design/tool_toggle.dart';
import '../../app/design/tool_tooltip.dart';
import '../../app/design/tool_toast.dart';
import '../../l10n/app_localizations.dart';
import '../../models/command_definition.dart';
import '../../models/bluetooth_write_mode.dart';
import '../../models/data_mapping.dart';
import '../../models/device_profile.dart';
import '../../models/device_safety_policy.dart';
import '../../models/protocol_profile.dart';
import '../../models/protocol_import/candidate_item.dart';
import '../../models/protocol_import/protocol_import_job.dart';
import '../../models/protocol_import/validation_report.dart';
import '../../models/script_config.dart';
import '../../models/session_log_record.dart';
import '../../models/workspace.dart';
import '../../services/bluetooth_service.dart';
import '../../services/command_payload_encoder.dart';
import '../../services/data_mapper.dart';
import '../../services/device_send_policy.dart';
import '../../services/packet_decoder.dart';
import '../../services/packet_encoder.dart';
import '../../services/script_engine.dart';
import '../../services/send_safety_policy.dart';
import '../../services/session_log_store.dart';
import '../../services/workspace_manager.dart';
import '../../services/protocol_import/candidate_workspace_codec.dart';
import '../../services/protocol_import/workspace_draft_manager.dart';
import '../../utils/ascii_utils.dart';
import '../../utils/web_service_uuid_parser.dart';

part '../../widgets/app_workspace_shell.dart';
part '../configuration/command_library_panel.dart';
part '../configuration/configuration_workspace.dart';
part '../configuration/data_mapping_library_panel.dart';
part '../configuration/default_scripts.dart';
part '../configuration/protocol_configuration_panel.dart';
part '../configuration/protocol_import_review.dart';
part '../configuration/workspace_overview.dart';
part '../debug/console_area.dart';
part '../debug/console_filter_bar.dart';
part '../debug/inspector_panel.dart';
part '../debug/log_line.dart';
part '../device/characteristic_tile.dart';
part '../device/device_tools_panel.dart';
part '../device/monitored_data_panel.dart';
part '../device/quick_commands_panel.dart';
part '../records/record_workspace.dart';
part 'home_shortcuts.dart';
part 'workspace_toolbar.dart';

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

class _ProtocolCandidateImportDecision {
  const _ProtocolCandidateImportDecision.import(this.jsonText) : jobId = null;

  const _ProtocolCandidateImportDecision.resume(this.jobId) : jsonText = null;

  final String? jsonText;
  final String? jobId;
}

enum _ConnectionOperation { connect, disconnect }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    this.bluetoothService,
  });

  final shad.ThemeMode themeMode;
  final Locale? locale;
  final ValueChanged<shad.ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final BluetoothService? bluetoothService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _maxConsoleLogs = SessionLogStore.maxRecords;
  static const int _maxPendingReceiveEvents = 64;
  late final WorkspaceManager _workspaceManager;
  late final WorkspaceDraftManager _workspaceDraftManager;
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
  List<SessionLogRecord>? _visibleConsoleLogsCache;
  SessionLogRecord? _selectedLog;
  int _discardedLogCount = 0;
  _ConsoleLogFilter _consoleLogFilter = _ConsoleLogFilter.all;
  final Map<String, _MonitoredFieldValue> _monitoredValues =
      <String, _MonitoredFieldValue>{};
  String? _selectedDeviceId;
  bool _scanning = false;
  _ConnectionOperation? _connectionOperation;
  bool _hexMode = true;
  bool _directSend = false;
  bool _autoScroll = true;
  _AppMode _mode = _AppMode.debug;
  bool _characteristicsOpen = true;
  bool _inspectorOpen = true;
  List<String> _webOptionalServices = <String>[];
  Future<void> _saveWorkspaceChain = Future<void>.value();
  Future<void> _saveSessionLogsChain = Future<void>.value();
  Timer? _sessionLogPersistTimer;
  Timer? _logRebuildTimer;
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
    _workspaceDraftManager = WorkspaceDraftManager();
    unawaited(_restoreWorkspaceDrafts());
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
    _logRebuildTimer?.cancel();
    _flushSessionLogsPersistence();
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
        _invalidateVisibleConsoleLogs();
      });
    } catch (error) {
      debugPrint('会话记录加载失败：$error');
    }
  }

  void _persistSessionLogs() {
    // RX traffic can produce multiple records per frame. Debounce persistence
    // so JSON encoding and preference writes do not compete with layout/paint.
    _sessionLogPersistTimer?.cancel();
    _sessionLogPersistTimer = Timer(const Duration(milliseconds: 250), () {
      _sessionLogPersistTimer = null;
      _flushSessionLogsPersistence();
    });
  }

  void _flushSessionLogsPersistence() {
    _sessionLogPersistTimer?.cancel();
    _sessionLogPersistTimer = null;
    final List<SessionLogRecord> snapshot = List<SessionLogRecord>.from(_logs);
    _saveSessionLogsChain = _saveSessionLogsChain
        .then((_) => _sessionLogStore.save(snapshot))
        .catchError((Object error) => debugPrint('会话记录保存失败：$error'));
  }

  void _updateLogState(VoidCallback mutation) {
    mutation();
    if (_logRebuildTimer != null) return;
    _logRebuildTimer = Timer(const Duration(milliseconds: 16), () {
      _logRebuildTimer = null;
      if (mounted) setState(() {});
    });
  }

  void _clearLogs() {
    _sessionLogPersistTimer?.cancel();
    setState(() {
      _logs.clear();
      _selectedLog = null;
      _discardedLogCount = 0;
      _invalidateVisibleConsoleLogs();
    });
    _saveSessionLogsChain = _saveSessionLogsChain
        .then((_) => _sessionLogStore.clear())
        .catchError((Object error) => debugPrint('会话记录清除失败：$error'));
  }

  List<SessionLogRecord> get _visibleConsoleLogs {
    final List<SessionLogRecord>? cached = _visibleConsoleLogsCache;
    if (cached != null) return cached;
    final String query = _consoleSearchController.text.trim().toLowerCase();
    return _visibleConsoleLogsCache = _logs
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

  void _invalidateVisibleConsoleLogs() {
    _visibleConsoleLogsCache = null;
  }

  void _toggleSessionLogBookmark(SessionLogRecord record) {
    final int index = _logs.indexOf(record);
    if (index < 0) return;
    setState(() {
      _logs[index] = record.copyWith(bookmarked: !record.bookmarked);
      _invalidateVisibleConsoleLogs();
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

  void _activateImportedDraftWorkspace(Workspace workspace) {
    setState(() => _upsertWorkspace(workspace));
  }

  Future<void> _restoreWorkspaceDrafts() async {
    try {
      await _workspaceDraftManager.load();
    } on Object catch (error) {
      if (mounted) {
        _addSystemLog('协议导入草案恢复失败：$error');
      }
    }
  }

  void _persistWorkspaceDrafts() {
    unawaited(
      _workspaceDraftManager.save().catchError((Object error) {
        if (mounted) {
          _addSystemLog('协议导入草案保存失败：$error');
        }
      }),
    );
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
      _updateLogState(() {
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
          _updateLogState(() {
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
      _updateLogState(() {
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
      _directSend = false;
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
                icon: AppIcons.bluetoothSearching,
                title: l10n.webServiceUuids,
                content: SizedBox(
                  width: 460,
                  child: ToolTextField(
                    controller: controller,
                    label: l10n.webServiceUuids,
                    hintText: l10n.webServiceUuidsHint,
                    errorText: validationError,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                  ),
                ),
                actions: <Widget>[
                  ToolButton.ghost(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  ToolButton.primary(
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
      showToolToast(context, l10n.deleteWorkspaceLast);
      return;
    }
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final bool confirmed =
        await showToolDialog<bool>(
          context: context,
          builder: (BuildContext context) => ToolAlertDialog(
            icon: AppIcons.deleteOutline,
            title: l10n.deleteWorkspace,
            content: Text(l10n.deleteWorkspaceConfirm(workspace.name)),
            actions: <Widget>[
              ToolButton.ghost(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              ToolButton.destructive(
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
              icon: AppIcons.warningAmber,
              title: '启用未信任脚本？',
              content: Text(
                '来源：${scriptConfig.source}\n'
                '代码规模：${scriptConfig.beforeSendScript.length + scriptConfig.afterReceiveScript.length} 字符\n\n'
                '脚本可修改发送到真实设备的 BLE 数据。仅在已审查脚本内容并信任来源时启用。',
              ),
              actions: <Widget>[
                ToolButton.ghost(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('保持禁用'),
                ),
                ToolButton.primary(
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
          builder: (BuildContext context, StateSetter setDialogState) => ToolAlertDialog(
            icon: AppIcons.terminalOutlined,
            title: existing == null ? l10n.newCommand : l10n.editCommand,
            content: SizedBox(
              width: 620,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 16),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final bool stacked = constraints.maxWidth < 560;

                      void insertParameter(String key) {
                        final String token = '{{${key.trim()}}}';
                        final String text = payloadController.text;
                        final TextSelection selection =
                            payloadController.selection;
                        final int start = selection.isValid
                            ? selection.start.clamp(0, text.length)
                            : text.length;
                        final int end = selection.isValid
                            ? selection.end.clamp(0, text.length)
                            : text.length;
                        final String before = text.substring(0, start);
                        final String after = text.substring(end);
                        final bool needsLeadingSpace =
                            format == CommandPayloadFormat.hex &&
                            before.isNotEmpty &&
                            !RegExp(r'\s$').hasMatch(before);
                        final bool needsTrailingSpace =
                            format == CommandPayloadFormat.hex &&
                            after.isNotEmpty &&
                            !RegExp(r'^\s').hasMatch(after);
                        final String inserted =
                            '${needsLeadingSpace ? ' ' : ''}$token${needsTrailingSpace ? ' ' : ''}';
                        payloadController.value = TextEditingValue(
                          text: '$before$inserted$after',
                          selection: TextSelection.collapsed(
                            offset: before.length + inserted.length,
                          ),
                        );
                        setDialogState(() {});
                      }

                      return Column(
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
                                      color: AppTheme.colorsOf(
                                        context,
                                      ).destructive,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>('command-name-row'),
                            label: l10n.commandName,
                            stacked: stacked,
                            labelWidth: 132,
                            child: ToolTextField(
                              key: const ValueKey<String>('command-name-field'),
                              controller: nameController,
                              autofocus: true,
                              label: l10n.commandName,
                              showLabel: false,
                              hintText: '请输入指令名称',
                              errorText: nameError,
                            ),
                          ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>('command-group-row'),
                            label: l10n.commandGroup,
                            stacked: stacked,
                            labelWidth: 132,
                            child: ToolTextField(
                              key: const ValueKey<String>(
                                'command-group-field',
                              ),
                              controller: groupController,
                              label: l10n.commandGroup,
                              showLabel: false,
                              hintText: '可选，用于在指令集和快捷指令中分组显示',
                            ),
                          ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>('command-format-row'),
                            label: l10n.commandFormat,
                            stacked: stacked,
                            labelWidth: 132,
                            child: ToolSelect<CommandPayloadFormat>(
                              key: const ValueKey<String>(
                                'command-format-select',
                              ),
                              value: format,
                              label: l10n.commandFormat,
                              showLabel: false,
                              openAbove: true,
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
                          ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>('command-payload-row'),
                            label: l10n.commandPayload,
                            stacked: stacked,
                            alignLabelToTop: true,
                            labelWidth: 132,
                            child: ToolTextField(
                              key: const ValueKey<String>(
                                'command-payload-field',
                              ),
                              controller: payloadController,
                              minLines: 2,
                              maxLines: 4,
                              label: l10n.commandPayload,
                              showLabel: false,
                              hintText: format == CommandPayloadFormat.hex
                                  ? '例如 AA 01 {{value}}'
                                  : '请输入文本内容',
                              errorText: payloadError,
                            ),
                          ),
                          if (parameters.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SizedBox(
                                    width: stacked ? null : 132,
                                    child: stacked
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              '快捷参数',
                                              style: AppTheme.textStylesOf(
                                                context,
                                              ).labelMedium,
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              '快捷参数',
                                              style: AppTheme.textStylesOf(
                                                context,
                                              ).labelMedium,
                                            ),
                                          ),
                                  ),
                                  if (!stacked) const SizedBox(width: 12),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: parameters
                                          .asMap()
                                          .entries
                                          .where(
                                            (
                                              MapEntry<int, CommandParameter>
                                              entry,
                                            ) => entry.value.key
                                                .trim()
                                                .isNotEmpty,
                                          )
                                          .map(
                                            (
                                              MapEntry<int, CommandParameter>
                                              entry,
                                            ) => ToolTooltip(
                                              key: ValueKey<String>(
                                                'command-parameter-token-wrapper-${entry.key}',
                                              ),
                                              message:
                                                  '插入 {{${entry.value.key}}}',
                                              child: ToolButton.outline(
                                                key: ValueKey<String>(
                                                  'command-parameter-token-${entry.key}',
                                                ),
                                                onPressed: () =>
                                                    insertParameter(
                                                      entry.value.key,
                                                    ),
                                                compact: true,
                                                height: 28,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: Text(
                                                  entry.value.label
                                                          .trim()
                                                          .isEmpty
                                                      ? entry.value.key
                                                      : entry.value.label,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  width: stacked ? null : 132,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      top: stacked ? 0 : 4,
                                      bottom: stacked ? 4 : 0,
                                    ),
                                    child: Text(
                                      '参数\n在 HEX 中使用 {{key}}',
                                      maxLines: 2,
                                      softWrap: false,
                                      style: AppTheme.textStylesOf(
                                        context,
                                      ).labelMedium,
                                    ),
                                  ),
                                ),
                                if (!stacked) const SizedBox(width: 12),
                                ToolTooltip(
                                  message: '新增参数',
                                  child: ToolButton.outline(
                                    key: const ValueKey<String>(
                                      'add-command-parameter-button',
                                    ),
                                    onPressed: () => setDialogState(
                                      () => parameters.add(
                                        _newCommandParameter(),
                                      ),
                                    ),
                                    compact: true,
                                    height: 28,
                                    leading: const Icon(AppIcons.add, size: 15),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: const Text('新增参数'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (
                            int index = 0;
                            index < parameters.length;
                            index++
                          )
                            _CommandParameterEditor(
                              key: ValueKey<String>(
                                'command-parameter-row-$index',
                              ),
                              parameter: parameters[index],
                              onChanged: (CommandParameter value) =>
                                  setDialogState(
                                    () => parameters[index] = value,
                                  ),
                              onDelete: () => setDialogState(
                                () => parameters.removeAt(index),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.only(
                              top: parameters.isEmpty ? 4 : 8,
                            ),
                            child: _ConfigurationFormRow(
                              key: const ValueKey<String>('command-notes-row'),
                              label: l10n.commandNotes,
                              stacked: stacked,
                              labelWidth: 132,
                              child: ToolTextField(
                                key: const ValueKey<String>(
                                  'command-notes-field',
                                ),
                                controller: notesController,
                                minLines: 1,
                                maxLines: 3,
                                label: l10n.commandNotes,
                                showLabel: false,
                                hintText: '可选',
                              ),
                            ),
                          ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>('command-enabled-row'),
                            label: l10n.commandEnabled,
                            stacked: stacked,
                            labelWidth: 132,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ToolSwitch(
                                value: enabled,
                                onChanged: (bool value) {
                                  setDialogState(() => enabled = value);
                                },
                                label: l10n.commandEnabled,
                              ),
                            ),
                          ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>(
                              'command-quick-access-row',
                            ),
                            label: l10n.quickAccess,
                            stacked: stacked,
                            labelWidth: 132,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ToolSwitch(
                                value: isQuickAccess,
                                onChanged: (bool value) {
                                  setDialogState(() => isQuickAccess = value);
                                },
                                label: l10n.quickAccess,
                              ),
                            ),
                          ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>(
                              'command-confirmation-row',
                            ),
                            label: '发送前始终确认',
                            stacked: stacked,
                            labelWidth: 132,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ToolSwitch(
                                value: requiresConfirmation,
                                onChanged: (bool value) {
                                  setDialogState(
                                    () => requiresConfirmation = value,
                                  );
                                },
                                label: '发送前始终确认',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              ToolButton.ghost(
                onPressed: () => Navigator.of(context).pop(),
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Text(l10n.cancel),
              ),
              ToolButton.primary(
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
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
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
      final Map<String, String> resolvedValues =
          CommandPayloadEncoder.resolveValues(command, values);
      final List<int> bytes = CommandPayloadEncoder.encode(
        command,
        resolvedValues,
      );
      _addSystemLog(
        _formatCommandSendLog(
          command,
          resolvedValues,
          AppLocalizations.of(context)!,
        ),
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
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
          builder: (BuildContext context, StateSetter setDialogState) => ToolAlertDialog(
            icon: AppIcons.dataObject,
            title: existing == null
                ? l10n.newResponseMapping
                : l10n.editResponseMapping,
            content: SizedBox(
              width: 620,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 16),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final bool stacked = constraints.maxWidth < 560;
                      return Column(
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
                                      color: AppTheme.colorsOf(
                                        context,
                                      ).destructive,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>(
                              'response-mapping-name-row',
                            ),
                            label: l10n.responseName,
                            stacked: stacked,
                            labelWidth: 132,
                            child: ToolTextField(
                              key: const ValueKey<String>(
                                'response-mapping-name-field',
                              ),
                              controller: nameController,
                              label: l10n.responseName,
                              showLabel: false,
                            ),
                          ),
                          _ConfigurationFormRow(
                            key: const ValueKey<String>(
                              'response-mapping-command-row',
                            ),
                            label: l10n.responseCommandHex,
                            stacked: stacked,
                            labelWidth: 132,
                            child: ToolTextField(
                              key: const ValueKey<String>(
                                'response-mapping-command-field',
                              ),
                              controller: commandController,
                              label: l10n.responseCommandHex,
                              showLabel: false,
                              style: AppFonts.monoStyle,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      l10n.responseFieldsHint,
                                      style: AppTheme.textStylesOf(
                                        context,
                                      ).labelMedium,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ToolTooltip(
                                  message: l10n.addDataField,
                                  child: ToolButton.outline(
                                    key: const ValueKey<String>(
                                      'add-response-mapping-field-button',
                                    ),
                                    onPressed: () => setDialogState(
                                      () => fields.add(
                                        _newDataField(fields.length),
                                      ),
                                    ),
                                    compact: true,
                                    height: 28,
                                    leading: const Icon(AppIcons.add, size: 15),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(l10n.addDataField),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (int index = 0; index < fields.length; index++)
                            _MappingFieldEditor(
                              key: ValueKey<String>(
                                'response-mapping-field-row-$index',
                              ),
                              field: fields[index],
                              onChanged: (DataField value) =>
                                  setDialogState(() => fields[index] = value),
                              onDelete: () =>
                                  setDialogState(() => fields.removeAt(index)),
                            ),
                          Container(
                            padding: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.colorsOf(context).border,
                                ),
                              ),
                            ),
                            child: _ConfigurationFormRow(
                              key: const ValueKey<String>(
                                'response-mapping-ascii-log-row',
                              ),
                              label: l10n.responseAsciiLog,
                              stacked: stacked,
                              labelWidth: 132,
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      l10n.responseAsciiLogHint,
                                      style: AppTheme.textStylesOf(
                                        context,
                                      ).bodySmall,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ToolSwitch(
                                    value: asciiLogEnabled,
                                    onChanged: (bool value) => setDialogState(
                                      () => asciiLogEnabled = value,
                                    ),
                                    label: l10n.responseAsciiLog,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              ToolButton.ghost(
                onPressed: () => Navigator.of(context).pop(),
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Text(l10n.cancel),
              ),
              ToolButton.primary(
                onPressed: () {
                  final String commandHex = commandController.text.replaceAll(
                    RegExp(r'[^0-9a-fA-F]'),
                    '',
                  );
                  if (nameController.text.trim().isEmpty ||
                      commandHex.length != 2 ||
                      fields.any(
                        (DataField field) => field.key.trim().isEmpty,
                      )) {
                    setDialogState(
                      () => validationError = l10n.invalidResponseMapping,
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
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Text(l10n.save),
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
    if (_connectionOperation != null) {
      return;
    }
    final _ConnectionOperation operation = device.connected
        ? _ConnectionOperation.disconnect
        : _ConnectionOperation.connect;
    _addSystemLog(
      operation == _ConnectionOperation.disconnect
          ? AppLocalizations.of(context)!.disconnectingDevice(device.name)
          : AppLocalizations.of(context)!.connectingDevice(device.name),
    );
    setState(() => _connectionOperation = operation);
    try {
      if (operation == _ConnectionOperation.disconnect) {
        await _bluetoothService.disconnect(device.id);
        if (mounted) {
          setState(() {
            _characteristics = <BluetoothCharacteristicInfo>[];
            _connectionOperation = null;
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
            _connectionOperation = null;
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
          _connectionOperation = null;
          _characteristics = <BluetoothCharacteristicInfo>[];
        });
      }
      _showBluetoothError(error);
    }
  }

  Future<void> _setWriteCharacteristic(
    BluetoothCharacteristicInfo characteristic,
    BluetoothWriteMode mode,
  ) async {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) {
      return;
    }
    try {
      await _bluetoothService.setWriteCharacteristic(
        deviceId,
        characteristic,
        mode,
      );
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
            (BluetoothCharacteristicInfo item) => item.key == characteristic.key
                ? item.copyWith(writeMode: mode)
                : item.copyWith(clearWriteMode: true),
          )
          .toList(growable: false);
    });
    _saveConnectionDefaults(write: characteristic, writeMode: mode);
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
        final BluetoothWriteMode mode =
            profile.writeMode ??
            (write.canWrite
                ? BluetoothWriteMode.withResponse
                : BluetoothWriteMode.withoutResponse);
        final bool modeSupported = switch (mode) {
          BluetoothWriteMode.withResponse => write.canWrite,
          BluetoothWriteMode.withoutResponse => write.canWriteWithoutResponse,
        };
        if (!modeSupported) {
          _addSystemLog('默认写入模式不可用：${mode.name}');
        } else {
          await _bluetoothService.setWriteCharacteristic(deviceId, write, mode);
          restored = restored
              .map(
                (BluetoothCharacteristicInfo item) => item.key == write.key
                    ? item.copyWith(writeMode: mode)
                    : item.copyWith(clearWriteMode: true),
              )
              .toList(growable: false);
          _addSystemLog('已恢复默认写入特征：${write.characteristicId}');
        }
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
    BluetoothWriteMode? writeMode,
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
      writeMode: writeMode,
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
              icon: AppIcons.shieldOutlined,
              title: '设备发送策略',
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '设备：${device.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '选择允许作为写入目标的特征；不选择表示不限制。',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        for (final BluetoothCharacteristicInfo characteristic
                            in writable)
                          ToolCheckboxTile(
                            title: Text(
                              characteristic.characteristicId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              characteristic.serviceId,
                              style: AppFonts.monoStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: allowedKeys.contains(characteristic.key),
                            onChanged: (bool value) => setDialogState(() {
                              if (value) {
                                allowedKeys.add(characteristic.key);
                              } else {
                                allowedKeys.remove(characteristic.key);
                              }
                            }),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          key: const ValueKey<String>(
                            'device-policy-max-frame-row',
                          ),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(
                              width: 128,
                              child: Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  '最终帧最大字节数',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ToolTextField(
                                controller: maxFrameController,
                                label: '最终帧最大字节数',
                                showLabel: false,
                                hintText: '留空表示不限制（全局上限 4096）',
                                keyboardType: TextInputType.number,
                                validator: (String? value) {
                                  final String trimmed = value?.trim() ?? '';
                                  if (trimmed.isEmpty) return null;
                                  final int? parsed = int.tryParse(trimmed);
                                  if (parsed == null ||
                                      parsed < 1 ||
                                      parsed >
                                          ScriptEngineService.maxPacketBytes) {
                                    return '请输入 1 到 ${ScriptEngineService.maxPacketBytes} 的整数。';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            key: const ValueKey<String>(
                              'device-policy-response-row',
                            ),
                            children: <Widget>[
                              ToolSwitch(
                                key: const ValueKey<String>(
                                  'device-policy-response-switch',
                                ),
                                label: '只允许带响应写入',
                                value: requireWriteWithResponse,
                                onChanged: (bool value) => setDialogState(
                                  () => requireWriteWithResponse = value,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '只允许带响应写入',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '仅支持 Write without response 的特征将被拒绝。',
                                  style: AppTheme.textStylesOf(
                                    context,
                                  ).bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                ToolButton.ghost(
                  onPressed: () => Navigator.pop(context),
                  height: 34,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: const Text('取消'),
                ),
                ToolButton.primary(
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
                  height: 34,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
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
    bool directSend = false,
    String? commandName,
    bool commandRequiresConfirmation = false,
  }) async {
    final device = _selectedDevice;
    if (device == null || !_hasWriteTarget) return;
    String? transactionId;
    try {
      final Workspace workspace = _workspaceManager.activeWorkspace;
      final bool hasStandardProtocol =
          !directSend &&
          !workspace.scriptConfig.enabled &&
          workspace.protocol.sendSegments.isNotEmpty;
      final List<int> businessPayload = List<int>.unmodifiable(bytes);
      ScriptEngineResult result;
      if (directSend) {
        result = ScriptEngineResult(
          bytes: businessPayload,
          logs: <String>['direct send: protocol configuration bypassed'],
          payloadHex: _formatHexForLog(businessPayload),
        );
      } else if (hasStandardProtocol) {
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
            writeWithResponseSelected:
                writeTarget.writeMode == BluetoothWriteMode.withResponse,
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
        scriptEnabled: workspace.scriptConfig.enabled && !directSend,
        confirmTransformedSend: workspace.scriptConfig.confirmTransformedSend,
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
          !directSend &&
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
      _updateLogState(() {
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
          DeviceSendPolicyReason.writeWithResponseRequired =>
            '当前选择的写入模式不是带响应写入',
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
            icon: AppIcons.warningAmber,
            title: '确认受保护发送',
            content: SizedBox(
              width: 560,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 16),
                  child: shad.SelectableText(
                    <String>[
                      if (commandName != null && commandName.isNotEmpty)
                        '指令：$commandName',
                      '写入特征：${target ?? '未知'}',
                      '原因：${reasons.join('\n')}',
                      '',
                      '业务载荷：${_formatHexForLog(businessPayload)}',
                      '最终帧：${_formatHexForLog(finalFrame)}',
                    ].join('\n'),
                    style: AppFonts.monoStyle,
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              ToolButton.ghost(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ToolButton.primary(
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
    _updateLogState(() {
      _logs.insert(
        0,
        SessionLogRecord.error(
          timestamp: DateTime.now(),
          message: '$message\n${error.toString()}',
        ),
      );
      _trimLogs();
    });
    showToolToast(context, message);
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
    _updateLogState(() {
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
    _invalidateVisibleConsoleLogs();
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
    bool directSend,
    AppLocalizations l10n,
  ) {
    final String value = directSend ? input : input.trim();
    if (value.trim().isEmpty) {
      return _ConsoleSendPreview(error: l10n.emptyInput);
    }
    final List<int>? bytes = hexMode ? _parseHex(value) : utf8.encode(value);
    if (bytes == null) {
      return _ConsoleSendPreview(error: l10n.invalidHexInput);
    }
    if (directSend) {
      return _ConsoleSendPreview(
        payloadLength: bytes.length,
        finalFrame: bytes,
      );
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
    final value = _directSend
        ? _inputController.text
        : _inputController.text.trim();
    if (value.trim().isEmpty) return;
    final bytes = _hexMode ? _parseHex(value) : utf8.encode(value);
    if (bytes == null) return;
    _inputController.clear();
    unawaited(_send(bytes, directSend: _directSend));
  }

  void _exportWorkspaces({required bool currentOnly}) {
    final String title = currentOnly ? '导出当前工作区' : '导出全部工作区';
    final String jsonText = currentOnly
        ? _workspaceManager.exportCurrentWorkspace()
        : _workspaceManager.exportWorkspaces();
    showToolDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => ToolAlertDialog(
        icon: AppIcons.uploadFile,
        title: title,
        content: SizedBox(
          width: 640,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 16),
              child: shad.SelectableText(jsonText, style: AppFonts.monoStyle),
            ),
          ),
        ),
        actions: <Widget>[
          ToolButton.ghost(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          ToolButton.primary(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonText));
              if (mounted) {
                showToolToast(context, '$title JSON 已复制。');
              }
            },
            leading: const Icon(AppIcons.copyOutlined),
            child: const Text('复制 JSON'),
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
          icon: AppIcons.downloadOutlined,
          title: '导入工作区',
          content: SizedBox(
            width: 640,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ToolTextField(
                      controller: controller,
                      label: '工作区 JSON',
                      minLines: 8,
                      maxLines: 16,
                      onChanged: (_) => setDialogState(() {
                        preview = null;
                        validationError = null;
                      }),
                      style: AppFonts.monoStyle,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '导入方式',
                      style: AppTheme.textStylesOf(context).labelLarge,
                    ),
                    const SizedBox(height: 6),
                    ToolSegmentedControl<WorkspaceImportMode>(
                      options: const <ToolSegmentOption<WorkspaceImportMode>>[
                        ToolSegmentOption<WorkspaceImportMode>(
                          value: WorkspaceImportMode.replace,
                          icon: Icon(AppIcons.syncDisabled),
                          label: '完整替换',
                        ),
                        ToolSegmentOption<WorkspaceImportMode>(
                          value: WorkspaceImportMode.merge,
                          icon: Icon(AppIcons.mergeType),
                          label: '合并导入',
                        ),
                      ],
                      value: mode,
                      onChanged: (WorkspaceImportMode value) =>
                          setDialogState(() => mode = value),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mode == WorkspaceImportMode.replace
                          ? '完整替换会移除当前所有工作区，再写入导入内容。'
                          : '合并导入会保留当前工作区；导入内容中 ID 不存在的工作区会作为新工作区加入。',
                      style: AppTheme.textStylesOf(context).bodySmall,
                    ),
                    if (validationError != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: AppTheme.colorsOf(context).destructive,
                        ),
                      ),
                    ],
                    if (preview != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        mode == WorkspaceImportMode.replace
                            ? '将替换当前 ${_workspaceManager.workspaces.length} 个工作区，导入 ${preview!.workspaces.length} 个工作区。'
                            : '将合并当前 ${_workspaceManager.workspaces.length} 个工作区：新增 ${preview!.workspaces.length - preview!.conflictingWorkspaceIds.length} 个工作区，处理 ${preview!.conflictingWorkspaceIds.length} 个 ID 冲突。',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '版本 ${preview!.sourceVersion}${preview!.migrationApplied ? ' -> ${preview!.version}（已迁移）' : ''} | 脚本工作区 ${preview!.scriptedWorkspaceCount} 个（导入后保持禁用）。',
                        style: AppTheme.textStylesOf(context).bodySmall,
                      ),
                      if (preview!
                          .conflictingWorkspaceIds
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'ID 冲突：${preview!.conflictingWorkspaceIds.join('、')}',
                          style: TextStyle(
                            color: AppTheme.colorsOf(context).destructive,
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
                          style: AppTheme.textStylesOf(context).labelLarge,
                        ),
                        const SizedBox(height: 6),
                        ToolSegmentedControl<WorkspaceConflictPolicy>(
                          options:
                              const <
                                ToolSegmentOption<WorkspaceConflictPolicy>
                              >[
                                ToolSegmentOption<WorkspaceConflictPolicy>(
                                  value:
                                      WorkspaceConflictPolicy.replaceExisting,
                                  icon: Icon(AppIcons.syncOutlined),
                                  label: '覆盖当前',
                                ),
                                ToolSegmentOption<WorkspaceConflictPolicy>(
                                  value: WorkspaceConflictPolicy.keepExisting,
                                  icon: Icon(AppIcons.shieldOutlined),
                                  label: '保留当前',
                                ),
                              ],
                          value: conflictPolicy,
                          onChanged: (WorkspaceConflictPolicy value) =>
                              setDialogState(() => conflictPolicy = value),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        preview!.workspaces
                            .map((Workspace workspace) => workspace.name)
                            .join('、'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.textStylesOf(context).bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '需先检查后才能确认',
                        key: const ValueKey<String>(
                          'workspace-import-check-hint',
                        ),
                        style: AppTheme.textStylesOf(context).labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            ToolButton.ghost(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ToolButton.outline(
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
            ToolButton.primary(
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
            const SizedBox(width: 8),
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
        icon: AppIcons.downloadOutlined,
        title: '导出会话记录',
        content: SizedBox(
          width: 640,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 16),
              child: shad.SelectableText(jsonText, style: AppFonts.monoStyle),
            ),
          ),
        ),
        actions: <Widget>[
          ToolButton.ghost(
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
    final bool compactConnectedStyle =
        _connectionOperation == _ConnectionOperation.disconnect ||
        _connectionOperation == null && _selectedDevice?.connected == true;
    final shad.ColorScheme colors = AppTheme.colorsOf(context);
    final shad.AbstractButtonStyle compactConnectionBaseStyle =
        compactConnectedStyle
        ? shad.ButtonVariance.secondary
        : shad.ButtonVariance.primary;
    final shad.AbstractButtonStyle compactConnectionStyle =
        _connectionOperation == null
        ? compactConnectionBaseStyle
        : compactConnectionBaseStyle
              .withBackgroundColor(
                disabledColor: compactConnectedStyle
                    ? colors.secondary
                    : colors.primary,
              )
              .withForegroundColor(
                disabledColor: compactConnectedStyle
                    ? colors.secondaryForeground
                    : colors.primaryForeground,
              )
              .withBorder(
                disabledBorder: compactConnectedStyle
                    ? Border.all(color: colors.secondaryForeground)
                    : null,
              );
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
        child: shad.Scaffold(
          headers: <Widget>[
            LayoutBuilder(
              key: const ValueKey<String>('home-toolbar-layout'),
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compactToolbar =
                    constraints.maxWidth <
                    _WorkspaceSelector._compactToolbarBreakpoint;
                return shad.AppBar(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  title: const _AppIdentity(),
                  trailingGap: compactToolbar
                      ? 4
                      : _WorkspaceSelector._toolbarControlGap,
                  trailing: <Widget>[
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
                          _directSend = false;
                          _workspaceManager.setActiveWorkspace(workspaceId);
                          _persistWorkspaces();
                        });
                      },
                      onNew: _createWorkspace,
                      onDelete: _deleteActiveWorkspace,
                      onExportCurrent: () =>
                          _exportWorkspaces(currentOnly: true),
                      onExportAll: () => _exportWorkspaces(currentOnly: false),
                      onImport: _importWorkspaces,
                      l10n: l10n,
                    ),
                    if (!compactToolbar) ...<Widget>[
                      _ConnectionSelector(
                        devices: _devices,
                        selectedId: _selectedDeviceId,
                        connected: _selectedDevice?.connected ?? false,
                        operation: _connectionOperation,
                        onSelected: _selectDevice,
                        onToggleConnection: _toggleConnection,
                        l10n: l10n,
                      ),
                    ],
                    if (compactToolbar)
                      ToolTooltip(
                        message:
                            _connectionOperation ==
                                _ConnectionOperation.disconnect
                            ? l10n.disconnecting
                            : _connectionOperation ==
                                  _ConnectionOperation.connect
                            ? l10n.connecting
                            : _selectedDevice == null
                            ? l10n.selectDeviceFirst
                            : _selectedDevice?.connected == true
                            ? '${l10n.connected} · ${l10n.disconnectDevice}'
                            : l10n.connectDevice,
                        child: shad.IconButton(
                          key: const ValueKey<String>(
                            'connection-action-button',
                          ),
                          variance: compactConnectionStyle,
                          density: shad.ButtonDensity.iconDense,
                          size: shad.ButtonSize.small,
                          onPressed:
                              _selectedDevice == null ||
                                  _connectionOperation != null
                              ? null
                              : _toggleConnection,
                          icon: Icon(
                            _connectionOperation != null
                                ? AppIcons.syncOutlined
                                : _selectedDevice?.connected == true
                                ? AppIcons.linkOff
                                : AppIcons.bluetoothOutlined,
                          ),
                        ),
                      ),
                    if (compactToolbar)
                      ToolTooltip(
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
                            _scanning ? AppIcons.stopCircle : AppIcons.radar,
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
                        onConfigureWebServices: kIsWeb
                            ? _configureWebServices
                            : null,
                        l10n: l10n,
                      ),
                  ],
                );
              },
            ),
            const shad.Divider(height: 1),
          ],
          child: _AppWorkspaceShell(
            mode: _mode,
            onModeChanged: (mode) => setState(() => _mode = mode),
            l10n: l10n,
            characteristicsOpen: _characteristicsOpen,
            inspectorOpen: _inspectorOpen,
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
              onModeChanged: (value) {
                setState(() {
                  _hexMode = value;
                  if (value) {
                    _inputController.value = _normalizeHexEditingValue(
                      _inputController.value,
                    );
                  }
                });
              },
              directSend: _directSend,
              onDirectSendChanged: (value) =>
                  setState(() => _directSend = value),
              onSend: _sendInput,
              canSend: _selectedDevice?.connected == true && _hasWriteTarget,
              sendDisabledReason: _consoleSendDisabledReason(l10n),
              sendPreview: (String input, bool hexMode, bool directSend) =>
                  _previewConsoleSend(input, hexMode, directSend, l10n),
              writeTarget: _characteristics
                  .where((item) => item.isWriteTarget)
                  .map((item) => item.characteristicId)
                  .firstOrNull,
              characteristicsOpen: _characteristicsOpen,
              onCharacteristicsVisibilityChanged: (value) =>
                  setState(() => _characteristicsOpen = value),
              inspectorOpen: _inspectorOpen,
              onInspectorVisibilityChanged: (value) =>
                  setState(() => _inspectorOpen = value),
              l10n: l10n,
              selectedLog: _selectedLog,
              onLogSelected: (SessionLogRecord record) =>
                  setState(() => _selectedLog = record),
              logFilter: _consoleLogFilter,
              onLogFilterChanged: (value) => setState(() {
                _consoleLogFilter = value;
                _invalidateVisibleConsoleLogs();
              }),
              onSearchChanged: (_) => setState(_invalidateVisibleConsoleLogs),
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
              onSelectedLogCleared: () => setState(() => _selectedLog = null),
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
              onImportProtocolCandidate: _importProtocolCandidate,
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
