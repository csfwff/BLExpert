import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/main.dart';
import 'package:blexpert/services/bluetooth_service.dart';

void main() {
  Future<void> pumpDesktopApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: MockBluetoothService(),
      ),
    );
    await tester.pump();
  }

  testWidgets('应用启动后显示 BLExpert 调试工作台', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('BLExpert'), findsWidgets);
    expect(find.text('默认工作区'), findsOneWidget);
    expect(find.text('控制台'), findsOneWidget);
    expect(find.text('快捷指令'), findsOneWidget);
  });

  testWidgets('可从语言菜单切换至英文界面', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.byTooltip('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英文'));
    await tester.pumpAndSettle();

    expect(find.text('Console'), findsOneWidget);
    expect(find.text('Quick commands'), findsOneWidget);
  });

  testWidgets('连接后可选择写入与订阅特征', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.byTooltip('连接设备'));
    await tester.pumpAndSettle();

    expect(find.text('0000FFF1-0000-1000-8000-00805F9B34FB'), findsOneWidget);
    expect(find.text('0000FFF2-0000-1000-8000-00805F9B34FB'), findsOneWidget);

    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Notify').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Indicate').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Indicate').first)
          .selected,
      isTrue,
    );

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '发送数据'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('仅支持无响应写入的特征可设为写入目标', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.byTooltip('连接设备'));
    await tester.pumpAndSettle();

    final Finder writeTargets = find.text('写入目标');
    expect(writeTargets, findsNWidgets(1));
    await tester.tap(writeTargets);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '写入目标'))
          .selected,
      isTrue,
    );
  });

  testWidgets('连接失败会写入控制台错误日志', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: MockBluetoothService(
          connectError: StateError(
            'The BLE device is no longer available. Scan again and reconnect.',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('连接设备'));
    await tester.pumpAndSettle();

    expect(find.text('设备已离开蓝牙范围或停止广播，请重新扫描后再连接。'), findsWidgets);
    expect(find.textContaining('Bad state:'), findsOneWidget);
  });
}
