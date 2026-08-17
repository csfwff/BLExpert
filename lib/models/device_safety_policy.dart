/// Persisted transport restrictions for one known Bluetooth device.
///
/// Empty allowed write targets and a null size limit preserve the legacy,
/// unrestricted debugging behavior.
class DeviceSafetyPolicy {
  const DeviceSafetyPolicy({
    this.allowedWriteTargetKeys = const <String>[],
    this.maxFinalFrameBytes,
    this.requireWriteWithResponse = false,
  });

  final List<String> allowedWriteTargetKeys;
  final int? maxFinalFrameBytes;
  final bool requireWriteWithResponse;

  factory DeviceSafetyPolicy.fromJson(Map<String, dynamic> json) {
    final int? configuredLimit = json['maxFinalFrameBytes'] as int?;
    return DeviceSafetyPolicy(
      allowedWriteTargetKeys:
          (json['allowedWriteTargetKeys'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic item) => item.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false),
      maxFinalFrameBytes: configuredLimit != null && configuredLimit > 0
          ? configuredLimit
          : null,
      requireWriteWithResponse:
          json['requireWriteWithResponse'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (allowedWriteTargetKeys.isNotEmpty)
      'allowedWriteTargetKeys': allowedWriteTargetKeys,
    if (maxFinalFrameBytes != null) 'maxFinalFrameBytes': maxFinalFrameBytes,
    if (requireWriteWithResponse)
      'requireWriteWithResponse': requireWriteWithResponse,
  };

  DeviceSafetyPolicy copyWith({
    List<String>? allowedWriteTargetKeys,
    int? maxFinalFrameBytes,
    bool clearMaxFinalFrameBytes = false,
    bool? requireWriteWithResponse,
  }) => DeviceSafetyPolicy(
    allowedWriteTargetKeys:
        allowedWriteTargetKeys ?? this.allowedWriteTargetKeys,
    maxFinalFrameBytes: clearMaxFinalFrameBytes
        ? null
        : (maxFinalFrameBytes ?? this.maxFinalFrameBytes),
    requireWriteWithResponse:
        requireWriteWithResponse ?? this.requireWriteWithResponse,
  );

  bool allowsWriteTarget(String targetKey) =>
      allowedWriteTargetKeys.isEmpty ||
      allowedWriteTargetKeys.any(
        (String value) => value.toLowerCase() == targetKey.toLowerCase(),
      );
}
