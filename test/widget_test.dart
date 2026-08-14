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

  testWidgets('工作台可切换工作区与设备功能页', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('通信'), findsOneWidget);
    expect(find.text('工作区设置'), findsOneWidget);
    expect(find.text('协议定义'), findsOneWidget);
    await tester.tap(find.text('工作区设置'));
    await tester.pumpAndSettle();
    expect(find.text('设备型号'), findsOneWidget);
    expect(find.byTooltip('编辑工作区'), findsOneWidget);

    await tester.tap(find.text('数据'));
    await tester.pumpAndSettle();
    expect(find.text('暂无数据'), findsOneWidget);

    await tester.tap(find.text('快捷指令'));
    await tester.pumpAndSettle();
    expect(find.text('尚未选择快捷指令。'), findsOneWidget);
  });

  testWidgets('工作区指令可选择显示在右侧快捷区', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.text('指令集'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建指令'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '查询状态');
    await tester.enterText(find.byType(TextField).at(1), '查询');
    await tester.enterText(find.byType(TextField).at(2), 'AA 55 01');
    await tester.tap(find.widgetWithText(FilledButton, '保存').first);
    await tester.pumpAndSettle();

    expect(find.text('查询'), findsOneWidget);
    expect(find.text('查询状态'), findsWidgets);
    expect(find.text('AA 55 01'), findsOneWidget);

    await tester.tap(find.byTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('快捷指令'));
    await tester.pumpAndSettle();
    expect(find.text('查询状态'), findsWidgets);
  });

  testWidgets('可在左侧新增协议定义', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.text('协议定义'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑协议'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '主协议');
    await tester.enterText(find.byType(TextField).at(1), '测试设备主链路');
    await tester.tap(find.byTooltip('新增片段').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '帧头');
    await tester.enterText(find.byType(TextField).at(2), 'AA 55');
    await tester.tap(find.widgetWithText(FilledButton, '保存').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存').first);
    await tester.pumpAndSettle();

    expect(find.text('主协议'), findsOneWidget);
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
