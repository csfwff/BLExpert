class WebGattCharacteristicInfo {
  const WebGattCharacteristicInfo({
    required this.serviceId,
    required this.characteristicId,
    required this.canRead,
    required this.canWrite,
    required this.canWriteWithoutResponse,
    required this.canNotify,
    required this.canIndicate,
  });

  final String serviceId;
  final String characteristicId;
  final bool canRead;
  final bool canWrite;
  final bool canWriteWithoutResponse;
  final bool canNotify;
  final bool canIndicate;
}
