import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blexpert/app/blexpert_app.dart';
import 'package:blexpert/app/app_theme.dart';
import 'package:blexpert/app/design/tool_tooltip.dart';
import 'package:blexpert/services/bluetooth_service.dart';

class _MappingBluetoothService extends MockBluetoothService {
  final StreamController<BluetoothIncomingData> _incomingController =
      StreamController<BluetoothIncomingData>.broadcast();
  bool _disposed = false;

  @override
  Stream<BluetoothIncomingData> watchIncomingData(String deviceId) =>
      _incomingController.stream;

  void emitIncoming(List<int> bytes) {
    _incomingController.add(
      BluetoothIncomingData(
        deviceId: 'ble-001',
        sourceKey: 'mock/mapping',
        bytes: List<int>.unmodifiable(bytes),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _incomingController.close();
    await super.dispose();
  }
}

void main() {
  testWidgets('映射数据使用紧凑两行网格显示值和名称', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'blexpert.workspace-store.v1':
          '''{"version":2,"activeWorkspaceId":"mapped-grid","workspaces":[{"id":"mapped-grid","name":"映射网格","responseMappings":[{"id":"status","name":"状态响应","commandHex":"A1","fields":[{"key":"temperature","label":"温度","offset":0,"byteLength":1,"type":"uint8","byteOrder":"littleEndian","scale":1,"offsetValue":0,"unit":"°C","visibleInDataPanel":true},{"key":"state","label":"状态","offset":1,"byteLength":1,"type":"uint8","byteOrder":"littleEndian","scale":1,"offsetValue":0,"unit":"","visibleInDataPanel":true}]}]}]}''',
    });
    final _MappingBluetoothService bluetoothService =
        _MappingBluetoothService();
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: bluetoothService,
        shadcnPlatform: TargetPlatform.linux,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    bluetoothService.emitIncoming(<int>[0xA1, 0x19, 0x01]);
    await tester.pump(const Duration(milliseconds: 300));

    final Finder panel = find.byKey(
      const ValueKey<String>('mapped-data-panel'),
    );
    expect(tester.widget<Container>(panel).padding, const EdgeInsets.all(8));
    expect(
      find.byKey(const ValueKey<String>('mapped-data-grid')),
      findsOneWidget,
    );

    final Finder temperatureCell = find.byKey(
      const ValueKey<String>('mapped-data-cell-status-temperature'),
    );
    final Finder stateCell = find.byKey(
      const ValueKey<String>('mapped-data-cell-status-state'),
    );
    expect(tester.getSize(temperatureCell).height, 56);
    final AnimatedContainer highlightedCell = tester.widget<AnimatedContainer>(
      find.descendant(
        of: temperatureCell,
        matching: find.byType(AnimatedContainer),
      ),
    );
    final BoxDecoration highlightedDecoration =
        highlightedCell.decoration! as BoxDecoration;
    expect(
      highlightedDecoration.color,
      isNot(AppTheme.colorsOf(tester.element(temperatureCell)).card),
    );
    await tester.pump(const Duration(seconds: 2));
    final AnimatedContainer persistentHighlight = tester
        .widget<AnimatedContainer>(
          find.descendant(
            of: temperatureCell,
            matching: find.byType(AnimatedContainer),
          ),
        );
    expect(
      (persistentHighlight.decoration! as BoxDecoration).color,
      isNot(AppTheme.colorsOf(tester.element(temperatureCell)).card),
    );
    expect(
      tester.getRect(stateCell).left,
      greaterThan(tester.getRect(temperatureCell).left),
    );
    expect(tester.getRect(stateCell).top, tester.getRect(temperatureCell).top);

    final Finder temperatureValue = find.byKey(
      const ValueKey<String>('mapped-data-value-status-temperature'),
    );
    final Finder temperatureName = find.byKey(
      const ValueKey<String>('mapped-data-name-status-temperature'),
    );
    expect(tester.widget<Text>(temperatureValue).data, '25 °C');
    expect(tester.widget<Text>(temperatureName).data, '温度');
    expect(
      tester.getRect(temperatureValue).bottom,
      lessThan(tester.getRect(temperatureName).top),
    );
    expect(tester.widget<Text>(temperatureValue).style?.fontSize, 12);
    expect(tester.widget<Text>(temperatureName).style?.fontSize, 10);

    final ToolTooltip sourceTooltip = tester.widget<ToolTooltip>(
      find.descendant(of: temperatureCell, matching: find.byType(ToolTooltip)),
    );
    expect(sourceTooltip.message, contains('状态响应 | CMD A1'));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await bluetoothService.dispose();
  });
}
