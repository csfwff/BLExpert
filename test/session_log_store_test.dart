import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blexpert/models/session_log_record.dart';
import 'package:blexpert/services/session_log_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('persists the newest bounded session records', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SessionLogStore store = SessionLogStore(preferences);
    final List<SessionLogRecord> records = <SessionLogRecord>[
      for (int index = 0; index <= SessionLogStore.maxRecords; index++)
        SessionLogRecord(
          kind: SessionLogKind.received,
          timestamp: DateTime.utc(2026, 8, 17, 12, 0, index),
          data: List<int>.filled(SessionLogStore.maxDataBytes + 1, index % 256),
          message: 'x' * (SessionLogStore.maxMessageLength + 1),
        ),
    ];

    await store.save(records);
    final List<SessionLogRecord> restored = await store.load();

    expect(restored, hasLength(SessionLogStore.maxRecords));
    expect(restored.first.timestamp.second, 0);
    expect(restored.first.data, hasLength(SessionLogStore.maxDataBytes));
    expect(restored.first.message, hasLength(SessionLogStore.maxMessageLength));
  });

  test('clearing removes persisted records', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SessionLogStore store = SessionLogStore(preferences);
    await store.save(<SessionLogRecord>[
      SessionLogRecord.system(timestamp: DateTime.utc(2026), message: 'ready'),
    ]);

    await store.clear();

    expect(await store.load(), isEmpty);
  });

  test('round-trips characteristic and command metadata', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SessionLogStore store = SessionLogStore(preferences);
    await store.save(<SessionLogRecord>[
      SessionLogRecord(
        kind: SessionLogKind.sent,
        timestamp: DateTime.utc(2026, 8, 17, 12),
        data: const <int>[0xAA, 0x55],
        characteristicId: '0000fff1',
        commandName: '查询状态',
        transactionId: 'tx-1234',
        bookmarked: true,
      ),
    ]);

    final SessionLogRecord restored = (await store.load()).single;

    expect(restored.characteristicId, '0000fff1');
    expect(restored.commandName, '查询状态');
    expect(restored.transactionId, 'tx-1234');
    expect(restored.bookmarked, isTrue);
  });

  test('ignores malformed persisted data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'blexpert.session-log-store.v1': '{"records":[{"kind":"sent"}]}',
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    expect(await SessionLogStore(preferences).load(), isEmpty);
  });
}
