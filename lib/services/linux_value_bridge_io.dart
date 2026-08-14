import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bluez/bluez.dart';

typedef LinuxValueCallback = void Function(Uint8List value);

class _LinuxSubscription {
  const _LinuxSubscription({
    required this.characteristic,
    required this.values,
  });

  final BlueZGattCharacteristic characteristic;
  final StreamSubscription<List<String>> values;
}

class LinuxValueBridge {
  final BlueZClient _client = BlueZClient();
  final Map<String, _LinuxSubscription> _subscriptions =
      <String, _LinuxSubscription>{};
  bool _connected = false;

  bool get _isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  Future<void> subscribe(
    String deviceId,
    String serviceId,
    String characteristicId,
    LinuxValueCallback onValue,
  ) async {
    if (!_isLinux) return;
    await _ensureConnected();
    final BlueZDevice device = _findDevice(deviceId);
    final BlueZGattCharacteristic characteristic = _findCharacteristic(
      device,
      serviceId,
      characteristicId,
    );
    final String key = _key(deviceId, serviceId, characteristicId);
    await _cancelSubscription(key, stopNotify: false);

    // Attach the value listener before StartNotify. Some peripherals send an
    // initial indication during StartNotify and BlueZ delivers it immediately.
    final StreamSubscription<List<String>> values = characteristic
        .propertiesChanged
        .listen((List<String> properties) {
          if (properties.contains('Value')) {
            onValue(Uint8List.fromList(characteristic.value));
          }
        });
    _subscriptions[key] = _LinuxSubscription(
      characteristic: characteristic,
      values: values,
    );
    try {
      if (!characteristic.notifying) {
        await characteristic.startNotify();
      }
    } catch (_) {
      await _cancelSubscription(key, stopNotify: false);
      rethrow;
    }
  }

  Future<void> unsubscribe(
    String deviceId,
    String serviceId,
    String characteristicId,
  ) async {
    if (!_isLinux) return;
    final String key = _key(deviceId, serviceId, characteristicId);
    await _cancelSubscription(key, stopNotify: true);
  }

  Future<void> _ensureConnected() async {
    if (_connected) return;
    await _client.connect();
    _connected = true;
  }

  BlueZDevice _findDevice(String deviceId) {
    final String target = deviceId.toLowerCase();
    return _client.devices.firstWhere(
      (BlueZDevice device) => device.address.toLowerCase() == target,
      orElse: () => throw StateError('Linux BlueZ device not found: $deviceId'),
    );
  }

  BlueZGattCharacteristic _findCharacteristic(
    BlueZDevice device,
    String serviceId,
    String characteristicId,
  ) {
    final String targetService = serviceId.toLowerCase();
    final String targetCharacteristic = characteristicId.toLowerCase();
    for (final BlueZGattService service in device.gattServices) {
      if (service.uuid.toString().toLowerCase() != targetService) continue;
      for (final BlueZGattCharacteristic characteristic
          in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() ==
            targetCharacteristic) {
          return characteristic;
        }
      }
    }
    throw StateError(
      'Linux BlueZ characteristic not found: $serviceId/$characteristicId',
    );
  }

  Future<void> _cancelSubscription(
    String key, {
    required bool stopNotify,
  }) async {
    final _LinuxSubscription? subscription = _subscriptions.remove(key);
    if (subscription == null) return;
    await subscription.values.cancel();
    if (stopNotify && subscription.characteristic.notifying) {
      await subscription.characteristic.stopNotify();
    }
  }

  String _key(String deviceId, String serviceId, String characteristicId) =>
      '${deviceId.toLowerCase()}/${serviceId.toLowerCase()}/${characteristicId.toLowerCase()}';

  Future<void> dispose() async {
    for (final String key in _subscriptions.keys.toList()) {
      await _cancelSubscription(key, stopNotify: true);
    }
    if (_connected) {
      await _client.close();
      _connected = false;
    }
  }
}

LinuxValueBridge createLinuxValueBridge() => LinuxValueBridge();
