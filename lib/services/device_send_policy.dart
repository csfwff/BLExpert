import '../models/device_safety_policy.dart';

enum DeviceSendPolicyReason {
  writeTargetNotAllowed,
  writeWithResponseRequired,
  finalFrameTooLarge,
}

class DeviceSendPolicyDecision {
  const DeviceSendPolicyDecision(this.reasons);

  final List<DeviceSendPolicyReason> reasons;

  bool get allowed => reasons.isEmpty;
}

/// Applies one device profile's restrictions before every BLE write.
class DeviceSendPolicy {
  static DeviceSendPolicyDecision evaluate({
    required DeviceSafetyPolicy policy,
    required String writeTargetKey,
    required bool writeWithResponseSelected,
    required int finalFrameLength,
  }) {
    final List<DeviceSendPolicyReason> reasons = <DeviceSendPolicyReason>[
      if (!policy.allowsWriteTarget(writeTargetKey))
        DeviceSendPolicyReason.writeTargetNotAllowed,
      if (policy.requireWriteWithResponse && !writeWithResponseSelected)
        DeviceSendPolicyReason.writeWithResponseRequired,
      if (policy.maxFinalFrameBytes != null &&
          finalFrameLength > policy.maxFinalFrameBytes!)
        DeviceSendPolicyReason.finalFrameTooLarge,
    ];
    return DeviceSendPolicyDecision(
      List<DeviceSendPolicyReason>.unmodifiable(reasons),
    );
  }
}
