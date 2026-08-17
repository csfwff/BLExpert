import '../models/script_config.dart';

class ScriptEngineResult {
  const ScriptEngineResult({
    required this.bytes,
    required this.logs,
    this.payloadHex,
    this.cmdHex,
    this.dataHex,
    this.valid,
  });

  final List<int> bytes;
  final List<String> logs;
  final String? payloadHex;
  final String? cmdHex;
  final String? dataHex;
  final bool? valid;
}

class ScriptEngineService {
  static const int maxPacketBytes = 4 * 1024;

  bool get isRuntimeAvailable => false;

  bool get hasHardExecutionLimit => false;

  Future<ScriptEngineResult> beforeSend(
    ScriptConfig config,
    List<int> bytes,
  ) async {
    if (config.enabled) {
      throw UnsupportedError(
        'Web does not execute JavaScript protocol scripts.',
      );
    }
    return const ScriptEngineResult(
      bytes: <int>[],
      logs: <String>['Web 端当前不执行 JavaScript 协议脚本。'],
    ).copyWith(bytes: bytes);
  }

  Future<ScriptEngineResult> afterReceive(
    ScriptConfig config,
    List<int> bytes,
  ) async {
    if (config.enabled) {
      return ScriptEngineResult(
        bytes: bytes,
        logs: const <String>['Web 端未执行 JavaScript，已跳过响应映射。'],
        valid: false,
      );
    }
    return const ScriptEngineResult(
      bytes: <int>[],
      logs: <String>['Web 端当前不执行 JavaScript 协议脚本。'],
    ).copyWith(bytes: bytes);
  }

  void dispose() {}
}

extension on ScriptEngineResult {
  ScriptEngineResult copyWith({List<int>? bytes}) {
    return ScriptEngineResult(
      bytes: bytes ?? this.bytes,
      logs: logs,
      payloadHex: payloadHex,
      cmdHex: cmdHex,
      dataHex: dataHex,
      valid: valid,
    );
  }
}
