import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/models/device_safety_policy.dart';
import 'package:blexpert/services/device_send_policy.dart';

void main() {
  test('allows legacy device profiles without configured restrictions', () {
    final DeviceSendPolicyDecision decision = DeviceSendPolicy.evaluate(
      policy: const DeviceSafetyPolicy(),
      writeTargetKey: 'service/characteristic',
      writeWithResponseSelected: false,
      finalFrameLength: 2048,
    );

    expect(decision.allowed, isTrue);
  });

  test('rejects a write target outside the configured allowlist', () {
    final DeviceSendPolicyDecision decision = DeviceSendPolicy.evaluate(
      policy: const DeviceSafetyPolicy(
        allowedWriteTargetKeys: <String>['service/allowed'],
      ),
      writeTargetKey: 'service/rejected',
      writeWithResponseSelected: true,
      finalFrameLength: 1,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reasons, <DeviceSendPolicyReason>[
      DeviceSendPolicyReason.writeTargetNotAllowed,
    ]);
  });

  test('enforces configured size and acknowledged-write requirements', () {
    final DeviceSendPolicyDecision decision = DeviceSendPolicy.evaluate(
      policy: const DeviceSafetyPolicy(
        maxFinalFrameBytes: 20,
        requireWriteWithResponse: true,
      ),
      writeTargetKey: 'service/characteristic',
      writeWithResponseSelected: false,
      finalFrameLength: 21,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reasons, <DeviceSendPolicyReason>[
      DeviceSendPolicyReason.writeWithResponseRequired,
      DeviceSendPolicyReason.finalFrameTooLarge,
    ]);
  });
}
