import 'dart:typed_data';

typedef LinuxValueCallback = void Function(Uint8List value);

class LinuxValueBridge {
  Future<void> subscribe(
    String deviceId,
    String serviceId,
    String characteristicId,
    LinuxValueCallback onValue,
  ) async {}

  Future<void> unsubscribe(
    String deviceId,
    String serviceId,
    String characteristicId,
  ) async {}

  Future<void> dispose() async {}
}

LinuxValueBridge createLinuxValueBridge() => LinuxValueBridge();
