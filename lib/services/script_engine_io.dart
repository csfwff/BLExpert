import 'dart:convert';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';

import '../models/script_config.dart';
import 'script_builtins.dart';

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
  static const int maxScriptCodeUnits = 64 * 1024;
  static const int maxPacketBytes = 4 * 1024;
  static const int maxLogEntries = 20;
  static const int maxLogCodeUnits = 512;
  static const int maxExecutionMilliseconds = 50;
  static const int maxRuntimeMemoryBytes = 16 * 1024 * 1024;

  /// QuickJS is the only flutter_js runtime in this package with a native
  /// interrupt budget. JavaScriptCore remains available on Apple platforms,
  /// but does not expose an equivalent hard execution limit here, so it is
  /// intentionally not treated as executable.
  bool get hasHardExecutionLimit =>
      Platform.isAndroid || Platform.isLinux || Platform.isWindows;

  bool get isRuntimeAvailable => hasHardExecutionLimit;

  Future<ScriptEngineResult> beforeSend(
    ScriptConfig config,
    List<int> bytes,
  ) async {
    if (!config.enabled) {
      return ScriptEngineResult(bytes: bytes, logs: const <String>[]);
    }
    if (!isRuntimeAvailable) {
      throw UnsupportedError(
        'This platform does not provide a bounded JavaScript runtime.',
      );
    }
    if (config.beforeSendScript.trim().isEmpty) {
      throw const FormatException(
        'Enabled script protocol requires beforeSend(context).',
      );
    }
    _validateInput(config.beforeSendScript, bytes);
    return _run(
      script: config.beforeSendScript,
      functionName: 'beforeSend',
      context: <String, dynamic>{'payloadHex': _toHex(bytes)},
      fallbackBytes: bytes,
      requireFrame: true,
    );
  }

  Future<ScriptEngineResult> afterReceive(
    ScriptConfig config,
    List<int> bytes,
  ) async {
    if (!config.enabled || config.afterReceiveScript.trim().isEmpty) {
      return ScriptEngineResult(bytes: bytes, logs: const <String>[]);
    }
    if (!isRuntimeAvailable) {
      return ScriptEngineResult(
        bytes: bytes,
        logs: const <String>['当前平台未执行 JavaScript 协议脚本，已保留原始接收数据。'],
        valid: false,
      );
    }
    _validateInput(config.afterReceiveScript, bytes);
    return _run(
      script: config.afterReceiveScript,
      functionName: 'afterReceive',
      context: <String, dynamic>{'frameHex': _toHex(bytes)},
      fallbackBytes: bytes,
      requireFrame: false,
    );
  }

  ScriptEngineResult _run({
    required String script,
    required String functionName,
    required Map<String, dynamic> context,
    required List<int> fallbackBytes,
    required bool requireFrame,
  }) {
    final JavascriptRuntime runtime = _createRuntime();
    final String contextJson = jsonEncode(context);
    final String harness =
        '''
var __blexpertContext = $contextJson;
$scriptBuiltins
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
    try {
      final JsEvalResult value = runtime.evaluate(harness);
      if (value.isError) {
        throw StateError(_runtimeError(value.stringResult));
      }
      final Map<String, dynamic> payload =
          jsonDecode(value.stringResult) as Map<String, dynamic>;
      if (payload['ok'] != true) {
        final String error =
            payload['error']?.toString() ?? 'Script execution failed';
        throw StateError(error.substring(0, error.length.clamp(0, 256)));
      }
      final Map<String, dynamic> result = Map<String, dynamic>.from(
        payload['result'] as Map? ?? const <String, dynamic>{},
      );
      final String? frameHex = result['frameHex']?.toString();
      final String? payloadHex = result['payloadHex']?.toString();
      final String? outputHex = frameHex ?? payloadHex;
      final List<int> output = outputHex == null || outputHex.trim().isEmpty
          ? (requireFrame
                ? throw const FormatException(
                    'Script must return a non-empty frameHex.',
                  )
                : fallbackBytes)
          : _parseHex(outputHex);
      if (output.length > maxPacketBytes) {
        throw const FormatException(
          'Script output exceeds the 4096-byte limit.',
        );
      }
      final List<String> logs =
          (result['logs'] as List<dynamic>? ?? const <dynamic>[])
              .take(maxLogEntries)
              .map((dynamic item) {
                final String text = item.toString();
                return text.substring(0, text.length.clamp(0, maxLogCodeUnits));
              })
              .toList(growable: false);
      return ScriptEngineResult(
        bytes: output,
        logs: logs,
        payloadHex: payloadHex,
        cmdHex: result['cmdHex']?.toString(),
        dataHex: result['dataHex']?.toString(),
        valid: result['valid'] as bool?,
      );
    } finally {
      runtime.dispose();
    }
  }

  JavascriptRuntime _createRuntime() {
    if (hasHardExecutionLimit) {
      return QuickJsRuntime2(
        timeout: maxExecutionMilliseconds,
        // flutter_js 0.8.7's Windows bridge does not export
        // jsSetMemoryLimit, although its Dart API exposes the option.
        // Keep QuickJS's interrupt-based execution limit on Windows.
        memoryLimit: Platform.isWindows ? null : maxRuntimeMemoryBytes,
      );
    }
    return getJavascriptRuntime(xhr: false);
  }

  String _runtimeError(String message) {
    final String normalized = message.trim();
    final String lower = normalized.toLowerCase();
    if (lower.contains('interrupt') || lower.contains('timeout')) {
      return 'Script execution exceeded the '
          '$maxExecutionMilliseconds ms limit.';
    }
    if (normalized.isEmpty) return 'Script execution failed.';
    return normalized.substring(0, normalized.length.clamp(0, 256));
  }

  void _validateInput(String script, List<int> bytes) {
    if (script.length > maxScriptCodeUnits) {
      throw const FormatException('Script exceeds the 64 KiB limit.');
    }
    if (bytes.length > maxPacketBytes) {
      throw const FormatException('Script input exceeds the 4096-byte limit.');
    }
  }

  void dispose() {}
}

List<int> _parseHex(String value) {
  final String compact = value.replaceAll(RegExp(r'[\s:_-]'), '');
  if (compact.isEmpty ||
      compact.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(compact)) {
    throw const FormatException('Script returned invalid HEX.');
  }
  return <int>[
    for (int i = 0; i < compact.length; i += 2)
      int.parse(compact.substring(i, i + 2), radix: 16),
  ];
}

String _toHex(List<int> bytes) => bytes
    .map((int byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
