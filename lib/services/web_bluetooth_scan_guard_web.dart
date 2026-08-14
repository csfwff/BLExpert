import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('globalThis.BluetoothDevice')
external JSObject? get _bluetoothDeviceConstructor;

/// Keeps Universal BLE on the standard requestDevice/GATT path.
///
/// Chrome on Linux exposes watchAdvertisements behind an experimental flag,
/// but an active watcher can keep BlueZ discovery running and block GATT
/// connections. BLExpert does not need that watcher because requestDevice
/// already returns the selected device as a scan result.
void disableWebAdvertisementWatching() {
  final JSObject? constructor = _bluetoothDeviceConstructor;
  final JSObject? prototype = constructor?['prototype'] as JSObject?;
  prototype?.delete('watchAdvertisements'.toJS);
}
