import 'linux_device_trust_stub.dart'
    if (dart.library.io) 'linux_device_trust_io.dart';

Future<void> trustLinuxDevice(String deviceId) => trustDevice(deviceId);
