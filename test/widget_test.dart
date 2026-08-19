import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'package:blexpert/main.dart';
import 'package:blexpert/app/design/tool_button.dart';
import 'package:blexpert/app/design/tool_select.dart';
import 'package:blexpert/app/design/tool_toggle.dart';
import 'package:blexpert/app/design/tool_tooltip.dart';
import 'package:blexpert/models/command_definition.dart';
import 'package:blexpert/services/bluetooth_service.dart';

class _DelayedBluetoothService extends MockBluetoothService {
  final Completer<void> _connectCompleter = Completer<void>();

  @override
  Future<void> connect(String deviceId) async {
    await _connectCompleter.future;
    await super.connect(deviceId);
  }

  void completeConnection() {
    if (!_connectCompleter.isCompleted) _connectCompleter.complete();
  }
}

void main() {
  Finder findToolTooltip(String message) => find.byWidgetPredicate(
    (Widget widget) => widget is ToolTooltip && widget.message == message,
    description: 'ToolTooltip with message "$message"',
  );

  Future<void> pumpDesktopApp(
    WidgetTester tester, {
    BluetoothService? bluetoothService,
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: bluetoothService ?? MockBluetoothService(),
        shadcnPlatform: TargetPlatform.linux,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openWorkspaceSelector(WidgetTester tester) async {
    await tester.tap(findToolTooltip('选择工作区'));
    // shadcn's anchored menu keeps an overlay ticker while it is open.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> selectAppMode(WidgetTester tester, String mode) async {
    await tester.tap(find.byKey(ValueKey<String>('app-mode-$mode')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('应用启动后显示 BLExpert 调试工作台', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('BLExpert'), findsWidgets);
    expect(find.text('未知设备'), findsNothing);
    expect(find.text('默认工作区'), findsOneWidget);
    expect(find.text('控制台'), findsOneWidget);
    expect(find.text('当前上下文'), findsOneWidget);
    expect(find.text('调试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('app-mode-navigation')),
      findsOneWidget,
    );
    expect(find.byType(shad.NavigationRail), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('app-mode-navigation')))
          .width,
      88,
    );
    for (final String label in <String>['调试', '配置', '记录', '设置']) {
      final Text text = tester.widget<Text>(find.text(label));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    }
  });

  testWidgets('扫描和连接按钮显示当前动作与连接状态', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('开始扫描'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('scan-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('connection-action-button')),
      findsOneWidget,
    );

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('connection-action-button')),
        matching: find.text('已连接 · 断开设备'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('首页工作区和蓝牙设备选择使用 shadcn 控件', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(
      tester
          .widget<shad.Button>(
            find.byKey(const ValueKey<String>('workspace-selector')),
          )
          .style,
      isA<shad.ButtonStyle>(),
    );
    expect(
      find.byKey(const ValueKey<String>('bluetooth-device-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('bluetooth-device-selector')),
      findsOneWidget,
    );

    await openWorkspaceSelector(tester);
    expect(find.byType(shad.DropdownMenu), findsOneWidget);
    await tester.tap(findToolTooltip('选择工作区'));
    await tester.pump();
  });

  testWidgets('首页工具栏选择器与操作按钮使用统一高度', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    final List<Finder> controls = <Finder>[
      find.byKey(const ValueKey<String>('workspace-selector')),
      find.byKey(const ValueKey<String>('bluetooth-device-selector')),
      find.byKey(const ValueKey<String>('connection-action-button')),
      find.byKey(const ValueKey<String>('scan-button')),
    ];
    for (final Finder control in controls) {
      expect(tester.getSize(control).height, 36);
    }

    expect(
      tester
          .widget<shad.Button>(
            find.byKey(const ValueKey<String>('connection-action-button')),
          )
          .alignment,
      Alignment.center,
    );
    expect(
      tester
          .widget<shad.Button>(
            find.byKey(const ValueKey<String>('scan-button')),
          )
          .alignment,
      Alignment.center,
    );
  });

  testWidgets('连接中图标保持正方形且按钮内容居中', (WidgetTester tester) async {
    final _DelayedBluetoothService bluetoothService =
        _DelayedBluetoothService();
    await pumpDesktopApp(tester, bluetoothService: bluetoothService);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pump();

    final Finder connectionButton = find.byKey(
      const ValueKey<String>('connection-action-button'),
    );
    final Finder loadingIcon = find.descendant(
      of: connectionButton,
      matching: find.byType(ToolLoadingIcon),
    );
    final Finder progressIndicator = find.descendant(
      of: connectionButton,
      matching: find.byType(shad.CircularProgressIndicator),
    );

    expect(loadingIcon, findsOneWidget);
    expect(tester.getSize(loadingIcon).width, 16);
    expect(tester.getSize(progressIndicator), const Size.square(16));
    expect(
      tester.widget<shad.Button>(connectionButton).alignment,
      Alignment.center,
    );

    bluetoothService.completeConnection();
    await tester.pumpAndSettle();
  });

  testWidgets('窄屏调试工作区保留搜索和底部模式导航', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: MockBluetoothService(),
        shadcnPlatform: TargetPlatform.linux,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('console-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app-mode-navigation-mobile')),
      findsOneWidget,
    );
    final Text sendLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('console-send-button')),
        matching: find.text('发送数据'),
      ),
    );
    expect(sendLabel.maxLines, 1);
    expect(sendLabel.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inspector 开关不遮挡控制台清空操作', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    final Rect clearButton = tester.getRect(findToolTooltip('清空'));
    final Rect inspectorToggle = tester.getRect(findToolTooltip('收起上下文面板'));

    expect(clearButton.overlaps(inspectorToggle), isFalse);
    expect(clearButton.right, lessThanOrEqualTo(inspectorToggle.left - 4));
  });

  testWidgets('发送区模式与行尾控件使用紧凑统一尺寸', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    final Rect modeToggle = tester.getRect(
      find.byKey(const ValueKey<String>('console-mode-toggle')),
    );
    final Rect lineEnding = tester.getRect(
      find.byKey(const ValueKey<String>('console-line-ending')),
    );

    expect(modeToggle.height, lessThanOrEqualTo(40));
    expect(lineEnding.height, 36);
    expect(modeToggle.center.dy, closeTo(lineEnding.center.dy, 2));
    expect(modeToggle.width, lessThan(140));
  });

  testWidgets('未连接时发送区说明禁用原因', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('暂不可发送：未连接'), findsOneWidget);
    expect(
      tester
          .widget<ToolButton>(
            find.byKey(const ValueKey<String>('console-send-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('可从设置工作区切换至英文界面', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await selectAppMode(tester, 'settings');
    await tester.tap(find.byKey(const ValueKey<String>('language-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('英文').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await selectAppMode(tester, 'debug');

    expect(find.text('Console'), findsOneWidget);
    expect(find.text('Current context'), findsOneWidget);
  });

  testWidgets('主题和语言统一收纳在设置工作区', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(findToolTooltip('主题模式'), findsNothing);
    expect(findToolTooltip('语言'), findsNothing);

    await selectAppMode(tester, 'settings');

    expect(
      find.byKey(const ValueKey<String>('theme-mode-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('language-selector')),
      findsOneWidget,
    );

    await tester.tap(find.text('暗色模式'));
    await tester.pumpAndSettle();
    expect(
      shad.Theme.of(
        tester.element(
          find.byKey(const ValueKey<String>('theme-mode-selector')),
        ),
      ).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const ValueKey<String>('language-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('英文').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Settings'), findsNWidgets(2));
  });

  testWidgets('工作区可导出、预览并确认替换导入', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await openWorkspaceSelector(tester);
    await tester.tap(find.text('导出工作区'));
    await tester.pumpAndSettle();
    expect(find.text('导出工作区'), findsOneWidget);
    expect(find.textContaining('"workspaces"'), findsOneWidget);
    await tester.tap(find.widgetWithText(ToolButton, '关闭'));
    await tester.pumpAndSettle();

    await openWorkspaceSelector(tester);
    await tester.tap(find.text('导入工作区'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolButton>(find.widgetWithText(ToolButton, '确认替换'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(shad.TextField).last,
      '{"version":1,"activeWorkspaceId":"imported","workspaces":[{"id":"imported","name":"导入测试工作区","scriptConfig":{"enabled":true,"beforeSendScript":"function beforeSend() { return {}; }","afterReceiveScript":"","language":"javascript"}}]}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ToolButton, '检查导入'));
    await tester.pumpAndSettle();

    expect(find.textContaining('脚本工作区 1 个'), findsOneWidget);
    expect(
      tester
          .widget<ToolButton>(find.widgetWithText(ToolButton, '确认替换'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(ToolButton, '确认替换'));
    await tester.pumpAndSettle();

    expect(find.text('导入测试工作区'), findsWidgets);
  });

  testWidgets('可合并导入并选择保留冲突工作区', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    Future<void> importAndConfirm(String jsonText) async {
      await openWorkspaceSelector(tester);
      await tester.tap(find.text('导入工作区'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(shad.TextField).last, jsonText);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ToolButton, '检查导入'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ToolButton, '确认替换'));
      await tester.pumpAndSettle();
    }

    await importAndConfirm(
      '{"version":2,"activeWorkspaceId":"conflict","workspaces":[{"id":"conflict","name":"原始工作区"}]}',
    );
    expect(find.text('原始工作区'), findsWidgets);

    await openWorkspaceSelector(tester);
    await tester.tap(find.text('导入工作区'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(shad.TextField).last,
      '{"version":2,"activeWorkspaceId":"new","workspaces":[{"id":"conflict","name":"覆盖版本"},{"id":"new","name":"新增工作区"}]}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ToolButton, '检查导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合并导入'));
    await tester.pumpAndSettle();

    expect(find.text('冲突处理'), findsOneWidget);
    expect(find.text('保留当前'), findsOneWidget);
    await tester.tap(find.text('保留当前'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ToolButton, '确认导入'));
    await tester.pumpAndSettle();

    await openWorkspaceSelector(tester);
    expect(find.text('原始工作区'), findsWidgets);
    expect(find.text('新增工作区'), findsWidgets);
    expect(find.text('覆盖版本'), findsNothing);
  });

  testWidgets('工作台可在调试和配置工作区间切换', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('控制台'), findsOneWidget);
    expect(find.text('特征'), findsOneWidget);
    await selectAppMode(tester, 'configure');

    expect(find.text('工作区'), findsWidgets);
    expect(find.text('设备型号'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('workspace-name-field')),
      findsOneWidget,
    );
  });

  testWidgets('配置导航在宽屏和窄屏均可切换协议页', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await selectAppMode(tester, 'configure');
    expect(find.byType(shad.NavigationRail), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-section-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('协议定义'), findsOneWidget);

    tester.view.physicalSize = const Size(375, 812);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('configuration-navigation-mobile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('app-mode-navigation-mobile')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-section-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('设备型号'), findsOneWidget);
  });

  testWidgets('新建工作区直接进入配置表单', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await openWorkspaceSelector(tester);
    await tester.tap(find.text('新建工作区'));
    await tester.pumpAndSettle();

    final Finder nameField = find.byKey(
      const ValueKey<String>('workspace-name-field'),
    );
    expect(nameField, findsOneWidget);
    expect(find.byType(Form), findsOneWidget);

    await tester.enterText(nameField, '温度计工作区');
    await tester.tap(find.widgetWithText(ToolButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('温度计工作区'), findsWidgets);
    expect(find.text('工作区已保存。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('工作区指令可选择显示在右侧快捷区', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('新建指令'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('command-name-field')),
        matching: find.byType(shad.TextField),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('command-format-select')),
      findsOneWidget,
    );
    expect(find.byType(shad.Select<CommandPayloadFormat>), findsOneWidget);
    final Rect commandDialog = tester.getRect(find.byType(shad.AlertDialog));
    expect(commandDialog.width, lessThan(700));
    expect(commandDialog.center.dx, closeTo(720, 1));

    await tester.tap(
      find.byKey(const ValueKey<String>('command-format-select')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byType(shad.SelectItemButton<CommandPayloadFormat>),
      findsNWidgets(2),
    );
    await tester.tap(
      find.byType(shad.SelectItemButton<CommandPayloadFormat>).last,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widget<shad.Select<CommandPayloadFormat>>(
            find.byType(shad.Select<CommandPayloadFormat>),
          )
          .value,
      CommandPayloadFormat.text,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('command-format-select')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(
      find.byType(shad.SelectItemButton<CommandPayloadFormat>).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widget<shad.Select<CommandPayloadFormat>>(
            find.byType(shad.Select<CommandPayloadFormat>),
          )
          .value,
      CommandPayloadFormat.hex,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('command-name-field')),
      '查询状态',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-group-field')),
      '查询',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-payload-field')),
      'AA 55 01',
    );
    await tester.tap(find.widgetWithText(ToolButton, '保存').first);
    await tester.pumpAndSettle();

    expect(find.text('查询'), findsOneWidget);
    expect(find.text('查询状态'), findsWidgets);
    expect(find.text('AA 55 01'), findsOneWidget);

    await tester.tap(findToolTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'debug');
    expect(find.bySemanticsLabel('查询状态：AA 55 01'), findsOneWidget);
    expect(find.text('AA'), findsOneWidget);
    expect(find.text('55'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
  });

  testWidgets('命令编辑器按字段显示保存校验错误', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('新建指令'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolButton>(find.widgetWithText(ToolButton, '保存').first)
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(ToolButton, '保存').first);
    await tester.pumpAndSettle();
    expect(find.byType(shad.AlertDialog), findsOneWidget);
    expect(find.textContaining('请先修复以下问题：'), findsOneWidget);
    expect(find.textContaining('指令名称为必填项'), findsWidgets);
    expect(find.textContaining('数据内容为必填项'), findsWidgets);
  });

  testWidgets('工作区命令白名单会阻止未选中指令进入发送链路', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final MockBluetoothService bluetoothService = MockBluetoothService();
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: bluetoothService,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> addCommand(String name, String payload) async {
      await tester.tap(findToolTooltip('新建指令'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('command-name-field')),
        name,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('command-group-field')),
        '测试',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('command-payload-field')),
        payload,
      );
      await tester.tap(find.widgetWithText(ToolButton, '保存').first);
      await tester.pumpAndSettle();
    }

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, '写入目标'),
          )
          .value,
      isTrue,
    );
    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await addCommand('允许指令', 'AA');
    await addCommand('拒绝指令', 'BB');

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ToolSwitchTile, '仅允许已选指令发送'),
        matching: find.byType(ToolSwitch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ToolCheckboxTile, '拒绝指令'),
        matching: find.byType(shad.Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ToolButton, '保存').last);
    await tester.pumpAndSettle();

    await tester.tap(findToolTooltip('快捷入口').first);
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('快捷入口').last);
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'debug');
    await tester.tap(findToolTooltip('发送 允许指令'));
    await tester.pumpAndSettle();
    expect(bluetoothService.sentPackets, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(findToolTooltip('发送 拒绝指令'));
    await tester.pumpAndSettle();

    expect(bluetoothService.sentPackets, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('设备策略会阻止超过当前设备帧上限的手动发送', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final MockBluetoothService bluetoothService = MockBluetoothService();
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: bluetoothService,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('设备发送策略'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(shad.TextField).last, '1');
    await tester.tap(find.widgetWithText(ToolButton, '保存'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('console-input')),
      'AA BB',
    );
    await tester.tap(find.widgetWithText(ToolButton, '发送数据'));
    await tester.pumpAndSettle();

    expect(bluetoothService.sentPackets, isEmpty);
  });

  testWidgets('可在左侧新增协议定义', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('协议'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(shad.TextField).at(0), '主协议');
    await tester.enterText(find.byType(shad.TextField).at(1), '测试设备主链路');
    await tester.tap(findToolTooltip('新增片段').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('固定 HEX').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<shad.TextField>(find.byType(shad.TextField))
          .any((shad.TextField field) => field.controller?.text == '主协议'),
      isTrue,
    );
    expect(find.text('固定 HEX'), findsWidgets);
  });

  testWidgets('连接后可选择写入与订阅特征', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    expect(find.text('0000FFF1-0000-1000-8000-00805F9B34FB'), findsOneWidget);
    expect(find.text('0000FFF2-0000-1000-8000-00805F9B34FB'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('characteristic-filter')),
      'FFF1',
    );
    await tester.pump();
    expect(find.text('0000FFF1-0000-1000-8000-00805F9B34FB'), findsOneWidget);
    expect(find.text('0000FFF2-0000-1000-8000-00805F9B34FB'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey<String>('characteristic-filter')),
      '',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ToolSelectedButton, 'R/W'));
    await tester.pump();
    expect(find.text('0000FFF1-0000-1000-8000-00805F9B34FB'), findsOneWidget);
    expect(find.text('0000FFF2-0000-1000-8000-00805F9B34FB'), findsNothing);
    await tester.tap(find.widgetWithText(ToolSelectedButton, 'R/W'));
    await tester.pump();

    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ToolSelectedButton, 'Notify').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ToolSelectedButton, 'Indicate').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, 'Indicate').first,
          )
          .value,
      isTrue,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('console-input')),
      'AA',
    );
    await tester.pump();

    expect(
      tester
          .widget<ToolButton>(find.widgetWithText(ToolButton, '发送数据'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('桌面特征面板使用紧凑筛选与操作控件', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    final Finder filter = find.byKey(
      const ValueKey<String>('characteristic-filter'),
    );
    final shad.TextField filterField = tester.widget<shad.TextField>(
      find.descendant(of: filter, matching: find.byType(shad.TextField)),
    );
    expect(filterField.style?.fontSize, 12);
    expect(tester.getSize(filter).height, lessThanOrEqualTo(36));

    final shad.Button scanButton = tester.widget<shad.Button>(
      find.byKey(const ValueKey<String>('scan-button')),
    );
    final shad.Button connectionButton = tester.widget<shad.Button>(
      find.byKey(const ValueKey<String>('connection-action-button')),
    );
    expect(scanButton.style, isA<shad.ButtonStyle>());
    expect(connectionButton.style, isA<shad.ButtonStyle>());

    final ToolSelectedButton operableOnly = tester.widget<ToolSelectedButton>(
      find.widgetWithText(ToolSelectedButton, 'R/W'),
    );
    expect(operableOnly.compact, isTrue);
    expect(operableOnly.emphasis, ToolSelectedEmphasis.subtle);

    final ToolSelectedButton writeTarget = tester.widget<ToolSelectedButton>(
      find.widgetWithText(ToolSelectedButton, '写入目标'),
    );
    expect(writeTarget.compact, isTrue);
    expect(writeTarget.emphasis, ToolSelectedEmphasis.subtle);
  });

  testWidgets('点击控制台日志后 Inspector 显示帧详情', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ToolSelectedButton, '写入目标'), findsOneWidget);
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, '写入目标'),
          )
          .value,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('console-input')),
      'AA BB',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('console-send-disabled-reason')),
      findsNothing,
    );
    expect(
      tester
          .widget<ToolButton>(
            find.byKey(const ValueKey<String>('console-send-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey<String>('console-send-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey<String>('console-log-list')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();

    final Finder detailsButton = findToolTooltip('查看日志详情');
    expect(detailsButton, findsWidgets);
    await tester.tap(detailsButton.first);
    await tester.pump();
    expect(find.text('选中日志'), findsOneWidget);
    expect(find.textContaining('AA BB'), findsWidgets);
  });

  testWidgets('控制台可按 HEX 搜索、筛选方向并导出结果', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, '写入目标'),
          )
          .value,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('console-input')),
      'AA BB',
    );
    await tester.pump();
    expect(
      tester
          .widget<ToolButton>(
            find.byKey(const ValueKey<String>('console-send-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey<String>('console-send-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('AA BB'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey<String>('console-search')),
      'AA BB',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的日志'), findsNothing);

    await tester.tap(findToolTooltip('筛选日志'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('TX').last);
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的日志'), findsNothing);

    await tester.tap(findToolTooltip('导出日志'));
    await tester.pumpAndSettle();
    expect(find.text('导出会话记录'), findsOneWidget);
    expect(find.textContaining('AA BB'), findsWidgets);
    await tester.tap(find.widgetWithText(ToolButton, '关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('仅支持无响应写入的特征可设为写入目标', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    final Finder writeTargets = find.text('写入目标');
    expect(writeTargets, findsNWidgets(1));
    await tester.tap(writeTargets);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, '写入目标'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('高风险命令在发送前要求确认', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('新建指令'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('command-name-field')),
      '恢复出厂设置',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-group-field')),
      '维护',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-payload-field')),
      'AA 55',
    );
    await tester.tap(find.widgetWithText(ToolButton, '保存').first);
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'debug');

    await tester.tap(findToolTooltip('发送 恢复出厂设置'));
    await tester.pumpAndSettle();

    expect(find.text('确认受保护发送'), findsOneWidget);
    expect(find.byType(shad.AlertDialog), findsOneWidget);
    final shad.Theme dialogTheme = tester.widget<shad.Theme>(
      find
          .ancestor(
            of: find.byType(shad.AlertDialog),
            matching: find.byType(shad.Theme),
          )
          .first,
    );
    expect(dialogTheme.data.radius, closeTo(0.25, 0.001));
    expect(find.textContaining('恢复出厂设置'), findsWidgets);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('确认受保护发送'), findsNothing);
  });

  testWidgets('显式保护命令在发送前要求确认', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('新建指令'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('command-name-field')),
      '安全动作',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-group-field')),
      '维护',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-payload-field')),
      'AA 55',
    );
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ToolSwitchTile, '发送前始终确认'),
        matching: find.byType(ToolSwitch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ToolButton, '保存').first);
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'debug');

    await tester.tap(findToolTooltip('发送 安全动作'));
    await tester.pumpAndSettle();

    expect(find.text('确认受保护发送'), findsOneWidget);
    expect(find.textContaining('每次发送都需要确认'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    expect(find.text('设备已离开蓝牙范围或停止广播，请重新扫描后再连接。'), findsWidgets);
    expect(find.textContaining('Bad state:'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
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
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'records');
    await tester.enterText(
      find.byType(shad.TextField),
      'session-record-filter-test',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1/'), findsOneWidget);
    await tester.tap(findToolTooltip('添加书签'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ToolSelectedButton, '书签'));
    await tester.pumpAndSettle();
    expect(findToolTooltip('取消书签'), findsOneWidget);
    await tester.tap(findToolTooltip('导出会话记录'));
    await tester.pumpAndSettle();
    expect(find.text('导出会话记录'), findsOneWidget);
    expect(find.textContaining('"kind": "error"'), findsOneWidget);
    expect(find.textContaining('"bookmarked": true'), findsOneWidget);
  });

  testWidgets('发送记录可按指令筛选并导出', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写入目标'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('指令'));
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('新建指令'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('command-name-field')),
      '诊断命令',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-group-field')),
      '诊断',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-payload-field')),
      'AA 55',
    );
    await tester.tap(find.widgetWithText(ToolButton, '保存').first);
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'debug');
    await tester.tap(findToolTooltip('发送 诊断命令'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'records');

    final Finder commandFilter = find.byWidgetPredicate(
      (Widget widget) => widget is ToolSelect<String> && widget.label == '指令',
    );
    expect(commandFilter, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: commandFilter,
        matching: find.byType(shad.Select<String>),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('诊断命令').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(findToolTooltip('导出会话记录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"commandName": "诊断命令"'), findsOneWidget);
    expect(find.textContaining('"transactionId": "tx-'), findsOneWidget);
  });
}
