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
  bool get isRuntimeAvailable => false;

  Future<ScriptEngineResult> beforeSend(dynamic config, List<int> bytes) async {
    return const ScriptEngineResult(
      bytes: <int>[],
      logs: <String>['Web 端当前不执行 JavaScript 协议脚本。'],
    ).copyWith(bytes: bytes);
  }

  Future<ScriptEngineResult> afterReceive(dynamic config, List<int> bytes) async {
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
