import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/models/script_config.dart';
import 'package:blexpert/services/script_engine_io.dart';

void main() {
  test('declares bounded native runtime policy', () {
    expect(ScriptEngineService.maxExecutionMilliseconds, 50);
    expect(ScriptEngineService.maxRuntimeMemoryBytes, 16 * 1024 * 1024);
    expect(
      ScriptEngineService().hasHardExecutionLimit,
      Platform.isAndroid || Platform.isLinux || Platform.isWindows,
    );
  });

  const String nativeRuntimeTestSkip =
      'Requires the flutter_js native QuickJS bridge; run on a built target.';

  const ScriptConfig finiteConfig = ScriptConfig(
    enabled: true,
    beforeSendScript: '''
function beforeSend(context) {
  return { frameHex: context.payloadHex, logs: ['ok'] };
}
''',
    afterReceiveScript: '',
    language: 'javascript',
  );

  test('executes a bounded beforeSend script', () async {
    final ScriptEngineService engine = ScriptEngineService();
    addTearDown(engine.dispose);

    final ScriptEngineResult result = await engine.beforeSend(
      finiteConfig,
      <int>[0xAA, 0x01],
    );

    expect(result.bytes, <int>[0xAA, 0x01]);
    expect(result.logs, <String>['ok']);
  }, skip: nativeRuntimeTestSkip);

  test(
    'interrupts an unbounded script on QuickJS platforms',
    () async {
      final ScriptEngineService engine = ScriptEngineService();
      addTearDown(engine.dispose);
      if (!engine.hasHardExecutionLimit) return;

      const ScriptConfig infiniteConfig = ScriptConfig(
        enabled: true,
        beforeSendScript: '''
function beforeSend(context) {
  while (true) {}
}
''',
        afterReceiveScript: '',
        language: 'javascript',
      );

      await expectLater(
        engine.beforeSend(infiniteConfig, <int>[1]),
        throwsA(
          predicate<Object>(
            (Object error) =>
                error.toString().contains('execution exceeded 50 ms limit'),
          ),
        ),
      );
    },
    skip: nativeRuntimeTestSkip,
  );
}
