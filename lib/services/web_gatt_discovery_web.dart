import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

import 'web_gatt_types.dart';

/// Discovers GATT attributes using the browser API directly.
Future<List<WebGattCharacteristicInfo>?> discoverWebGattCharacteristics(
  String deviceId,
) async {
  final Set<BluetoothDevice> devices =
      await FlutterWebBluetooth.instance.devices.first;
  final BluetoothDevice? device = devices
      .where((BluetoothDevice item) => item.id == deviceId)
      .firstOrNull;
  if (device == null) return null;

  final List<WebGattCharacteristicInfo> result = <WebGattCharacteristicInfo>[];
  for (final BluetoothService service in await device.discoverServices()) {
    for (final BluetoothCharacteristic characteristic
        in await service.getCharacteristics()) {
      final BluetoothCharacteristicProperties properties =
          characteristic.properties;
      result.add(
        WebGattCharacteristicInfo(
          serviceId: service.uuid,
          characteristicId: characteristic.uuid,
          canRead: properties.read,
          canWrite: properties.write,
          canWriteWithoutResponse: properties.writeWithoutResponse,
          canNotify: properties.notify,
          canIndicate: properties.indicate,
        ),
      );
    }
  }
  return result;
}

/// Reads the browser's GATT connection state without waiting for a plugin
/// connection event. This is the authoritative Web Bluetooth state.
Future<bool> isWebGattConnected(String deviceId) async {
  final Set<BluetoothDevice> devices =
      await FlutterWebBluetooth.instance.devices.first;
  final BluetoothDevice? device = devices
      .where((BluetoothDevice item) => item.id == deviceId)
      .firstOrNull;
  return await device?.connected.first ?? false;
}
