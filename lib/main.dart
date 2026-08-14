import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models/workspace.dart';
import 'models/command_definition.dart';
import 'models/protocol_profile.dart';
import 'models/script_config.dart';
import 'services/bluetooth_service.dart';
import 'services/script_engine.dart';
import 'services/workspace_manager.dart';
import 'utils/web_service_uuid_parser.dart';

void main() => runApp(const BlexpertApp());

class BlexpertApp extends StatefulWidget {
  const BlexpertApp({super.key, this.locale, this.bluetoothService});

  final Locale? locale;
  final BluetoothService? bluetoothService;

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

ThemeData _buildTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4297F5),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF111315)
        : const Color(0xFFF4F6F8),
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF1B1D1F)
          : scheme.surface,
      foregroundColor: brightness == Brightness.dark
          ? Colors.white
          : scheme.onSurface,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
  );
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
  late final WorkspaceManager _workspaceManager;
  late final BluetoothService _bluetoothService;
  late final ScriptEngineService _scriptEngine;
  late final StreamSubscription<List<BluetoothDeviceInfo>> _scanSubscription;
  late final StreamSubscription<BluetoothServiceEvent>
  _serviceEventSubscription;
  StreamSubscription<List<int>>? _dataSubscription;
  final TextEditingController _inputController = TextEditingController();

  List<BluetoothDeviceInfo> _devices = <BluetoothDeviceInfo>[];
  List<BluetoothCharacteristicInfo> _characteristics =
      <BluetoothCharacteristicInfo>[];
  final List<_LogEntry> _logs = <_LogEntry>[];
  String? _selectedDeviceId;
  bool _scanning = false;
  bool _connecting = false;
  bool _hexMode = true;
  bool _autoScroll = true;
  List<String> _webOptionalServices = <String>[];

  @override
  void initState() {
    super.initState();
    _workspaceManager = WorkspaceManager();
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

  Future<void> _watchSelectedIncomingData() async {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) {
      return;
    }
    await _dataSubscription?.cancel();
    _dataSubscription = _bluetoothService.watchIncomingData(deviceId).listen((
      List<int> payload,
    ) {
      if (!mounted) {
        return;
      }
      unawaited(_handleIncomingData(payload));
    });
  }

  Future<void> _handleIncomingData(List<int> payload) async {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    try {
      final ScriptEngineResult result = await _scriptEngine.afterReceive(
        workspace.scriptConfig,
        payload,
      );
      if (!mounted) return;
      setState(() {
        _logs.insert(0, _LogEntry(_LogKind.received, DateTime.now(), payload));
        if (!listEquals(result.bytes, payload)) {
          _logs.insert(
            0,
            _LogEntry.system(
              timestamp: DateTime.now(),
              message: '脚本解码：${_toHex(result.bytes)}',
            ),
          );
        }
        for (final String log in result.logs.reversed) {
          _logs.insert(0, _LogEntry.system(timestamp: DateTime.now(), message: log));
        }
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
    final List<String>? services = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        String? validationError;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              AlertDialog(
                title: Text(l10n.webServiceUuids),
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

  Future<void> _editActiveWorkspace() async {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final TextEditingController nameController = TextEditingController(
      text: workspace.name,
    );
    final TextEditingController modelController = TextEditingController(
      text: workspace.deviceModel,
    );
    final TextEditingController descriptionController = TextEditingController(
      text: workspace.description,
    );
    final TextEditingController tagsController = TextEditingController(
      text: workspace.tags.join(', '),
    );
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Workspace? updated = await showDialog<Workspace>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.editWorkspace),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.workspace),
                ),
                TextField(
                  controller: modelController,
                  decoration: InputDecoration(labelText: l10n.deviceModel),
                ),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: l10n.description),
                ),
                TextField(
                  controller: tagsController,
                  decoration: InputDecoration(labelText: l10n.tags),
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
              Navigator.of(context).pop(
                workspace.copyWith(
                  name: name.isEmpty ? workspace.name : name,
                  deviceModel: modelController.text.trim(),
                  description: descriptionController.text.trim(),
                  tags: tagsController.text
                      .split(',')
                      .map((String tag) => tag.trim())
                      .where((String tag) => tag.isNotEmpty)
                      .toSet()
                      .toList(growable: false),
                  updatedAt: DateTime.now(),
                ),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    nameController.dispose();
    modelController.dispose();
    descriptionController.dispose();
    tagsController.dispose();
    if (updated == null || !mounted) return;
    setState(() => _workspaceManager.upsertWorkspace(updated));
  }

  Future<void> _editProtocol() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final TextEditingController nameController = TextEditingController(
      text: workspace.protocol.name,
    );
    final TextEditingController descriptionController = TextEditingController(
      text: workspace.protocol.description,
    );
    final ProtocolDefinition? protocol = await showDialog<ProtocolDefinition>(
      context: context,
      builder: (BuildContext context) => _ProtocolEditorDialog(
        existing: workspace.protocol,
        nameController: nameController,
        descriptionController: descriptionController,
        l10n: l10n,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      descriptionController.dispose();
    });
    if (protocol == null || !mounted) return;
    setState(
      () => _workspaceManager.upsertWorkspace(
        workspace.copyWith(
          protocol: protocol,
          updatedAt: DateTime.now(),
        ),
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
    final CommandDefinition? command = await showDialog<CommandDefinition>(
      context: context,
      builder: (BuildContext context) {
        CommandPayloadFormat format =
            existing?.format ?? CommandPayloadFormat.hex;
        bool enabled = existing?.enabled ?? true;
        bool isQuickAccess = existing?.isQuickAccess ?? false;
        String? validationError;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              AlertDialog(
                title: Text(
                  existing == null ? l10n.newCommand : l10n.editCommand,
                ),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.commandName,
                          ),
                        ),
                        TextField(
                          controller: groupController,
                          decoration: InputDecoration(
                            labelText: l10n.commandGroup,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<CommandPayloadFormat>(
                          segments: <ButtonSegment<CommandPayloadFormat>>[
                            ButtonSegment(
                              value: CommandPayloadFormat.hex,
                              label: Text(l10n.commandHex),
                            ),
                            ButtonSegment(
                              value: CommandPayloadFormat.text,
                              label: Text(l10n.commandText),
                            ),
                          ],
                          selected: <CommandPayloadFormat>{format},
                          onSelectionChanged:
                              (Set<CommandPayloadFormat> values) {
                                setDialogState(() => format = values.first);
                              },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: payloadController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l10n.commandPayload,
                            errorText: validationError,
                          ),
                        ),
                        TextField(
                          controller: notesController,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: l10n.commandNotes,
                          ),
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
                      if (name.isEmpty ||
                          payload.isEmpty ||
                          (format == CommandPayloadFormat.hex &&
                              _parseHex(payload) == null)) {
                        setDialogState(
                          () => validationError = l10n.invalidCommandPayload,
                        );
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
      () => _workspaceManager.upsertWorkspace(
        workspace.copyWith(commands: commands, updatedAt: DateTime.now()),
      ),
    );
  }

  Future<void> _editScriptConfig() async {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final TextEditingController beforeSendController = TextEditingController(
      text: workspace.scriptConfig.beforeSendScript,
    );
    final TextEditingController afterReceiveController = TextEditingController(
      text: workspace.scriptConfig.afterReceiveScript,
    );
    final ScriptConfig? updated = await showDialog<ScriptConfig>(
      context: context,
      builder: (BuildContext context) {
        bool enabled = workspace.scriptConfig.enabled;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
            title: Text(l10n.scriptProtocolMode),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.scriptEnabled),
                      subtitle: Text(
                        _scriptEngine.isRuntimeAvailable
                            ? l10n.scriptEngineReady
                            : l10n.scriptEngineUnavailable,
                      ),
                      value: enabled,
                      onChanged: (bool value) => setDialogState(() => enabled = value),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          beforeSendController.text = _defaultBeforeSendScript;
                          afterReceiveController.text = _defaultAfterReceiveScript;
                        },
                        icon: const Icon(Icons.auto_fix_high_outlined),
                        label: Text(l10n.loadProtocolSample),
                      ),
                    ),
                    TextField(
                      controller: beforeSendController,
                      minLines: 14,
                      maxLines: 22,
                      decoration: InputDecoration(
                        labelText: l10n.beforeSendScript,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: afterReceiveController,
                      minLines: 14,
                      maxLines: 22,
                      decoration: InputDecoration(
                        labelText: l10n.afterReceiveScript,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
                  Navigator.of(context).pop(
                    workspace.scriptConfig.copyWith(
                      enabled: enabled,
                      beforeSendScript: beforeSendController.text,
                      afterReceiveScript: afterReceiveController.text,
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
      beforeSendController.dispose();
      afterReceiveController.dispose();
    });
    if (updated == null || !mounted) return;
    setState(
      () => _workspaceManager.upsertWorkspace(
        workspace.copyWith(scriptConfig: updated, updatedAt: DateTime.now()),
      ),
    );
  }

  void _deleteCommand(CommandDefinition command) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _workspaceManager.upsertWorkspace(
        workspace.copyWith(
          commands: workspace.commands
              .where((CommandDefinition item) => item.id != command.id)
              .toList(growable: false),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _setCommandEnabled(CommandDefinition command, bool enabled) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _workspaceManager.upsertWorkspace(
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
      () => _workspaceManager.upsertWorkspace(
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
        final characteristics = await _bluetoothService.discoverCharacteristics(
          device.id,
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
    final String modeLabel = mode == BluetoothSubscriptionMode.indicate
        ? l10n.indicate
        : l10n.notify;
    _addSystemLog(
      enabled
          ? l10n.subscriptionEnabled(modeLabel)
          : l10n.subscriptionDisabled(modeLabel),
    );
  }

  Future<void> _send(List<int> bytes) async {
    final device = _selectedDevice;
    if (device == null || !_hasWriteTarget) return;
    try {
      final Workspace workspace = _workspaceManager.activeWorkspace;
      final ScriptEngineResult result = await _scriptEngine.beforeSend(
        workspace.scriptConfig,
        bytes,
      );
      await _bluetoothService.sendData(device.id, result.bytes);
      if (!mounted) return;
      setState(() {
        _logs.insert(0, _LogEntry(_LogKind.sent, DateTime.now(), result.bytes));
        for (final String log in result.logs.reversed) {
          _logs.insert(0, _LogEntry.system(timestamp: DateTime.now(), message: log));
        }
      });
      _addSystemLog(AppLocalizations.of(context)!.dataSent(result.bytes.length));
    } catch (error) {
      _showBluetoothError(error);
    }
  }

  Future<void> _readCharacteristic(
    BluetoothCharacteristicInfo characteristic,
  ) async {
    final String? deviceId = _selectedDeviceId;
    if (deviceId == null) return;
    try {
      final List<int> value = await _bluetoothService.readData(
        deviceId,
        characteristic,
      );
      if (!mounted) return;
      setState(
        () => _logs.insert(
          0,
          _LogEntry(_LogKind.received, DateTime.now(), value),
        ),
      );
      _addSystemLog(AppLocalizations.of(context)!.dataRead(value.length));
    } catch (error) {
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
        _LogEntry.error(
          timestamp: DateTime.now(),
          message: '$message\n${error.toString()}',
        ),
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addSystemLog(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.insert(
        0,
        _LogEntry.system(timestamp: DateTime.now(), message: message),
      );
    });
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

  void _sendInput() {
    final value = _inputController.text.trim();
    if (value.isEmpty) return;
    final bytes = _hexMode ? _parseHex(value) : utf8.encode(value);
    if (bytes == null) return;
    _inputController.clear();
    unawaited(_send(bytes));
  }

  void _previewExport() {
    final jsonText = _workspaceManager.exportWorkspaces();
    final length = jsonText.length < 32 ? jsonText.length : 32;
    setState(
      () => _logs.insert(
        0,
        _LogEntry(
          _LogKind.system,
          DateTime.now(),
          utf8.encode(jsonText.substring(0, length)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = _workspaceManager.activeWorkspace;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 16,
        title: Text(
          'BLExpert',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          _WorkspaceSelector(
            workspace: workspace,
            workspaces: _workspaceManager.workspaces,
            onSelected: (String workspaceId) {
              setState(() => _workspaceManager.setActiveWorkspace(workspaceId));
            },
            l10n: l10n,
          ),
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
          if (kIsWeb)
            IconButton(
              tooltip: l10n.webServiceUuids,
              onPressed: _configureWebServices,
              icon: const Icon(Icons.tune),
            ),
          IconButton(
            tooltip: _scanning ? l10n.stopScan : l10n.startScan,
            onPressed: _toggleScan,
            icon: Icon(_scanning ? Icons.pause_circle_outline : Icons.radar),
          ),
          IconButton(
            tooltip: l10n.exportWorkspacePreview,
            onPressed: _previewExport,
            icon: const Icon(Icons.upload_file_outlined),
          ),
          _ThemeModeMenu(
            value: widget.themeMode,
            onChanged: widget.onThemeModeChanged,
          ),
          _LocaleMenu(value: widget.locale, onChanged: widget.onLocaleChanged),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final workbench = _WorkbenchPanel(
            logs: _logs,
            autoScroll: _autoScroll,
            onClear: () => setState(_logs.clear),
            onAutoScrollChanged: (value) => setState(() => _autoScroll = value),
            inputController: _inputController,
            hexMode: _hexMode,
            onModeChanged: (value) => setState(() => _hexMode = value),
            onSend: _sendInput,
            canSend: _selectedDevice?.connected == true && _hasWriteTarget,
            workspace: workspace,
            onEditWorkspace: _editActiveWorkspace,
            onEditProtocol: _editProtocol,
            onEditScriptConfig: _editScriptConfig,
            onNewCommand: () => _editCommand(),
            onEditCommand: _editCommand,
            onDeleteCommand: _deleteCommand,
            onCommandEnabledChanged: _setCommandEnabled,
            onCommandQuickAccessChanged: _setCommandQuickAccess,
            l10n: l10n,
          );
          final sidePanel = _DeviceWorkbenchPanel(
            characteristics: _characteristics,
            connected: _selectedDevice?.connected == true,
            canSend: _hasWriteTarget,
            onSelectWrite: _setWriteCharacteristic,
            onSubscriptionChanged: _setSubscription,
            onRead: _readCharacteristic,
            onSend: _send,
            commands: workspace.commands,
            logs: _logs,
            l10n: l10n,
          );
          if (wide) {
            return Row(
              children: <Widget>[
                Expanded(flex: 7, child: workbench),
                const VerticalDivider(width: 1),
                SizedBox(width: 390, child: sidePanel),
              ],
            );
          }
          return ListView(
            children: <Widget>[
              SizedBox(height: 620, child: workbench),
              SizedBox(height: 560, child: sidePanel),
            ],
          );
        },
      ),
    );
  }
}

class _WorkspaceSelector extends StatelessWidget {
  const _WorkspaceSelector({
    required this.workspace,
    required this.workspaces,
    required this.onSelected,
    required this.l10n,
  });
  final Workspace workspace;
  final List<Workspace> workspaces;
  final ValueChanged<String> onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: l10n.selectWorkspace,
      onSelected: onSelected,
      itemBuilder: (_) => workspaces
          .map((item) => PopupMenuItem(value: item.id, child: Text(item.name)))
          .toList(),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DropdownButtonHideUnderline(
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
        const SizedBox(width: 4),
        IconButton.filled(
          tooltip: connecting
              ? l10n.connecting
              : connected
              ? l10n.disconnectDevice
              : l10n.connectDevice,
          onPressed: device == null || connecting ? null : onToggleConnection,
          icon: connecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(connected ? Icons.link_off : Icons.play_arrow),
        ),
      ],
    );
  }
}

class _WorkbenchPanel extends StatelessWidget {
  const _WorkbenchPanel({
    required this.logs,
    required this.autoScroll,
    required this.onClear,
    required this.onAutoScrollChanged,
    required this.inputController,
    required this.hexMode,
    required this.onModeChanged,
    required this.onSend,
    required this.canSend,
    required this.workspace,
    required this.onEditWorkspace,
    required this.onEditProtocol,
    required this.onEditScriptConfig,
    required this.onNewCommand,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onCommandEnabledChanged,
    required this.onCommandQuickAccessChanged,
    required this.l10n,
  });

  final List<_LogEntry> logs;
  final bool autoScroll;
  final VoidCallback onClear;
  final ValueChanged<bool> onAutoScrollChanged;
  final TextEditingController inputController;
  final bool hexMode;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSend;
  final bool canSend;
  final Workspace workspace;
  final VoidCallback onEditWorkspace;
  final VoidCallback onEditProtocol;
  final VoidCallback onEditScriptConfig;
  final VoidCallback onNewCommand;
  final ValueChanged<CommandDefinition> onEditCommand;
  final ValueChanged<CommandDefinition> onDeleteCommand;
  final void Function(CommandDefinition, bool) onCommandEnabledChanged;
  final void Function(CommandDefinition, bool) onCommandQuickAccessChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: <Widget>[
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: TabBar(
              tabs: <Tab>[
                Tab(
                  icon: const Icon(Icons.terminal_outlined),
                  text: l10n.communication,
                ),
                Tab(
                  icon: const Icon(Icons.settings_outlined),
                  text: l10n.workspaceSettings,
                ),
                Tab(
                  icon: const Icon(Icons.account_tree_outlined),
                  text: l10n.protocolProfiles,
                ),
                Tab(
                  icon: const Icon(Icons.code_outlined),
                  text: l10n.scriptProtocolMode,
                ),
                Tab(
                  icon: const Icon(Icons.list_alt_outlined),
                  text: l10n.commandLibrary,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _ConsoleArea(
                  logs: logs,
                  autoScroll: autoScroll,
                  onClear: onClear,
                  onAutoScrollChanged: onAutoScrollChanged,
                  inputController: inputController,
                  hexMode: hexMode,
                  onModeChanged: onModeChanged,
                  onSend: onSend,
                  canSend: canSend,
                  l10n: l10n,
                ),
                _WorkspaceOverview(
                  workspace: workspace,
                  onEdit: onEditWorkspace,
                  l10n: l10n,
                ),
                _ProtocolLibraryPanel(
                  protocol: workspace.protocol,
                  onEditProtocol: onEditProtocol,
                  l10n: l10n,
                ),
                _ScriptLibraryPanel(
                  scriptConfig: workspace.scriptConfig,
                  onEdit: onEditScriptConfig,
                  runtimeAvailable: !kIsWeb,
                  l10n: l10n,
                ),
                _CommandLibraryPanel(
                  commands: workspace.commands,
                  onNewCommand: onNewCommand,
                  onEditCommand: onEditCommand,
                  onDeleteCommand: onDeleteCommand,
                  onEnabledChanged: onCommandEnabledChanged,
                  onQuickAccessChanged: onCommandQuickAccessChanged,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceOverview extends StatelessWidget {
  const _WorkspaceOverview({
    required this.workspace,
    required this.onEdit,
    required this.l10n,
  });

  final Workspace workspace;
  final VoidCallback onEdit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                workspace.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l10n.editWorkspace,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WorkspaceField(label: l10n.deviceModel, value: workspace.deviceModel),
        _WorkspaceField(label: l10n.description, value: workspace.description),
        _WorkspaceField(
          label: l10n.tags,
          value: workspace.tags.isEmpty ? l10n.none : workspace.tags.join(', '),
        ),
        _WorkspaceField(
          label: l10n.workspaceDevices,
          value: '${workspace.devices.length}',
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

class _ProtocolLibraryPanel extends StatelessWidget {
  const _ProtocolLibraryPanel({
    required this.protocol,
    required this.onEditProtocol,
    required this.l10n,
  });

  final ProtocolDefinition protocol;
  final VoidCallback onEditProtocol;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.protocolProfiles,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l10n.editProtocol,
              onPressed: onEditProtocol,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (protocol.name.isEmpty &&
            protocol.sendSegments.isEmpty &&
            protocol.receiveSegments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text(l10n.noProtocolProfiles)),
          )
        else ...<Widget>[
          Text(protocol.name.isEmpty ? '-' : protocol.name),
          if (protocol.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(protocol.description, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 14),
          _ProtocolSectionSummary(
            title: l10n.sendFrame,
            segments: protocol.sendSegments,
            l10n: l10n,
          ),
          const SizedBox(height: 12),
          _ProtocolSectionSummary(
            title: l10n.receiveFrame,
            segments: protocol.receiveSegments,
            l10n: l10n,
          ),
        ],
      ],
    );
  }
}

class _ProtocolSectionSummary extends StatelessWidget {
  const _ProtocolSectionSummary({
    required this.title,
    required this.segments,
    required this.l10n,
  });

  final String title;
  final List<ProtocolSegment> segments;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        if (segments.isEmpty)
          Text('-', style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: segments
                .map(
                  (ProtocolSegment segment) => _CapabilityChip(
                    label: _segmentSummary(segment, l10n),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

String _segmentSummary(ProtocolSegment segment, AppLocalizations l10n) {
  return switch (segment.type) {
    ProtocolSegmentType.fixedHex =>
      '${segment.label.isEmpty ? l10n.fixedHexSegment : segment.label}: ${segment.fixedHex.isEmpty ? '-' : segment.fixedHex}',
    ProtocolSegmentType.payload =>
      segment.label.isEmpty ? l10n.payloadSegment : segment.label,
    ProtocolSegmentType.length =>
      '${segment.label.isEmpty ? l10n.lengthField : segment.label} ${segment.byteLength ?? 1}B',
    ProtocolSegmentType.sequence =>
      '${segment.label.isEmpty ? l10n.sequenceField : segment.label} ${segment.byteLength ?? 1}B',
    ProtocolSegmentType.checksum =>
      '${segment.label.isEmpty ? l10n.checksumField : segment.label} ${_checksumLabel(segment.checksumAlgorithm ?? ProtocolChecksumAlgorithm.crc16Modbus, l10n)}',
  };
}

class _ProtocolEditorDialog extends StatefulWidget {
  const _ProtocolEditorDialog({
    required this.existing,
    required this.nameController,
    required this.descriptionController,
    required this.l10n,
  });

  final ProtocolDefinition existing;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final AppLocalizations l10n;

  @override
  State<_ProtocolEditorDialog> createState() => _ProtocolEditorDialogState();
}

class _ProtocolEditorDialogState extends State<_ProtocolEditorDialog> {
  late List<ProtocolSegment> _sendSegments;
  late List<ProtocolSegment> _receiveSegments;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _sendSegments = List<ProtocolSegment>.from(widget.existing.sendSegments);
    _receiveSegments = List<ProtocolSegment>.from(widget.existing.receiveSegments);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.l10n.editProtocol,
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: widget.nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: widget.l10n.protocolName),
              ),
              TextField(
                controller: widget.descriptionController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(labelText: widget.l10n.description),
              ),
              const SizedBox(height: 14),
              _ProtocolSegmentSection(
                title: widget.l10n.sendFrame,
                segments: _sendSegments,
                l10n: widget.l10n,
                onChanged: (List<ProtocolSegment> value) {
                  setState(() => _sendSegments = value);
                },
              ),
              const Divider(height: 28),
              _ProtocolSegmentSection(
                title: widget.l10n.receiveFrame,
                segments: _receiveSegments,
                l10n: widget.l10n,
                onChanged: (List<ProtocolSegment> value) {
                  setState(() => _receiveSegments = value);
                },
              ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _validationError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final String name = widget.nameController.text.trim();
            if (name.isEmpty ||
                !_validSegments(_sendSegments) ||
                !_validSegments(_receiveSegments)) {
              setState(() => _validationError = widget.l10n.invalidProtocol);
              return;
            }
            Navigator.of(context).pop(
              ProtocolDefinition(
                name: name,
                description: widget.descriptionController.text.trim(),
                sendSegments: List<ProtocolSegment>.unmodifiable(_sendSegments),
                receiveSegments: List<ProtocolSegment>.unmodifiable(_receiveSegments),
              ),
            );
          },
          child: Text(widget.l10n.save),
        ),
      ],
    );
  }
}

class _ScriptLibraryPanel extends StatelessWidget {
  const _ScriptLibraryPanel({
    required this.scriptConfig,
    required this.onEdit,
    required this.runtimeAvailable,
    required this.l10n,
  });

  final ScriptConfig scriptConfig;
  final VoidCallback onEdit;
  final bool runtimeAvailable;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.scriptProtocolMode,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l10n.editScriptConfig,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WorkspaceField(
          label: l10n.scriptEnabled,
          value: scriptConfig.enabled ? l10n.enabledState : l10n.disabledState,
        ),
        _WorkspaceField(
          label: l10n.scriptRuntime,
          value: runtimeAvailable ? l10n.scriptEngineReady : l10n.scriptEngineUnavailable,
        ),
        _WorkspaceField(
          label: l10n.beforeSendScript,
          value: scriptConfig.beforeSendScript.trim().isEmpty
              ? l10n.none
              : scriptConfig.beforeSendScript.split('\n').first,
        ),
        _WorkspaceField(
          label: l10n.afterReceiveScript,
          value: scriptConfig.afterReceiveScript.trim().isEmpty
              ? l10n.none
              : scriptConfig.afterReceiveScript.split('\n').first,
        ),
      ],
    );
  }
}

class _ProtocolSegmentSection extends StatelessWidget {
  const _ProtocolSegmentSection({
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
            IconButton(
              tooltip: l10n.newProtocolSegment,
              onPressed: () async {
                final ProtocolSegment? segment = await _showSegmentDialog(
                  context,
                  l10n,
                );
                if (segment == null) return;
                onChanged(<ProtocolSegment>[...segments, segment]);
              },
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (segments.isEmpty)
          Text(l10n.noProtocolSegments, style: Theme.of(context).textTheme.bodySmall)
        else
          ...List<Widget>.generate(segments.length, (int index) {
            final ProtocolSegment segment = segments[index];
            return _ProtocolSegmentTile(
              segment: segment,
              canMoveUp: index > 0,
              canMoveDown: index < segments.length - 1,
              l10n: l10n,
              onMoveUp: () {
                final List<ProtocolSegment> updated = List<ProtocolSegment>.from(segments);
                final ProtocolSegment item = updated.removeAt(index);
                updated.insert(index - 1, item);
                onChanged(updated);
              },
              onMoveDown: () {
                final List<ProtocolSegment> updated = List<ProtocolSegment>.from(segments);
                final ProtocolSegment item = updated.removeAt(index);
                updated.insert(index + 1, item);
                onChanged(updated);
              },
              onDelete: () {
                final List<ProtocolSegment> updated = List<ProtocolSegment>.from(segments)
                  ..removeAt(index);
                onChanged(updated);
              },
              onEdit: () async {
                final ProtocolSegment? updatedSegment = await _showSegmentDialog(
                  context,
                  l10n,
                  existing: segment,
                );
                if (updatedSegment == null) return;
                final List<ProtocolSegment> updated = List<ProtocolSegment>.from(segments);
                updated[index] = updatedSegment;
                onChanged(updated);
              },
            );
          }),
      ],
    );
  }
}

class _ProtocolSegmentTile extends StatelessWidget {
  const _ProtocolSegmentTile({
    required this.segment,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.l10n,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onEdit,
  });

  final ProtocolSegment segment;
  final bool canMoveUp;
  final bool canMoveDown;
  final AppLocalizations l10n;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(segment.label.isEmpty ? _segmentTypeLabel(segment.type, l10n) : segment.label),
                  const SizedBox(height: 2),
                  Text(
                    _segmentSummary(segment, l10n),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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
            tooltip: l10n.editProtocol,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
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

String _checksumLabel(ProtocolChecksumAlgorithm algorithm, AppLocalizations l10n) =>
    switch (algorithm) {
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

bool _validSegments(List<ProtocolSegment> segments) {
  if (segments.isEmpty) {
    return false;
  }
  final int payloadCount = segments
      .where((ProtocolSegment segment) => segment.type == ProtocolSegmentType.payload)
      .length;
  if (payloadCount != 1) {
    return false;
  }
  for (final ProtocolSegment segment in segments) {
    if (segment.type == ProtocolSegmentType.fixedHex && _parseHex(segment.fixedHex) == null) {
      return false;
    }
    if ((segment.type == ProtocolSegmentType.length ||
            segment.type == ProtocolSegmentType.sequence) &&
        (segment.byteLength == null || segment.byteLength! <= 0)) {
      return false;
    }
    if (segment.type == ProtocolSegmentType.checksum && segment.checksumAlgorithm == null) {
      return false;
    }
  }
  return true;
}

Future<ProtocolSegment?> _showSegmentDialog(
  BuildContext context,
  AppLocalizations l10n, {
  ProtocolSegment? existing,
}) async {
  final TextEditingController labelController = TextEditingController(
    text: existing?.label ?? '',
  );
  final TextEditingController fixedHexController = TextEditingController(
    text: existing?.fixedHex ?? '',
  );
  final TextEditingController byteLengthController = TextEditingController(
    text: existing?.byteLength?.toString() ?? '',
  );
  final ProtocolSegment? result = await showDialog<ProtocolSegment>(
    context: context,
    builder: (BuildContext context) {
      ProtocolSegmentType type = existing?.type ?? ProtocolSegmentType.fixedHex;
      ProtocolByteOrder byteOrder = existing?.byteOrder ?? ProtocolByteOrder.littleEndian;
      ProtocolChecksumAlgorithm checksum =
          existing?.checksumAlgorithm ?? ProtocolChecksumAlgorithm.crc16Modbus;
      ProtocolCalculationRange range =
          existing?.calculationRange ?? ProtocolCalculationRange.payloadOnly;
      String? validationError;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: Text(existing == null ? l10n.newProtocolSegment : l10n.editProtocolSegment),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<ProtocolSegmentType>(
                    initialValue: type,
                    decoration: InputDecoration(labelText: l10n.segmentType),
                    items: ProtocolSegmentType.values
                        .map(
                          (ProtocolSegmentType item) => DropdownMenuItem<ProtocolSegmentType>(
                            value: item,
                            child: Text(_segmentTypeLabel(item, l10n)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (ProtocolSegmentType? value) {
                      if (value != null) {
                        setDialogState(() {
                          type = value;
                          validationError = null;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(labelText: l10n.segmentLabel),
                  ),
                  if (type == ProtocolSegmentType.fixedHex)
                    TextField(
                      controller: fixedHexController,
                      decoration: InputDecoration(
                        labelText: l10n.fixedHexSegment,
                        errorText: validationError,
                      ),
                    ),
                  if (type == ProtocolSegmentType.length || type == ProtocolSegmentType.sequence) ...<Widget>[
                    TextField(
                      controller: byteLengthController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.fieldByteLength,
                        errorText: validationError,
                      ),
                    ),
                    DropdownButtonFormField<ProtocolByteOrder>(
                      initialValue: byteOrder,
                      decoration: InputDecoration(labelText: l10n.byteOrder),
                      items: ProtocolByteOrder.values
                          .map(
                            (ProtocolByteOrder item) => DropdownMenuItem<ProtocolByteOrder>(
                              value: item,
                              child: Text(_byteOrderLabel(item, l10n)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (ProtocolByteOrder? value) {
                        if (value != null) setDialogState(() => byteOrder = value);
                      },
                    ),
                  ],
                  if (type == ProtocolSegmentType.length || type == ProtocolSegmentType.checksum)
                    DropdownButtonFormField<ProtocolCalculationRange>(
                      initialValue: range,
                      decoration: InputDecoration(labelText: l10n.calculationRange),
                      items: ProtocolCalculationRange.values
                          .map(
                            (ProtocolCalculationRange item) => DropdownMenuItem<ProtocolCalculationRange>(
                              value: item,
                              child: Text(_calculationRangeLabel(item, l10n)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (ProtocolCalculationRange? value) {
                        if (value != null) setDialogState(() => range = value);
                      },
                    ),
                  if (type == ProtocolSegmentType.checksum) ...<Widget>[
                    DropdownButtonFormField<ProtocolChecksumAlgorithm>(
                      initialValue: checksum,
                      decoration: InputDecoration(labelText: l10n.checksumAlgorithm),
                      items: ProtocolChecksumAlgorithm.values
                          .map(
                            (ProtocolChecksumAlgorithm item) => DropdownMenuItem<ProtocolChecksumAlgorithm>(
                              value: item,
                              child: Text(_checksumLabel(item, l10n)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (ProtocolChecksumAlgorithm? value) {
                        if (value != null) setDialogState(() => checksum = value);
                      },
                    ),
                    DropdownButtonFormField<ProtocolByteOrder>(
                      initialValue: byteOrder,
                      decoration: InputDecoration(labelText: l10n.byteOrder),
                      items: ProtocolByteOrder.values
                          .map(
                            (ProtocolByteOrder item) => DropdownMenuItem<ProtocolByteOrder>(
                              value: item,
                              child: Text(_byteOrderLabel(item, l10n)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (ProtocolByteOrder? value) {
                        if (value != null) setDialogState(() => byteOrder = value);
                      },
                    ),
                  ],
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
                final String label = labelController.text.trim();
                final int? byteLength = int.tryParse(byteLengthController.text.trim());
                if (type == ProtocolSegmentType.fixedHex && _parseHex(fixedHexController.text.trim()) == null) {
                  setDialogState(() => validationError = l10n.invalidProtocolSegment);
                  return;
                }
                if ((type == ProtocolSegmentType.length || type == ProtocolSegmentType.sequence) &&
                    (byteLength == null || byteLength <= 0)) {
                  setDialogState(() => validationError = l10n.invalidProtocolSegment);
                  return;
                }
                Navigator.of(context).pop(
                  ProtocolSegment(
                    id: existing?.id ?? 'segment-${DateTime.now().microsecondsSinceEpoch}',
                    type: type,
                    label: label,
                    byteLength: (type == ProtocolSegmentType.length || type == ProtocolSegmentType.sequence)
                        ? byteLength
                        : null,
                    byteOrder: (type == ProtocolSegmentType.length ||
                            type == ProtocolSegmentType.sequence ||
                            type == ProtocolSegmentType.checksum)
                        ? byteOrder
                        : null,
                    fixedHex: type == ProtocolSegmentType.fixedHex
                        ? fixedHexController.text.trim()
                        : '',
                    checksumAlgorithm: type == ProtocolSegmentType.checksum ? checksum : null,
                    calculationRange: (type == ProtocolSegmentType.length ||
                            type == ProtocolSegmentType.checksum)
                        ? range
                        : null,
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
    labelController.dispose();
    fixedHexController.dispose();
    byteLengthController.dispose();
  });
  return result;
}

class _CommandLibraryPanel extends StatelessWidget {
  const _CommandLibraryPanel({
    required this.commands,
    required this.onNewCommand,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onEnabledChanged,
    required this.onQuickAccessChanged,
    required this.l10n,
  });

  final List<CommandDefinition> commands;
  final VoidCallback onNewCommand;
  final ValueChanged<CommandDefinition> onEditCommand;
  final ValueChanged<CommandDefinition> onDeleteCommand;
  final void Function(CommandDefinition, bool) onEnabledChanged;
  final void Function(CommandDefinition, bool) onQuickAccessChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(5),
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

class _ConsoleArea extends StatelessWidget {
  const _ConsoleArea({
    required this.logs,
    required this.autoScroll,
    required this.onClear,
    required this.onAutoScrollChanged,
    required this.inputController,
    required this.hexMode,
    required this.onModeChanged,
    required this.onSend,
    required this.canSend,
    required this.l10n,
  });
  final List<_LogEntry> logs;
  final bool autoScroll;
  final VoidCallback onClear;
  final ValueChanged<bool> onAutoScrollChanged;
  final TextEditingController inputController;
  final bool hexMode;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSend;
  final bool canSend;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: <Widget>[
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF191B1D) : null,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: <Widget>[
              Text(
                l10n.console,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.clear,
                onPressed: onClear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 19),
              ),
              Switch.adaptive(
                value: autoScroll,
                onChanged: onAutoScrollChanged,
              ),
              Text(
                l10n.autoScroll,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: dark
                ? const Color(0xFF101112)
                : Theme.of(context).colorScheme.surface,
            child: ListView.builder(
              reverse: false,
              padding: const EdgeInsets.all(14),
              itemCount: logs.length,
              itemBuilder: (_, index) {
                final entry = logs[logs.length - index - 1];
                return _LogLine(entry: entry, l10n: l10n);
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF191B1D) : null,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            children: <Widget>[
              TextField(
                controller: inputController,
                minLines: 2,
                maxLines: 4,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: l10n.inputPlaceholder,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  ChoiceChip(
                    label: Text(l10n.textMode),
                    selected: !hexMode,
                    onSelected: (_) => onModeChanged(false),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(l10n.hexMode),
                    selected: hexMode,
                    onSelected: (_) => onModeChanged(true),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.lineEnding),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: 'none',
                    underline: const SizedBox(),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'none', child: Text(l10n.none)),
                      DropdownMenuItem(value: 'lf', child: Text(l10n.lf)),
                      DropdownMenuItem(value: 'crlf', child: Text(l10n.crlf)),
                    ],
                    onChanged: (_) {},
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: canSend ? onSend : null,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(l10n.sendData),
                  ),
                ],
              ),
            ],
          ),
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

class _DeviceWorkbenchPanel extends StatelessWidget {
  const _DeviceWorkbenchPanel({
    required this.characteristics,
    required this.connected,
    required this.canSend,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onRead,
    required this.onSend,
    required this.commands,
    required this.logs,
    required this.l10n,
  });

  final List<BluetoothCharacteristicInfo> characteristics;
  final bool connected;
  final bool canSend;
  final Future<void> Function(BluetoothCharacteristicInfo) onSelectWrite;
  final Future<void> Function(
    BluetoothCharacteristicInfo,
    BluetoothSubscriptionMode,
    bool,
  )
  onSubscriptionChanged;
  final Future<void> Function(BluetoothCharacteristicInfo) onRead;
  final Future<void> Function(List<int>) onSend;
  final List<CommandDefinition> commands;
  final List<_LogEntry> logs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Tab>[
                Tab(
                  icon: const Icon(Icons.bluetooth_searching),
                  text: l10n.characteristics,
                ),
                Tab(
                  icon: const Icon(Icons.bolt_outlined),
                  text: l10n.quickCommands,
                ),
                Tab(
                  icon: const Icon(Icons.insights_outlined),
                  text: l10n.dataView,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _DeviceToolsPanel(
                  characteristics: characteristics,
                  connected: connected,
                  onSelectWrite: onSelectWrite,
                  onSubscriptionChanged: onSubscriptionChanged,
                  onRead: onRead,
                  l10n: l10n,
                ),
                _QuickCommandsPanel(
                  canSend: canSend,
                  onSend: onSend,
                  commands: commands,
                  l10n: l10n,
                ),
                _DataSummaryPanel(logs: logs, l10n: l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceToolsPanel extends StatelessWidget {
  const _DeviceToolsPanel({
    required this.characteristics,
    required this.connected,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onRead,
    required this.l10n,
  });

  final List<BluetoothCharacteristicInfo> characteristics;
  final bool connected;
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
    final Map<String, List<BluetoothCharacteristicInfo>> byService =
        <String, List<BluetoothCharacteristicInfo>>{};
    for (final BluetoothCharacteristicInfo characteristic in characteristics) {
      byService
          .putIfAbsent(
            characteristic.serviceId,
            () => <BluetoothCharacteristicInfo>[],
          )
          .add(characteristic);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                l10n.characteristics,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connected ? l10n.connected : l10n.disconnected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!connected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.connectToDiscoverCharacteristics),
            )
          else if (characteristics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.noCharacteristics),
            )
          else
            ...byService.entries.expand(
              (MapEntry<String, List<BluetoothCharacteristicInfo>> entry) =>
                  <Widget>[
                    const Divider(height: 20),
                    Text(
                      _serviceTitle(entry.key, l10n),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...entry.value.map(
                      (BluetoothCharacteristicInfo characteristic) =>
                          _CharacteristicTile(
                            characteristic: characteristic,
                            onSelectWrite: onSelectWrite,
                            onSubscriptionChanged: onSubscriptionChanged,
                            onRead: onRead,
                            l10n: l10n,
                          ),
                    ),
                  ],
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
  final Future<void> Function(List<int>) onSend;
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

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.command,
    required this.canSend,
    required this.onSend,
    required this.l10n,
  });

  final CommandDefinition command;
  final bool canSend;
  final Future<void> Function(List<int>) onSend;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<int>? bytes = command.format == CommandPayloadFormat.hex
        ? _parseHex(command.payload)
        : utf8.encode(command.payload);
    final bool sendEnabled = canSend && command.enabled && bytes != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    command.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    command.payload,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          IconButton.filled(
            tooltip: l10n.sendCommand,
            onPressed: sendEnabled ? () => onSend(bytes) : null,
            icon: const Icon(Icons.send_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DataSummaryPanel extends StatelessWidget {
  const _DataSummaryPanel({required this.logs, required this.l10n});
  final List<_LogEntry> logs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final int sent = logs.where((entry) => entry.kind == _LogKind.sent).length;
    final int received = logs
        .where((entry) => entry.kind == _LogKind.received)
        .length;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.dataView,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _PacketCount(
                  label: l10n.sentPackets,
                  count: sent,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PacketCount(
                  label: l10n.receivedPackets,
                  count: received,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (sent + received == 0)
            Expanded(child: Center(child: Text(l10n.noPacketData)))
          else
            Expanded(
              child: ListView(
                children: logs
                    .where(
                      (entry) =>
                          entry.kind == _LogKind.sent ||
                          entry.kind == _LogKind.received,
                    )
                    .take(12)
                    .map((entry) => _LogLine(entry: entry, l10n: l10n))
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _PacketCount extends StatelessWidget {
  const _PacketCount({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text('$count', style: Theme.of(context).textTheme.headlineSmall),
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
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_characteristicTitle(characteristic.characteristicId, l10n)
                case final String title?)
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            Text(
              characteristic.characteristicId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                if (characteristic.canWrite)
                  _CapabilityChip(label: l10n.writeWithResponse),
                if (characteristic.canWriteWithoutResponse)
                  _CapabilityChip(label: l10n.writeWithoutResponse),
                if (characteristic.canRead) _CapabilityChip(label: l10n.read),
                if (characteristic.canNotify)
                  _CapabilityChip(label: l10n.notify),
                if (characteristic.canIndicate)
                  _CapabilityChip(label: l10n.indicate),
              ],
            ),
            if (characteristic.canRead ||
                characteristic.canWrite ||
                characteristic.canWriteWithoutResponse ||
                characteristic.canSubscribe)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    if (characteristic.canRead)
                      OutlinedButton.icon(
                        onPressed: () => onRead(characteristic),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: Text(l10n.readValue),
                      ),
                    if (characteristic.canWrite ||
                        characteristic.canWriteWithoutResponse)
                      ChoiceChip(
                        label: Text(l10n.writeTarget),
                        selected: characteristic.isWriteTarget,
                        onSelected: (_) => onSelectWrite(characteristic),
                      ),
                    if (characteristic.canNotify)
                      FilterChip(
                        label: Text(l10n.notify),
                        selected:
                            characteristic.isSubscribed &&
                            characteristic.subscriptionMode ==
                                BluetoothSubscriptionMode.notify,
                        onSelected: (bool selected) => onSubscriptionChanged(
                          characteristic,
                          BluetoothSubscriptionMode.notify,
                          selected,
                        ),
                      ),
                    if (characteristic.canIndicate)
                      FilterChip(
                        label: Text(l10n.indicate),
                        selected:
                            characteristic.isSubscribed &&
                            characteristic.subscriptionMode ==
                                BluetoothSubscriptionMode.indicate,
                        onSelected: (bool selected) => onSubscriptionChanged(
                          characteristic,
                          BluetoothSubscriptionMode.indicate,
                          selected,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry, required this.l10n});
  final _LogEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (entry.kind) {
      _LogKind.received => Colors.lightBlueAccent,
      _LogKind.sent => Colors.lightGreenAccent,
      _LogKind.system => Theme.of(context).colorScheme.secondary,
      _LogKind.error => Theme.of(context).colorScheme.error,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '${entry.timestamp.toIso8601String()}  ',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 11,
              ),
            ),
            TextSpan(
              text: '${entry.directionLabel(l10n)}  ',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: entry.message ?? _toHex(entry.data),
              style: TextStyle(
                fontFamily: 'monospace',
                color: entry.kind == _LogKind.error ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LogKind { sent, received, system, error }

class _LogEntry {
  const _LogEntry(this.kind, this.timestamp, this.data) : message = null;
  const _LogEntry.system({required this.timestamp, required this.message})
    : kind = _LogKind.system,
      data = const <int>[];
  const _LogEntry.error({required this.timestamp, required this.message})
    : kind = _LogKind.error,
      data = const <int>[];

  final _LogKind kind;
  final DateTime timestamp;
  final List<int> data;
  final String? message;

  String directionLabel(AppLocalizations l10n) => switch (kind) {
    _LogKind.received => l10n.received,
    _LogKind.sent => l10n.sendData,
    _LogKind.system => l10n.system,
    _LogKind.error => l10n.error,
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

class _ThemeModeMenu extends StatelessWidget {
  const _ThemeModeMenu({required this.value, required this.onChanged});
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<ThemeMode>(
      tooltip: l10n.themeMode,
      initialValue: value,
      onSelected: onChanged,
      icon: Icon(_themeModeIcon(value)),
      itemBuilder: (_) => <PopupMenuEntry<ThemeMode>>[
        PopupMenuItem(value: ThemeMode.system, child: Text(l10n.followSystem)),
        PopupMenuItem(value: ThemeMode.light, child: Text(l10n.lightMode)),
        PopupMenuItem(value: ThemeMode.dark, child: Text(l10n.darkMode)),
      ],
    );
  }
}

class _LocaleMenu extends StatelessWidget {
  const _LocaleMenu({required this.value, required this.onChanged});
  final Locale? value;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<_LocaleSelection>(
      tooltip: l10n.language,
      onSelected: (selection) => onChanged(switch (selection) {
        _LocaleSelection.system => null,
        _LocaleSelection.chinese => const Locale('zh'),
        _LocaleSelection.english => const Locale('en'),
      }),
      icon: const Icon(Icons.language_outlined),
      itemBuilder: (_) => <PopupMenuEntry<_LocaleSelection>>[
        PopupMenuItem(
          value: _LocaleSelection.system,
          child: Text(l10n.followSystem),
        ),
        PopupMenuItem(
          value: _LocaleSelection.chinese,
          child: Text(l10n.chinese),
        ),
        PopupMenuItem(
          value: _LocaleSelection.english,
          child: Text(l10n.english),
        ),
      ],
    );
  }
}

enum _LocaleSelection { system, chinese, english }

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
