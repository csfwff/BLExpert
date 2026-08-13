import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

Future<void> trustDevice(String deviceId) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) {
    return;
  }

  final ProcessResult result = await Process.run('bluetoothctl', <String>[
    'trust',
    deviceId,
  ]).timeout(const Duration(seconds: 3));
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to mark the Linux BLE device as trusted: '
      '${result.stderr.toString().trim()}',
    );
  }
}
