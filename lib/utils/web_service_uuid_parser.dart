final RegExp _webServiceUuidPattern = RegExp(
  r'^(?:[0-9a-f]{4}|[0-9a-f]{8}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$',
);

const String _bluetoothBaseUuidSuffix = '-0000-1000-8000-00805f9b34fb';

List<String>? parseWebServiceUuids(String input) {
  final List<String> services = input
      .split(RegExp(r'[\s,;]+'))
      .map((String value) => value.trim().toLowerCase())
      .where((String value) => value.isNotEmpty)
      .map(_expandWebServiceUuid)
      .toSet()
      .toList(growable: false);
  if (services.any((String value) => !_webServiceUuidPattern.hasMatch(value))) {
    return null;
  }
  return services;
}

String _expandWebServiceUuid(String uuid) {
  if (uuid.length == 4) return '0000$uuid$_bluetoothBaseUuidSuffix';
  if (uuid.length == 8) return '$uuid$_bluetoothBaseUuidSuffix';
  return uuid;
}
