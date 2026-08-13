import 'dart:async';

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

/// 蓝牙能力抽象，后续可替换为不同平台的真实插件实现。
abstract class BluetoothService {
  Stream<List<BluetoothDeviceInfo>> watchScannedDevices();

  Future<void> startScan();

  Future<void> stopScan();

  Future<void> connect(String deviceId);

  Future<void> disconnect(String deviceId);

  Future<void> sendData(String deviceId, List<int> bytes);

  Stream<List<int>> watchIncomingData(String deviceId);
}

/// 轻量 Mock 实现，用于真实蓝牙插件接入前的早期开发和桌面/Web 预览。
class MockBluetoothService implements BluetoothService {
  MockBluetoothService() {
    _scannedDevicesController.add(_devices);
  }

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
    const BluetoothDeviceInfo(
      id: 'spp-001',
      name: '经典蓝牙调试板',
      rssi: -61,
      protocol: 'SPP',
      connected: false,
    ),
  ];

  @override
  Future<void> connect(String deviceId) async {
    _replaceDevice(deviceId, connected: true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    _replaceDevice(deviceId, connected: false);
  }

  @override
  Future<void> sendData(String deviceId, List<int> bytes) async {
    _incomingControllers.putIfAbsent(
      deviceId,
      () => StreamController<List<int>>.broadcast(),
    ).add(bytes);
  }

  @override
  Stream<List<int>> watchIncomingData(String deviceId) {
    return _incomingControllers.putIfAbsent(
      deviceId,
      () => StreamController<List<int>>.broadcast(),
    ).stream;
  }

  @override
  Stream<List<BluetoothDeviceInfo>> watchScannedDevices() {
    return _scannedDevicesController.stream;
  }

  @override
  Future<void> startScan() async {
    _scannedDevicesController.add(_devices);
  }

  @override
  Future<void> stopScan() async {
    return;
  }

  void _replaceDevice(String deviceId, {required bool connected}) {
    final int index = _devices.indexWhere((BluetoothDeviceInfo item) => item.id == deviceId);
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
    _scannedDevicesController.add(List<BluetoothDeviceInfo>.unmodifiable(_devices));
  }

  Future<void> dispose() async {
    await _scannedDevicesController.close();
    for (final StreamController<List<int>> controller in _incomingControllers.values) {
      await controller.close();
    }
  }
}
