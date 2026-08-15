import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'linux_device_trust.dart';
import 'linux_value_bridge.dart';
import 'web_bluetooth_scan_guard.dart';
import 'web_gatt_discovery.dart';

/// 扫描层发现的蓝牙设备信息。
class BluetoothDeviceInfo {
  const BluetoothDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    required this.protocol,
    required this.connected,
  });

  final String id;
  final String name;
  final int rssi;
  final String protocol;
  final bool connected;
}

/// A transport-level event that the console can display alongside payloads.
class BluetoothServiceEvent {
  const BluetoothServiceEvent({
    required this.deviceId,
    required this.message,
    this.isError = false,
  });

  final String deviceId;
  final String message;
  final bool isError;
}

enum BluetoothSubscriptionMode { notify, indicate }

/// A GATT characteristic exposed to the debugger after service discovery.
class BluetoothCharacteristicInfo {
  const BluetoothCharacteristicInfo({
    required this.serviceId,
    required this.characteristicId,
    required this.canRead,
    required this.canWrite,
    required this.canWriteWithoutResponse,
    required this.canNotify,
    required this.canIndicate,
    required this.isSubscribed,
    required this.isWriteTarget,
    this.subscriptionMode,
  });

  final String serviceId;
  final String characteristicId;
  final bool canRead;
  final bool canWrite;
  final bool canWriteWithoutResponse;
  final bool canNotify;
  final bool canIndicate;
  final bool isSubscribed;
  final bool isWriteTarget;
  final BluetoothSubscriptionMode? subscriptionMode;

  bool get canSubscribe => canNotify || canIndicate;

  String get key => '$serviceId/$characteristicId';

  BluetoothCharacteristicInfo copyWith({
    bool? isSubscribed,
    bool? isWriteTarget,
    BluetoothSubscriptionMode? subscriptionMode,
  }) {
    return BluetoothCharacteristicInfo(
      serviceId: serviceId,
      characteristicId: characteristicId,
      canRead: canRead,
      canWrite: canWrite,
      canWriteWithoutResponse: canWriteWithoutResponse,
      canNotify: canNotify,
      canIndicate: canIndicate,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      isWriteTarget: isWriteTarget ?? this.isWriteTarget,
      subscriptionMode: subscriptionMode ?? this.subscriptionMode,
    );
  }
}

/// 蓝牙能力抽象，后续可替换为不同平台的真实插件实现。
abstract class BluetoothService {
  Stream<List<BluetoothDeviceInfo>> watchScannedDevices();

  Future<void> startScan({List<String> webOptionalServices = const <String>[]});

  Future<void> stopScan();

  Future<void> connect(String deviceId);

  Future<void> disconnect(String deviceId);

  Future<List<BluetoothCharacteristicInfo>> discoverCharacteristics(
    String deviceId,
  );

  Future<void> setWriteCharacteristic(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
  );

  Future<void> setCharacteristicSubscription(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
    bool enabled, {
    BluetoothSubscriptionMode? mode,
  });

  Future<void> sendData(String deviceId, List<int> bytes);

  Stream<List<int>> watchIncomingData(String deviceId);

  Stream<BluetoothServiceEvent> watchEvents();

  Future<List<int>> readData(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
  );

  Future<void> dispose();
}

/// BLE central adapter backed by Universal BLE.
///
/// Characteristics are discovered when connecting but are not selected
/// automatically. The user explicitly chooses subscriptions and a write target.
class UniversalBleService implements BluetoothService {
  UniversalBleService() {
    UniversalBle.queueType = QueueType.perDevice;
    if (kIsWeb) {
      disableWebAdvertisementWatching();
    }
    _scanSubscription = UniversalBle.scanStream.listen(_handleScanResult);
    UniversalBle.onConnectionChange = _handleConnectionChange;
    UniversalBle.onValueChange = _handleValueChange;
  }

  final StreamController<List<BluetoothDeviceInfo>> _devicesController =
      StreamController<List<BluetoothDeviceInfo>>.broadcast();
  final StreamController<BluetoothServiceEvent> _eventsController =
      StreamController<BluetoothServiceEvent>.broadcast();
  final Map<String, StreamController<List<int>>> _incomingControllers =
      <String, StreamController<List<int>>>{};
  final Map<String, BluetoothDeviceInfo> _devices =
      <String, BluetoothDeviceInfo>{};
  final Map<String, List<BluetoothCharacteristicInfo>> _characteristics =
      <String, List<BluetoothCharacteristicInfo>>{};
  final LinuxValueBridge _linuxValueBridge = createLinuxValueBridge();
  late final StreamSubscription<BleDevice> _scanSubscription;

  @override
  Stream<List<BluetoothDeviceInfo>> watchScannedDevices() async* {
    yield _sortedDevices;
    yield* _devicesController.stream;
  }

  @override
  Future<void> startScan({
    List<String> webOptionalServices = const <String>[],
  }) async {
    await UniversalBle.requestPermissions();
    await UniversalBle.startScan(
      platformConfig: kIsWeb
          ? PlatformConfig(
              web: WebOptions(optionalServices: webOptionalServices),
            )
          : null,
    );
  }

  @override
  Future<void> stopScan() => UniversalBle.stopScan();

  @override
  Future<void> connect(String deviceId) async {
    await UniversalBle.requestPermissions();
    final bool isLinux =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    try {
      // BlueZ may discard an unpaired Device1 object when discovery stops.
      // Refresh the exact address first. Keep the UI selection untouched while
      // doing so; the service cache must contain the current BlueZ object.
      if (isLinux) {
        await _refreshLinuxDevice(deviceId);
        // BlueZ can delete an unpaired temporary Device1 object when a
        // connection is requested. universal_ble does not expose BlueZ's
        // Trusted property, so set it through the Linux system adapter before
        // handing the actual BLE connection back to universal_ble.
        await trustLinuxDevice(deviceId);
        await UniversalBle.stopScan();
      } else {
        // On Web this cancels the advertisement watcher created after the
        // device picker. Chrome on Linux cannot reliably connect GATT while
        // that watcher is still active.
        await UniversalBle.stopScan();
      }
      if (kIsWeb) {
        await _connectWeb(deviceId);
      } else {
        await UniversalBle.connect(
          deviceId,
          timeout: const Duration(seconds: 15),
        );
      }
    } catch (error) {
      if (_isStaleDeviceError(error)) {
        _invalidateDevice(deviceId);
        throw StateError(
          'The BLE device is no longer available. Scan again and reconnect.',
        );
      }
      rethrow;
    } finally {
      if (isLinux) {
        await UniversalBle.stopScan();
      }
    }
    _setConnected(deviceId, true);
  }

  Future<void> _connectWeb(String deviceId) async {
    // universal_ble's Web adapter waits for a connection event that it starts
    // listening to after gatt.connect() has already completed. Chrome can
    // therefore report an active GATT link while that Future still waits for
    // its timeout. Start the adapter operation for its internal bookkeeping,
    // but use the browser GATT state as the completion signal.
    final Future<void> adapterConnection = UniversalBle.connect(
      deviceId,
      timeout: const Duration(seconds: 60),
    );
    // The adapter Future can time out after the browser has already confirmed
    // the link. Keep its error handled so it never becomes an unhandled async
    // exception after this method has returned successfully.
    unawaited(adapterConnection.catchError((Object _) {}));
    final bool browserConnected = await _waitForWebGattConnection(deviceId);
    if (!browserConnected) {
      await adapterConnection;
      return;
    }
    _eventsController.add(
      BluetoothServiceEvent(
        deviceId: deviceId,
        message: 'Web GATT connection confirmed by browser.',
      ),
    );
  }

  Future<bool> _waitForWebGattConnection(String deviceId) async {
    const Duration pollInterval = Duration(milliseconds: 200);
    const Duration timeout = Duration(seconds: 15);
    final Stopwatch stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (await isWebGattConnected(deviceId)) return true;
      await Future<void>.delayed(pollInterval);
    }
    return await isWebGattConnected(deviceId);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final List<BluetoothCharacteristicInfo> characteristics =
        _characteristics[deviceId] ?? const <BluetoothCharacteristicInfo>[];
    for (final BluetoothCharacteristicInfo characteristic in characteristics) {
      if (characteristic.isSubscribed) {
        if (_isLinux) {
          await _linuxValueBridge.unsubscribe(
            deviceId,
            characteristic.serviceId,
            characteristic.characteristicId,
          );
        } else {
          await UniversalBle.unsubscribe(
            deviceId,
            characteristic.serviceId,
            characteristic.characteristicId,
          );
        }
      }
    }
    _characteristics.remove(deviceId);
    await UniversalBle.disconnect(deviceId);
    _setConnected(deviceId, false);
  }

  @override
  Future<void> sendData(String deviceId, List<int> bytes) async {
    final BluetoothCharacteristicInfo? characteristic = _writeCharacteristic(
      deviceId,
    );
    if (characteristic == null) {
      throw StateError('No write characteristic selected for $deviceId.');
    }
    await UniversalBle.write(
      deviceId,
      characteristic.serviceId,
      characteristic.characteristicId,
      Uint8List.fromList(bytes),
      // Prefer acknowledged writes when both modes are available so the
      // debugger reports transport failures instead of silently losing data.
      withoutResponse:
          !characteristic.canWrite && characteristic.canWriteWithoutResponse,
    );
  }

  @override
  Future<List<int>> readData(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
  ) async {
    if (!characteristic.canRead) {
      throw ArgumentError.value(
        characteristic,
        'characteristic',
        'Characteristic is not readable.',
      );
    }
    final Uint8List value = await UniversalBle.read(
      deviceId,
      characteristic.serviceId,
      characteristic.characteristicId,
    );
    return List<int>.unmodifiable(value);
  }

  @override
  Future<List<BluetoothCharacteristicInfo>> discoverCharacteristics(
    String deviceId,
  ) async {
    final List<BleService> services = await _discoverServices(deviceId);
    final List<BluetoothCharacteristicInfo> characteristics =
        <BluetoothCharacteristicInfo>[
          for (final BleService service in services)
            for (final BleCharacteristic characteristic
                in service.characteristics)
              BluetoothCharacteristicInfo(
                serviceId: service.uuid,
                characteristicId: characteristic.uuid,
                canRead: characteristic.properties.contains(
                  CharacteristicProperty.read,
                ),
                canWrite: characteristic.properties.contains(
                  CharacteristicProperty.write,
                ),
                canWriteWithoutResponse: characteristic.properties.contains(
                  CharacteristicProperty.writeWithoutResponse,
                ),
                canNotify: characteristic.properties.contains(
                  CharacteristicProperty.notify,
                ),
                canIndicate: characteristic.properties.contains(
                  CharacteristicProperty.indicate,
                ),
                isSubscribed: false,
                isWriteTarget: false,
              ),
        ];
    _characteristics[deviceId] = characteristics;
    return List<BluetoothCharacteristicInfo>.unmodifiable(characteristics);
  }

  Future<List<BleService>> _discoverServices(String deviceId) async {
    if (kIsWeb) {
      final List<WebGattCharacteristicInfo>? webCharacteristics =
          await discoverWebGattCharacteristics(deviceId);
      if (webCharacteristics != null) {
        _eventsController.add(
          BluetoothServiceEvent(
            deviceId: deviceId,
            message:
                'Web GATT discovered ${webCharacteristics.length} characteristic(s).',
          ),
        );
        return _webCharacteristicsToServices(webCharacteristics);
      }
    }
    Object? lastError;
    const int attempts = 4;
    for (int attempt = 0; attempt < attempts; attempt++) {
      try {
        final List<BleService> services = await UniversalBle.discoverServices(
          deviceId,
        );
        if (services.isNotEmpty || !_isLinux) {
          return services;
        }
      } catch (error) {
        lastError = error;
        if (!_isLinux || attempt == attempts - 1) {
          rethrow;
        }
      }

      // BlueZ may publish ServicesResolved before its GATT child objects are
      // visible through D-Bus. Give the object manager time to finish adding
      // the services and characteristics, then ask UniversalBle again.
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    if (lastError != null) {
      throw lastError;
    }
    return const <BleService>[];
  }

  List<BleService> _webCharacteristicsToServices(
    List<WebGattCharacteristicInfo> characteristics,
  ) {
    final Map<String, List<BleCharacteristic>> grouped =
        <String, List<BleCharacteristic>>{};
    for (final WebGattCharacteristicInfo characteristic in characteristics) {
      grouped
          .putIfAbsent(characteristic.serviceId, () => <BleCharacteristic>[])
          .add(
            BleCharacteristic(
              characteristic.characteristicId,
              <CharacteristicProperty>[
                if (characteristic.canRead) CharacteristicProperty.read,
                if (characteristic.canWrite) CharacteristicProperty.write,
                if (characteristic.canWriteWithoutResponse)
                  CharacteristicProperty.writeWithoutResponse,
                if (characteristic.canNotify) CharacteristicProperty.notify,
                if (characteristic.canIndicate) CharacteristicProperty.indicate,
              ],
              <BleDescriptor>[],
            ),
          );
    }
    return grouped.entries
        .map((entry) => BleService(entry.key, entry.value))
        .toList(growable: false);
  }

  @override
  Future<void> setWriteCharacteristic(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
  ) async {
    if (!characteristic.canWrite && !characteristic.canWriteWithoutResponse) {
      throw ArgumentError.value(
        characteristic,
        'characteristic',
        'Characteristic is not writable.',
      );
    }
    _updateCharacteristic(
      deviceId,
      characteristic.key,
      (BluetoothCharacteristicInfo item) =>
          item.copyWith(isWriteTarget: item.key == characteristic.key),
    );
  }

  @override
  Future<void> setCharacteristicSubscription(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
    bool enabled, {
    BluetoothSubscriptionMode? mode,
  }) async {
    if (!characteristic.canSubscribe) {
      throw ArgumentError.value(
        characteristic,
        'characteristic',
        'Characteristic cannot be subscribed.',
      );
    }
    final BluetoothSubscriptionMode selectedMode =
        mode ??
        (characteristic.canIndicate && !characteristic.canNotify
            ? BluetoothSubscriptionMode.indicate
            : BluetoothSubscriptionMode.notify);
    if (selectedMode == BluetoothSubscriptionMode.notify &&
        !characteristic.canNotify) {
      throw ArgumentError.value(
        characteristic,
        'characteristic',
        'Characteristic does not support Notify.',
      );
    }
    if (selectedMode == BluetoothSubscriptionMode.indicate &&
        !characteristic.canIndicate) {
      throw ArgumentError.value(
        characteristic,
        'characteristic',
        'Characteristic does not support Indicate.',
      );
    }

    if (enabled) {
      final BluetoothCharacteristicInfo? active =
          (_characteristics[deviceId] ?? const <BluetoothCharacteristicInfo>[])
              .where(
                (BluetoothCharacteristicInfo item) =>
                    item.key == characteristic.key,
              )
              .firstOrNull;
      if (active?.isSubscribed == true &&
          active?.subscriptionMode != selectedMode) {
        if (_isLinux) {
          await _linuxValueBridge.unsubscribe(
            deviceId,
            characteristic.serviceId,
            characteristic.characteristicId,
          );
        } else {
          await UniversalBle.unsubscribe(
            deviceId,
            characteristic.serviceId,
            characteristic.characteristicId,
          );
        }
      }

      // Register before the platform call: some peripherals send immediately
      // after the CCCD write and that first packet must not be discarded.
      _updateCharacteristic(
        deviceId,
        characteristic.key,
        (BluetoothCharacteristicInfo item) =>
            item.copyWith(isSubscribed: true, subscriptionMode: selectedMode),
      );
      try {
        if (_isLinux) {
          await _linuxValueBridge.subscribe(
            deviceId,
            characteristic.serviceId,
            characteristic.characteristicId,
            (Uint8List value) => _handleValueChange(
              deviceId,
              characteristic.characteristicId,
              value,
              null,
            ),
          );
        } else if (selectedMode == BluetoothSubscriptionMode.notify) {
          await UniversalBle.subscribeNotifications(
            deviceId,
            characteristic.serviceId,
            characteristic.characteristicId,
          );
        } else {
          await UniversalBle.subscribeIndications(
            deviceId,
            characteristic.serviceId,
            characteristic.characteristicId,
          );
        }
      } catch (_) {
        _updateCharacteristic(
          deviceId,
          characteristic.key,
          (BluetoothCharacteristicInfo item) =>
              item.copyWith(isSubscribed: false),
        );
        rethrow;
      }
    } else {
      if (_isLinux) {
        await _linuxValueBridge.unsubscribe(
          deviceId,
          characteristic.serviceId,
          characteristic.characteristicId,
        );
      } else {
        await UniversalBle.unsubscribe(
          deviceId,
          characteristic.serviceId,
          characteristic.characteristicId,
        );
      }
      _updateCharacteristic(
        deviceId,
        characteristic.key,
        (BluetoothCharacteristicInfo item) =>
            item.copyWith(isSubscribed: false),
      );
    }
  }

  @override
  Stream<List<int>> watchIncomingData(String deviceId) {
    return _incomingControllers
        .putIfAbsent(deviceId, () => StreamController<List<int>>.broadcast())
        .stream;
  }

  @override
  Stream<BluetoothServiceEvent> watchEvents() => _eventsController.stream;

  void _handleScanResult(BleDevice device) {
    final String name = (device.name?.isNotEmpty ?? false)
        ? device.name!
        : 'BLE ${device.deviceId}';
    _devices[device.deviceId] = BluetoothDeviceInfo(
      id: device.deviceId,
      name: name,
      rssi: device.rssi ?? 0,
      protocol: 'BLE',
      connected: _devices[device.deviceId]?.connected ?? false,
    );
    _publishDevices();
  }

  void _handleConnectionChange(
    String deviceId,
    bool isConnected,
    String? error,
  ) {
    _setConnected(deviceId, isConnected);
    if (error != null && error.isNotEmpty) {
      _eventsController.add(
        BluetoothServiceEvent(
          deviceId: deviceId,
          message: 'Connection ${isConnected ? 'warning' : 'failed'}: $error',
          isError: !isConnected,
        ),
      );
    }
  }

  void _handleValueChange(
    String deviceId,
    String characteristicId,
    Uint8List value,
    int? timestamp,
  ) {
    final bool isSubscribed =
        (_characteristics[deviceId] ?? const <BluetoothCharacteristicInfo>[])
            .any(
              (BluetoothCharacteristicInfo item) =>
                  item.characteristicId.toLowerCase() ==
                      characteristicId.toLowerCase() &&
                  item.isSubscribed,
            );
    if (!isSubscribed) {
      return;
    }
    _incomingControllers
        .putIfAbsent(deviceId, () => StreamController<List<int>>.broadcast())
        .add(List<int>.unmodifiable(value));
  }

  void _setConnected(String deviceId, bool connected) {
    final BluetoothDeviceInfo? previous = _devices[deviceId];
    if (previous == null) {
      return;
    }
    _devices[deviceId] = BluetoothDeviceInfo(
      id: previous.id,
      name: previous.name,
      rssi: previous.rssi,
      protocol: previous.protocol,
      connected: connected,
    );
    _publishDevices();
  }

  void _publishDevices() => _devicesController.add(_sortedDevices);

  Future<void> _refreshLinuxDevice(String deviceId) async {
    // Remove only the service cache entry. The UI keeps its selected item until
    // the scan proves that the address is gone or a new result replaces it.
    _devices.remove(deviceId);
    _characteristics.remove(deviceId);

    final Completer<void> deviceResult = Completer<void>();
    late final StreamSubscription<List<BluetoothDeviceInfo>> subscription;
    subscription = _devicesController.stream.listen((devices) {
      if (devices.any((BluetoothDeviceInfo item) => item.id == deviceId) &&
          !deviceResult.isCompleted) {
        deviceResult.complete();
      }
    });

    try {
      await UniversalBle.startScan();
      if (_devices.containsKey(deviceId)) {
        return;
      }
      await deviceResult.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      _invalidateDevice(deviceId);
      throw StateError(
        'The BLE device is no longer available. Scan again and reconnect.',
      );
    } finally {
      await subscription.cancel();
    }
  }

  void _invalidateDevice(String deviceId) {
    _devices.remove(deviceId);
    _characteristics.remove(deviceId);
    _publishDevices();
  }

  bool _isStaleDeviceError(Object error) {
    final String text = error.toString();
    return (text.contains('org.freedesktop.DBus.Error.UnknownObject') &&
            text.contains('org.bluez.Device1')) ||
        text.contains('UniversalBleErrorCode.deviceNotFound') ||
        text.contains('Unknown deviceId:');
  }

  List<BluetoothDeviceInfo> get _sortedDevices {
    final List<BluetoothDeviceInfo> result = _devices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return List<BluetoothDeviceInfo>.unmodifiable(result);
  }

  BluetoothCharacteristicInfo? _writeCharacteristic(String deviceId) {
    for (final BluetoothCharacteristicInfo item
        in _characteristics[deviceId] ??
            const <BluetoothCharacteristicInfo>[]) {
      if (item.isWriteTarget) {
        return item;
      }
    }
    return null;
  }

  void _updateCharacteristic(
    String deviceId,
    String key,
    BluetoothCharacteristicInfo Function(BluetoothCharacteristicInfo item)
    update,
  ) {
    final List<BluetoothCharacteristicInfo>? current =
        _characteristics[deviceId];
    if (current == null) {
      throw StateError(
        'Characteristics have not been discovered for $deviceId.',
      );
    }
    _characteristics[deviceId] = current
        .map(
          (BluetoothCharacteristicInfo item) =>
              item.key == key ? update(item) : item,
        )
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    await _linuxValueBridge.dispose();
    await _scanSubscription.cancel();
    UniversalBle.onConnectionChange = null;
    UniversalBle.onValueChange = null;
    await _devicesController.close();
    await _eventsController.close();
    for (final StreamController<List<int>> controller
        in _incomingControllers.values) {
      await controller.close();
    }
  }

  bool get _isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
}

/// 轻量 Mock 实现，用于真实蓝牙插件接入前的早期开发和桌面/Web 预览。
class MockBluetoothService implements BluetoothService {
  MockBluetoothService({this.connectError}) {
    _scannedDevicesController.add(_devices);
  }

  final Object? connectError;

  final StreamController<List<BluetoothDeviceInfo>> _scannedDevicesController =
      StreamController<List<BluetoothDeviceInfo>>.broadcast();
  final Map<String, StreamController<List<int>>> _incomingControllers =
      <String, StreamController<List<int>>>{};

  final List<BluetoothDeviceInfo> _devices = <BluetoothDeviceInfo>[
    const BluetoothDeviceInfo(
      id: 'ble-001',
      name: 'BLE 温度传感器',
      rssi: -48,
      protocol: 'BLE',
      connected: false,
    ),
  ];
  final Map<String, List<BluetoothCharacteristicInfo>> _characteristics =
      <String, List<BluetoothCharacteristicInfo>>{
        'ble-001': <BluetoothCharacteristicInfo>[
          const BluetoothCharacteristicInfo(
            serviceId: '0000181A-0000-1000-8000-00805F9B34FB',
            characteristicId: '00002A6E-0000-1000-8000-00805F9B34FB',
            canRead: true,
            canWrite: false,
            canWriteWithoutResponse: false,
            canNotify: true,
            canIndicate: false,
            isSubscribed: false,
            isWriteTarget: false,
          ),
          const BluetoothCharacteristicInfo(
            serviceId: '0000FFF0-0000-1000-8000-00805F9B34FB',
            characteristicId: '0000FFF1-0000-1000-8000-00805F9B34FB',
            canRead: false,
            canWrite: true,
            canWriteWithoutResponse: true,
            canNotify: false,
            canIndicate: false,
            isSubscribed: false,
            isWriteTarget: false,
          ),
          const BluetoothCharacteristicInfo(
            serviceId: '0000FFF0-0000-1000-8000-00805F9B34FB',
            characteristicId: '0000FFF2-0000-1000-8000-00805F9B34FB',
            canRead: false,
            canWrite: false,
            canWriteWithoutResponse: false,
            canNotify: true,
            canIndicate: true,
            isSubscribed: false,
            isWriteTarget: false,
          ),
        ],
      };

  @override
  Future<void> connect(String deviceId) async {
    if (connectError != null) {
      throw connectError!;
    }
    _replaceDevice(deviceId, connected: true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    _replaceDevice(deviceId, connected: false);
  }

  @override
  Future<List<BluetoothCharacteristicInfo>> discoverCharacteristics(
    String deviceId,
  ) async {
    return List<BluetoothCharacteristicInfo>.unmodifiable(
      _characteristics[deviceId] ?? const <BluetoothCharacteristicInfo>[],
    );
  }

  @override
  Future<void> setWriteCharacteristic(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
  ) async {
    _updateCharacteristic(
      deviceId,
      characteristic.key,
      (BluetoothCharacteristicInfo item) =>
          item.copyWith(isWriteTarget: item.key == characteristic.key),
    );
  }

  @override
  Future<void> setCharacteristicSubscription(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
    bool enabled, {
    BluetoothSubscriptionMode? mode,
  }) async {
    _updateCharacteristic(
      deviceId,
      characteristic.key,
      (BluetoothCharacteristicInfo item) => item.copyWith(
        isSubscribed: enabled,
        subscriptionMode:
            mode ??
            (item.canIndicate && !item.canNotify
                ? BluetoothSubscriptionMode.indicate
                : BluetoothSubscriptionMode.notify),
      ),
    );
  }

  @override
  Future<List<int>> readData(
    String deviceId,
    BluetoothCharacteristicInfo characteristic,
  ) async {
    if (!characteristic.canRead) {
      throw ArgumentError.value(
        characteristic,
        'characteristic',
        'Characteristic is not readable.',
      );
    }
    final List<int> value = <int>[0x12, 0x34];
    _incomingControllers
        .putIfAbsent(deviceId, () => StreamController<List<int>>.broadcast())
        .add(value);
    return value;
  }

  @override
  Stream<BluetoothServiceEvent> watchEvents() => const Stream.empty();

  @override
  Future<void> sendData(String deviceId, List<int> bytes) async {
    final bool hasWriteTarget =
        (_characteristics[deviceId] ?? const <BluetoothCharacteristicInfo>[])
            .any((BluetoothCharacteristicInfo item) => item.isWriteTarget);
    if (!hasWriteTarget) {
      throw StateError('No write characteristic selected for $deviceId.');
    }
    _incomingControllers
        .putIfAbsent(deviceId, () => StreamController<List<int>>.broadcast())
        .add(bytes);
  }

  @override
  Stream<List<int>> watchIncomingData(String deviceId) {
    return _incomingControllers
        .putIfAbsent(deviceId, () => StreamController<List<int>>.broadcast())
        .stream;
  }

  @override
  Stream<List<BluetoothDeviceInfo>> watchScannedDevices() async* {
    yield List<BluetoothDeviceInfo>.unmodifiable(_devices);
    yield* _scannedDevicesController.stream;
  }

  @override
  Future<void> startScan({
    List<String> webOptionalServices = const <String>[],
  }) async {
    _scannedDevicesController.add(_devices);
  }

  @override
  Future<void> stopScan() async {
    return;
  }

  void _replaceDevice(String deviceId, {required bool connected}) {
    final int index = _devices.indexWhere(
      (BluetoothDeviceInfo item) => item.id == deviceId,
    );
    if (index < 0) {
      return;
    }

    _devices[index] = BluetoothDeviceInfo(
      id: _devices[index].id,
      name: _devices[index].name,
      rssi: _devices[index].rssi,
      protocol: _devices[index].protocol,
      connected: connected,
    );
    _scannedDevicesController.add(
      List<BluetoothDeviceInfo>.unmodifiable(_devices),
    );
  }

  void _updateCharacteristic(
    String deviceId,
    String key,
    BluetoothCharacteristicInfo Function(BluetoothCharacteristicInfo item)
    update,
  ) {
    final List<BluetoothCharacteristicInfo>? current =
        _characteristics[deviceId];
    if (current == null) {
      throw StateError(
        'Characteristics have not been discovered for $deviceId.',
      );
    }
    _characteristics[deviceId] = current
        .map(
          (BluetoothCharacteristicInfo item) =>
              item.key == key ? update(item) : item,
        )
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    await _scannedDevicesController.close();
    for (final StreamController<List<int>> controller
        in _incomingControllers.values) {
      await controller.close();
    }
  }
}
