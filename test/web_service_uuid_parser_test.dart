import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/utils/web_service_uuid_parser.dart';

void main() {
  test('parses supported UUID forms without device defaults', () {
    expect(parseWebServiceUuids(''), isEmpty);
    expect(
      parseWebServiceUuids(
        '180f, 12345678\n12345678-1234-5678-9abc-1234567890AB;180f',
      ),
      <String>[
        '0000180f-0000-1000-8000-00805f9b34fb',
        '12345678-0000-1000-8000-00805f9b34fb',
        '12345678-1234-5678-9abc-1234567890ab',
      ],
    );
  });

  test('rejects malformed service UUIDs', () {
    expect(parseWebServiceUuids('not-a-uuid'), isNull);
    expect(parseWebServiceUuids('123'), isNull);
  });
}
