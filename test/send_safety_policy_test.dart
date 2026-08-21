import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/services/send_safety_policy.dart';

void main() {
  test('requires confirmation when a script changes the final frame', () {
    final SendSafetyDecision decision = SendSafetyPolicy.evaluate(
      businessPayload: <int>[0x01],
      finalFrame: <int>[0xAA, 0x01, 0x55],
      scriptEnabled: true,
    );

    expect(decision.requiresConfirmation, isTrue);
    expect(decision.reasons, <SendSafetyReason>[
      SendSafetyReason.scriptTransformed,
    ]);
  });

  test('can skip confirmation for a script-transformed frame', () {
    final SendSafetyDecision decision = SendSafetyPolicy.evaluate(
      businessPayload: <int>[0x01],
      finalFrame: <int>[0xAA, 0x01, 0x55],
      scriptEnabled: true,
      confirmTransformedSend: false,
    );

    expect(decision.requiresConfirmation, isFalse);
  });

  test('requires confirmation for potentially dangerous command names', () {
    final SendSafetyDecision decision = SendSafetyPolicy.evaluate(
      businessPayload: <int>[0x01],
      finalFrame: <int>[0x01],
      scriptEnabled: false,
      commandName: '恢复出厂设置',
    );

    expect(decision.requiresConfirmation, isTrue);
    expect(decision.reasons, <SendSafetyReason>[
      SendSafetyReason.potentiallyDangerousCommand,
    ]);
  });

  test('does not require confirmation for ordinary unchanged commands', () {
    final SendSafetyDecision decision = SendSafetyPolicy.evaluate(
      businessPayload: <int>[0x01],
      finalFrame: <int>[0x01],
      scriptEnabled: false,
      commandName: '查询状态',
    );

    expect(decision.requiresConfirmation, isFalse);
  });

  test('requires confirmation for an explicitly protected command', () {
    final SendSafetyDecision decision = SendSafetyPolicy.evaluate(
      businessPayload: <int>[0x01],
      finalFrame: <int>[0x01],
      scriptEnabled: false,
      commandName: '设备控制',
      commandRequiresConfirmation: true,
    );

    expect(decision.requiresConfirmation, isTrue);
    expect(decision.reasons, <SendSafetyReason>[
      SendSafetyReason.explicitCommandPolicy,
    ]);
  });

  test('rate limiter rejects sends inside the configured interval', () {
    final ScriptSendRateLimiter limiter = ScriptSendRateLimiter();
    final DateTime start = DateTime(2026, 8, 17, 12);

    expect(limiter.tryAcquire(start), isTrue);
    expect(
      limiter.tryAcquire(start.add(const Duration(milliseconds: 199))),
      isFalse,
    );
    expect(
      limiter.remaining(start.add(const Duration(milliseconds: 199))),
      const Duration(milliseconds: 1),
    );
    expect(
      limiter.tryAcquire(start.add(const Duration(milliseconds: 200))),
      isTrue,
    );
  });
}
