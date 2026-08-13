import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models/workspace.dart';
import 'services/bluetooth_service.dart';
import 'services/workspace_manager.dart';

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
  late final StreamSubscription<List<BluetoothDeviceInfo>> _scanSubscription;
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

  @override
  void initState() {
    super.initState();
    _workspaceManager = WorkspaceManager();
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
    // Web Bluetooth requires a user gesture before it may show the device
    // picker, so scanning always starts from the toolbar action.
    _scanning = false;
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _dataSubscription?.cancel();
    _inputController.dispose();
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
      setState(() {
        _logs.insert(0, _LogEntry(_LogKind.received, DateTime.now(), payload));
      });
    });
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
        await _bluetoothService.startScan();
      }
      if (mounted) setState(() => _scanning = !_scanning);
    } catch (error) {
      _showBluetoothError(error);
    }
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
                ? item.copyWith(isSubscribed: enabled)
                : item,
          )
          .toList(growable: false);
    });
  }

  Future<void> _send(List<int> bytes) async {
    final device = _selectedDevice;
    if (device == null || !_hasWriteTarget) return;
    setState(
      () => _logs.insert(0, _LogEntry(_LogKind.sent, DateTime.now(), bytes)),
    );
    try {
      await _bluetoothService.sendData(device.id, bytes);
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
          final console = _ConsoleArea(
            logs: _logs,
            autoScroll: _autoScroll,
            onClear: () => setState(_logs.clear),
            onAutoScrollChanged: (value) => setState(() => _autoScroll = value),
            inputController: _inputController,
            hexMode: _hexMode,
            onModeChanged: (value) => setState(() => _hexMode = value),
            onSend: _sendInput,
            canSend: _selectedDevice?.connected == true && _hasWriteTarget,
            l10n: l10n,
          );
          final sidePanel = _DeviceToolsPanel(
            characteristics: _characteristics,
            connected: _selectedDevice?.connected == true,
            canSend: _hasWriteTarget,
            onSelectWrite: _setWriteCharacteristic,
            onSubscriptionChanged: _setSubscription,
            onSend: _send,
            l10n: l10n,
          );
          if (wide) {
            return Row(
              children: <Widget>[
                Expanded(flex: 7, child: console),
                const VerticalDivider(width: 1),
                SizedBox(width: 390, child: sidePanel),
              ],
            );
          }
          return ListView(
            children: <Widget>[
              SizedBox(height: 620, child: console),
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
    required this.l10n,
  });
  final Workspace workspace;
  final List<Workspace> workspaces;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: l10n.selectWorkspace,
      onSelected: (_) {},
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

class _DeviceToolsPanel extends StatelessWidget {
  const _DeviceToolsPanel({
    required this.characteristics,
    required this.connected,
    required this.canSend,
    required this.onSelectWrite,
    required this.onSubscriptionChanged,
    required this.onSend,
    required this.l10n,
  });

  final List<BluetoothCharacteristicInfo> characteristics;
  final bool connected;
  final bool canSend;
  final Future<void> Function(BluetoothCharacteristicInfo) onSelectWrite;
  final Future<void> Function(BluetoothCharacteristicInfo, bool)
  onSubscriptionChanged;
  final Future<void> Function(List<int>) onSend;
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
    final commands = <({String name, List<int> payload})>[
      (name: 'PING', payload: <int>[0xAA, 0x55, 0x00]),
      (name: 'GET STATUS', payload: <int>[0xAA, 0x55, 0x01, 0x00]),
      (name: 'GET VERSION', payload: <int>[0xAA, 0x55, 0x02, 0x00]),
      (name: 'HEX TEST', payload: <int>[0xAA, 0xBB, 0xCC, 0x11, 0x22]),
    ];
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
                      '${l10n.service} ${entry.key}',
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
                            l10n: l10n,
                          ),
                    ),
                  ],
            ),
          const Divider(height: 28),
          Row(
            children: <Widget>[
              Text(
                l10n.quickCommands,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.newCommand,
                onPressed: () {},
                icon: const Icon(Icons.add, size: 19),
              ),
            ],
          ),
          const Divider(height: 20),
          ...commands.map(
            (command) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canSend ? () => onSend(command.payload) : null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(command.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: l10n.sendCommand,
                    onPressed: canSend ? () => onSend(command.payload) : null,
                    icon: const Icon(Icons.send_outlined, size: 18),
                  ),
                ],
              ),
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
    required this.l10n,
  });

  final BluetoothCharacteristicInfo characteristic;
  final Future<void> Function(BluetoothCharacteristicInfo) onSelectWrite;
  final Future<void> Function(BluetoothCharacteristicInfo, bool)
  onSubscriptionChanged;
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
                if (characteristic.canNotify)
                  _CapabilityChip(label: l10n.notify),
                if (characteristic.canIndicate)
                  _CapabilityChip(label: l10n.indicate),
              ],
            ),
            if (characteristic.canWrite || characteristic.canSubscribe)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    if (characteristic.canWrite ||
                        characteristic.canWriteWithoutResponse)
                      ChoiceChip(
                        label: Text(l10n.writeTarget),
                        selected: characteristic.isWriteTarget,
                        onSelected: (_) => onSelectWrite(characteristic),
                      ),
                    if (characteristic.canSubscribe)
                      FilterChip(
                        label: Text(l10n.subscribe),
                        selected: characteristic.isSubscribed,
                        onSelected: (bool selected) =>
                            onSubscriptionChanged(characteristic, selected),
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
