enum SendSafetyReason {
  scriptTransformed,
  potentiallyDangerousCommand,
  explicitCommandPolicy,
}

class SendSafetyDecision {
  const SendSafetyDecision(this.reasons);

  final List<SendSafetyReason> reasons;

  bool get requiresConfirmation => reasons.isNotEmpty;
}

/// Keeps confirmation rules deterministic and independent from BLE/UI code.
class SendSafetyPolicy {
  static final RegExp _dangerousCommandPattern = RegExp(
    r'\b(reset|erase|factory|boot|upgrade|flash|auth)\b|重置|复位|擦除|恢复出厂|升级|刷写|认证',
    caseSensitive: false,
  );

  static SendSafetyDecision evaluate({
    required List<int> businessPayload,
    required List<int> finalFrame,
    required bool scriptEnabled,
    String? commandName,
    bool commandRequiresConfirmation = false,
  }) {
    final List<SendSafetyReason> reasons = <SendSafetyReason>[
      if (scriptEnabled && !_sameBytes(businessPayload, finalFrame))
        SendSafetyReason.scriptTransformed,
      if (commandName != null &&
          _dangerousCommandPattern.hasMatch(commandName.trim()))
        SendSafetyReason.potentiallyDangerousCommand,
      if (commandRequiresConfirmation) SendSafetyReason.explicitCommandPolicy,
    ];
    return SendSafetyDecision(List<SendSafetyReason>.unmodifiable(reasons));
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

/// Limits script-generated writes without affecting raw BLE debugging traffic.
class ScriptSendRateLimiter {
  ScriptSendRateLimiter({
    this.minimumInterval = const Duration(milliseconds: 200),
  });

  final Duration minimumInterval;
  DateTime? _lastAcquiredAt;

  Duration? remaining(DateTime now) {
    final DateTime? last = _lastAcquiredAt;
    if (last == null) return null;
    final Duration elapsed = now.difference(last);
    if (elapsed >= minimumInterval) return null;
    return minimumInterval - elapsed;
  }

  bool tryAcquire(DateTime now) {
    if (remaining(now) != null) return false;
    _lastAcquiredAt = now;
    return true;
  }

  void reset() => _lastAcquiredAt = null;
}
