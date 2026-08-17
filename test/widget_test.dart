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
    expect(find.text('当前上下文'), findsOneWidget);
    expect(find.text('调试'), findsOneWidget);
  });

  testWidgets('Inspector 开关不遮挡控制台清空操作', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    final Rect clearButton = tester.getRect(find.byTooltip('清空'));
    final Rect inspectorToggle = tester.getRect(find.byTooltip('收起上下文面板'));

    expect(clearButton.overlaps(inspectorToggle), isFalse);
    expect(clearButton.right, lessThanOrEqualTo(inspectorToggle.left - 4));
  });

  testWidgets('可从语言菜单切换至英文界面', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英文'));
    await tester.pumpAndSettle();

    expect(find.text('Console'), findsOneWidget);
    expect(find.text('Current context'), findsOneWidget);
  });

  testWidgets('工作区可导出、预览并确认替换导入', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出工作区'));
    await tester.pumpAndSettle();
    expect(find.text('导出工作区'), findsOneWidget);
    expect(find.textContaining('"workspaces"'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入工作区'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认替换'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextField).last,
      '{"version":1,"activeWorkspaceId":"imported","workspaces":[{"id":"imported","name":"导入测试工作区","scriptConfig":{"enabled":true,"beforeSendScript":"function beforeSend() { return {}; }","afterReceiveScript":"","language":"javascript"}}]}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '检查导入'));
    await tester.pumpAndSettle();

    expect(find.textContaining('脚本工作区 1 个'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认替换'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, '确认替换'));
    await tester.pumpAndSettle();

    expect(find.text('导入测试工作区'), findsWidgets);
  });

  testWidgets('可合并导入并选择保留冲突工作区', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    Future<void> importAndConfirm(String jsonText) async {
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入工作区'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, jsonText);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '检查导入'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确认替换'));
      await tester.pumpAndSettle();
    }

    await importAndConfirm(
      '{"version":2,"activeWorkspaceId":"conflict","workspaces":[{"id":"conflict","name":"原始工作区"}]}',
    );
    expect(find.text('原始工作区'), findsWidgets);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入工作区'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '{"version":2,"activeWorkspaceId":"new","workspaces":[{"id":"conflict","name":"覆盖版本"},{"id":"new","name":"新增工作区"}]}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '检查导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合并导入'));
    await tester.pumpAndSettle();

    expect(find.text('冲突处理'), findsOneWidget);
    expect(find.text('保留当前'), findsOneWidget);
    await tester.tap(find.text('保留当前'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('选择工作区'));
    await tester.pumpAndSettle();
    expect(find.text('原始工作区'), findsWidgets);
    expect(find.text('新增工作区'), findsWidgets);
    expect(find.text('覆盖版本'), findsNothing);
  });

  testWidgets('工作台可在调试和配置工作区间切换', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('控制台'), findsOneWidget);
    expect(find.text('特征'), findsOneWidget);
    await tester.tap(find.text('配置'));
    await tester.pumpAndSettle();

    expect(find.text('工作区'), findsOneWidget);
    expect(find.text('设备型号'), findsOneWidget);
    expect(find.byTooltip('编辑工作区'), findsOneWidget);
  });

  testWidgets('工作区指令可选择显示在右侧快捷区', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.text('配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('指令'));
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
    await tester.tap(find.text('调试'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('查询状态：AA 55 01'), findsOneWidget);
    expect(find.text('AA'), findsOneWidget);
    expect(find.text('55'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
  });

  testWidgets('可在左侧新增协议定义', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.text('配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('协议'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '主协议');
    await tester.enterText(find.byType(TextField).at(1), '测试设备主链路');
    await tester.tap(find.byTooltip('新增片段').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('固定 HEX').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '主协议'), findsOneWidget);
    expect(find.text('固定 HEX'), findsWidgets);
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

  testWidgets('高风险命令在发送前要求确认', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.byTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建指令'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '恢复出厂设置');
    await tester.enterText(find.byType(TextField).at(1), '维护');
    await tester.enterText(find.byType(TextField).at(2), 'AA 55');
    await tester.tap(find.widgetWithText(FilledButton, '保存').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('调试'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('发送 恢复出厂设置'));
    await tester.pumpAndSettle();

    expect(find.text('确认受保护发送'), findsOneWidget);
    expect(find.textContaining('恢复出厂设置'), findsWidgets);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('确认受保护发送'), findsNothing);
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

  testWidgets('会话记录可筛选并导出当前结果', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: MockBluetoothService(
          connectError: StateError('session-record-filter-test'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'session-record-filter-test',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1/'), findsOneWidget);
    await tester.tap(find.byTooltip('添加书签'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '书签'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消书签'), findsOneWidget);
    await tester.tap(find.byTooltip('导出会话记录'));
    await tester.pumpAndSettle();
    expect(find.text('导出会话记录'), findsOneWidget);
    expect(find.textContaining('"kind": "error"'), findsOneWidget);
    expect(find.textContaining('"bookmarked": true'), findsOneWidget);
  });

  testWidgets('发送记录可按指令筛选并导出', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.byTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建指令'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '诊断命令');
    await tester.enterText(find.byType(TextField).at(1), '诊断');
    await tester.enterText(find.byType(TextField).at(2), 'AA 55');
    await tester.tap(find.widgetWithText(FilledButton, '保存').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('调试'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('发送 诊断命令'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();

    final Finder commandFilter = find.byWidgetPredicate(
      (Widget widget) => widget is DropdownButtonFormField<String?>,
    );
    expect(commandFilter, findsNWidgets(3));
    await tester.tap(commandFilter.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('诊断命令').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导出会话记录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"commandName": "诊断命令"'), findsOneWidget);
    expect(find.textContaining('"transactionId": "tx-'), findsOneWidget);
  });
}
