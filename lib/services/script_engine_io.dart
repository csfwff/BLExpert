import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

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
  JavascriptRuntime? _runtime;

  bool get isRuntimeAvailable => true;

  Future<ScriptEngineResult> beforeSend(
    ScriptConfig config,
    List<int> bytes,
  ) async {
    if (!config.enabled || config.beforeSendScript.trim().isEmpty) {
      return ScriptEngineResult(bytes: bytes, logs: const <String>[]);
    }
    return _run(
      script: config.beforeSendScript,
      functionName: 'beforeSend',
      context: <String, dynamic>{'payloadHex': _toHex(bytes)},
      fallbackBytes: bytes,
    );
  }

  Future<ScriptEngineResult> afterReceive(
    ScriptConfig config,
    List<int> bytes,
  ) async {
    if (!config.enabled || config.afterReceiveScript.trim().isEmpty) {
      return ScriptEngineResult(bytes: bytes, logs: const <String>[]);
    }
    return _run(
      script: config.afterReceiveScript,
      functionName: 'afterReceive',
      context: <String, dynamic>{'frameHex': _toHex(bytes)},
      fallbackBytes: bytes,
    );
  }

  ScriptEngineResult _run({
    required String script,
    required String functionName,
    required Map<String, dynamic> context,
    required List<int> fallbackBytes,
  }) {
    final JavascriptRuntime runtime = _runtime ??= getJavascriptRuntime();
    final String contextJson = jsonEncode(context);
    final String harness = '''
var __blexpertContext = $contextJson;
$script
(function() {
  try {
    var fn = typeof $functionName === 'function' ? $functionName : null;
    if (!fn) {
      return JSON.stringify({ ok: false, error: 'Missing function: $functionName' });
    }
    var result = fn(__blexpertContext);
    return JSON.stringify({ ok: true, result: result || {} });
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error) });
  }
})();
''';
    final JsEvalResult value = runtime.evaluate(harness);
    final Map<String, dynamic> payload =
        jsonDecode(value.stringResult) as Map<String, dynamic>;
    if (payload['ok'] != true) {
      throw StateError(payload['error']?.toString() ?? 'Script execution failed');
    }
    final Map<String, dynamic> result = Map<String, dynamic>.from(
      payload['result'] as Map? ?? const <String, dynamic>{},
    );
    final String? frameHex = result['frameHex']?.toString();
    final String? payloadHex = result['payloadHex']?.toString();
    final List<int> bytes = _parseHex(frameHex ?? payloadHex ?? '') ?? fallbackBytes;
    return ScriptEngineResult(
      bytes: bytes,
      logs: (result['logs'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      payloadHex: payloadHex,
      cmdHex: result['cmdHex']?.toString(),
      dataHex: result['dataHex']?.toString(),
      valid: result['valid'] as bool?,
    );
  }

  void dispose() {
    _runtime?.dispose();
    _runtime = null;
  }
}

List<int>? _parseHex(String value) {
  final String compact = value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (compact.isEmpty || compact.length.isOdd) return null;
  return <int>[
    for (int i = 0; i < compact.length; i += 2)
      int.parse(compact.substring(i, i + 2), radix: 16),
  ];
}

String _toHex(List<int> bytes) => bytes
    .map((int byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
