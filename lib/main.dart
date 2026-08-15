import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models/workspace.dart';
import 'models/command_definition.dart';
import 'models/data_mapping.dart';
import 'models/protocol_profile.dart';
import 'models/script_config.dart';
import 'services/bluetooth_service.dart';
import 'services/script_engine.dart';
import 'services/command_payload_encoder.dart';
import 'services/data_mapper.dart';
import 'services/workspace_manager.dart';
import 'utils/ascii_utils.dart';
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
  final Map<String, _MonitoredFieldValue> _monitoredValues =
      <String, _MonitoredFieldValue>{};
  String? _selectedDeviceId;
  bool _scanning = false;
  bool _connecting = false;
  bool _hexMode = true;
  bool _autoScroll = true;
  List<String> _webOptionalServices = <String>[];
  Future<void> _saveWorkspaceChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _workspaceManager = WorkspaceManager();
    unawaited(_restoreWorkspaces());
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
      final List<int> decodedPayload = result.bytes;
      final String? commandHex =
          result.cmdHex ??
          (decodedPayload.isEmpty
              ? null
              : decodedPayload.first.toRadixString(16).padLeft(2, '0'));
      final String dataHex =
          result.dataHex ??
          (decodedPayload.length < 2 ? '' : _toHex(decodedPayload.sublist(1)));
      final ParsedResponse? parsed = result.valid == false || commandHex == null
          ? null
          : DataMapper.tryParse(
              mappings: workspace.responseMappings,
              commandHex: commandHex,
              dataHex: dataHex,
            );
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
          _logs.insert(
            0,
            _LogEntry.system(timestamp: DateTime.now(), message: log),
          );
        }
        if (parsed != null) {
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
            _LogEntry.system(
              timestamp: DateTime.now(),
              message: _formatParsedResponseLog(
                parsed,
                AppLocalizations.of(context)!,
              ),
            ),
          );
          if (parsed.mapping.asciiLogEnabled) {
            final String ascii = printableAscii(
              _parseHex(parsed.dataHex) ?? const <int>[],
            );
            if (ascii.isNotEmpty) {
              _logs.insert(
                0,
                _LogEntry.system(
                  timestamp: DateTime.now(),
                  message: AppLocalizations.of(
                    context,
                  )!.asciiDecodedLog(parsed.mapping.name, ascii),
                ),
              );
            }
          }
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
    setState(() => _upsertWorkspace(updated));
  }

  void _updateProtocol(ProtocolDefinition protocol) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(protocol: protocol, updatedAt: DateTime.now()),
      ),
    );
  }

  void _updateScriptConfig(ScriptConfig scriptConfig) {
    final Workspace workspace = _workspaceManager.activeWorkspace;
    setState(
      () => _upsertWorkspace(
        workspace.copyWith(
          scriptConfig: scriptConfig,
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
        final List<CommandParameter> parameters = <CommandParameter>[
          ...?existing?.parameters,
        ];
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
                      final String validationPayload = payload.replaceAll(
                        RegExp(r'\{\{\s*[A-Za-z_][A-Za-z0-9_]*\s*\}\}'),
                        '00',
                      );
                      if (name.isEmpty ||
                          payload.isEmpty ||
                          (format == CommandPayloadFormat.hex &&
                              _parseHex(validationPayload) == null) ||
                          parameters.any(
                            (CommandParameter parameter) =>
                                parameter.key.trim().isEmpty ||
                                !payload.contains('{{${parameter.key.trim()}}'),
                          )) {
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

  Future<void> _sendCommandDefinition(
    CommandDefinition command,
    Map<String, String> values,
  ) async {
    try {
      final List<int> bytes = CommandPayloadEncoder.encode(command, values);
      _addSystemLog(
        _formatCommandSendLog(command, values, AppLocalizations.of(context)!),
      );
      await _send(bytes);
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
    final ResponseMapping? mapping = await showDialog<ResponseMapping>(
      context: context,
      builder: (BuildContext context) {
        final List<DataField> fields = <DataField>[...?existing?.fields];
        bool asciiLogEnabled = existing?.asciiLogEnabled ?? false;
        String? validationError;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) =>
              AlertDialog(
                title: Text(
                  existing == null
                      ? AppLocalizations.of(context)!.newResponseMapping
                      : AppLocalizations.of(context)!.editResponseMapping,
                ),
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
          _logs.insert(
            0,
            _LogEntry.system(timestamp: DateTime.now(), message: log),
          );
        }
      });
      _addSystemLog(
        AppLocalizations.of(context)!.dataSent(result.bytes.length),
      );
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
      await _handleIncomingData(value);
      if (!mounted) return;
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
              setState(() {
                _workspaceManager.setActiveWorkspace(workspaceId);
                _persistWorkspaces();
              });
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
            onProtocolChanged: _updateProtocol,
            onScriptConfigChanged: _updateScriptConfig,
            onNewCommand: () => _editCommand(),
            onEditCommand: _editCommand,
            onDeleteCommand: _deleteCommand,
            onCommandEnabledChanged: _setCommandEnabled,
            onCommandQuickAccessChanged: _setCommandQuickAccess,
            responseMappings: workspace.responseMappings,
            onNewResponseMapping: () => _editResponseMapping(),
            onEditResponseMapping: _editResponseMapping,
            onDeleteResponseMapping: _deleteResponseMapping,
            l10n: l10n,
          );
          final sidePanel = _DeviceWorkbenchPanel(
            characteristics: _characteristics,
            connected: _selectedDevice?.connected == true,
            canSend: _hasWriteTarget,
            onSelectWrite: _setWriteCharacteristic,
            onSubscriptionChanged: _setSubscription,
            onRead: _readCharacteristic,
            onSendCommand: _sendCommandDefinition,
            commands: workspace.commands,
            responseMappings: workspace.responseMappings,
            monitoredValues: _monitoredValues,
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
    required this.onProtocolChanged,
    required this.onScriptConfigChanged,
    required this.onNewCommand,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onCommandEnabledChanged,
    required this.onCommandQuickAccessChanged,
    required this.responseMappings,
    required this.onNewResponseMapping,
    required this.onEditResponseMapping,
    required this.onDeleteResponseMapping,
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
  final ValueChanged<ProtocolDefinition> onProtocolChanged;
  final ValueChanged<ScriptConfig> onScriptConfigChanged;
  final VoidCallback onNewCommand;
  final ValueChanged<CommandDefinition> onEditCommand;
  final ValueChanged<CommandDefinition> onDeleteCommand;
  final void Function(CommandDefinition, bool) onCommandEnabledChanged;
  final void Function(CommandDefinition, bool) onCommandQuickAccessChanged;
  final List<ResponseMapping> responseMappings;
  final VoidCallback onNewResponseMapping;
  final ValueChanged<ResponseMapping> onEditResponseMapping;
  final ValueChanged<ResponseMapping> onDeleteResponseMapping;
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
                  icon: const Icon(Icons.list_alt_outlined),
                  text: l10n.commandLibrary,
                ),
                Tab(
                  icon: const Icon(Icons.data_object_outlined),
                  text: l10n.dataMappings,
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
                _ProtocolConfigurationPanel(
                  protocol: workspace.protocol,
                  scriptConfig: workspace.scriptConfig,
                  onProtocolChanged: onProtocolChanged,
                  onScriptConfigChanged: onScriptConfigChanged,
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
                _DataMappingLibraryPanel(
                  mappings: responseMappings,
                  onNew: onNewResponseMapping,
                  onEdit: onEditResponseMapping,
                  onDelete: onDeleteResponseMapping,
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
            _updateScript(enabled: mode == _ProtocolMode.script);
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
        borderRadius: BorderRadius.circular(6),
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
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(5),
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
        borderRadius: BorderRadius.circular(5),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(5),
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
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(4),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
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
    required this.onSendCommand,
    required this.commands,
    required this.responseMappings,
    required this.monitoredValues,
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
  final Future<void> Function(CommandDefinition, Map<String, String>)
  onSendCommand;
  final List<CommandDefinition> commands;
  final List<ResponseMapping> responseMappings;
  final Map<String, _MonitoredFieldValue> monitoredValues;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
                  text: l10n.commandsAndData,
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
                _CommandsAndDataPanel(
                  canSend: canSend,
                  onSend: onSendCommand,
                  commands: commands,
                  responseMappings: responseMappings,
                  monitoredValues: monitoredValues,
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
  String? _validationError;

  @override
  void initState() {
    super.initState();
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
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
              IconButton.filled(
                tooltip: widget.l10n.sendCommand,
                onPressed: sendEnabled ? _send : null,
                icon: const Icon(Icons.send_outlined, size: 18),
              ),
            ],
          ),
          if (command.parameters.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: command.parameters
                  .map(_buildParameterInput)
                  .toList(growable: false),
            ),
          ],
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
    );
  }

  Widget _buildParameterInput(CommandParameter parameter) {
    final String label = parameter.label.isEmpty
        ? parameter.key
        : parameter.label;
    return SizedBox(
      width: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 3),
          if (parameter.type == CommandParameterType.enumValue &&
              parameter.options.isNotEmpty)
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
              ),
              items: parameter.options
                  .map(
                    (CommandParameterOption option) => DropdownMenuItem<String>(
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
            TextField(
              controller: _controllers[parameter.key],
              keyboardType: _usesNumericKeyboard(parameter.type)
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: _commandParameterTypeLabel(parameter.type),
              ),
            ),
        ],
      ),
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
