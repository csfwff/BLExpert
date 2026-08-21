import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'package:blexpert/main.dart';
import 'package:blexpert/app/app_theme.dart';
import 'package:blexpert/app/design/app_icons.dart';
import 'package:blexpert/app/design/tool_button.dart';
import 'package:blexpert/app/design/tool_select.dart';
import 'package:blexpert/app/design/tool_text_field.dart';
import 'package:blexpert/app/design/tool_toggle.dart';
import 'package:blexpert/app/design/tool_tooltip.dart';
import 'package:blexpert/models/bluetooth_write_mode.dart';
import 'package:blexpert/models/command_definition.dart';
import 'package:blexpert/services/bluetooth_service.dart';

class _DelayedBluetoothService extends MockBluetoothService {
  final Completer<void> _connectCompleter = Completer<void>();
  final Completer<void> _disconnectCompleter = Completer<void>();

  @override
  Future<void> connect(String deviceId) async {
    await _connectCompleter.future;
    await super.connect(deviceId);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _disconnectCompleter.future;
    await super.disconnect(deviceId);
  }

  void completeConnection() {
    if (!_connectCompleter.isCompleted) _connectCompleter.complete();
  }

  void completeDisconnection() {
    if (!_disconnectCompleter.isCompleted) _disconnectCompleter.complete();
  }
}

class _ConnectedBeforeReadyBluetoothService extends MockBluetoothService {
  final Completer<void> _discoveryCompleter = Completer<void>();

  @override
  Future<List<BluetoothCharacteristicInfo>> discoverCharacteristics(
    String deviceId,
  ) async {
    await _discoveryCompleter.future;
    return super.discoverCharacteristics(deviceId);
  }

  void completeDiscovery() {
    if (!_discoveryCompleter.isCompleted) _discoveryCompleter.complete();
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

  testWidgets('模式导航切换时保持图标一致', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    final Finder debugDestination = find.byKey(
      const ValueKey<String>('app-mode-debug'),
    );
    final Icon selectedIcon = tester.widget<Icon>(
      find.descendant(of: debugDestination, matching: find.byType(Icon)),
    );

    await selectAppMode(tester, 'configure');

    final Icon unselectedIcon = tester.widget<Icon>(
      find.descendant(of: debugDestination, matching: find.byType(Icon)),
    );
    expect(unselectedIcon.icon, selectedIcon.icon);
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
        matching: find.text('断开设备'),
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
    final Finder workspaceMenu = find.byType(shad.DropdownMenu);
    expect(workspaceMenu, findsOneWidget);
    expect(
      tester.getSize(workspaceMenu).width,
      tester
          .getSize(find.byKey(const ValueKey<String>('workspace-selector')))
          .width,
    );
    await tester.tap(findToolTooltip('选择工作区'));
    await tester.pump();
  });

  testWidgets('设备选择下拉使用紧凑选项密度', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('bluetooth-device-selector')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final Finder option = find.byKey(
      const ValueKey<String>('bluetooth-device-option-ble-001'),
    );
    expect(option, findsOneWidget);
    expect(tester.getSize(option).height, 24);
    expect(
      tester.getSize(find.byType(shad.SelectPopup<String>)).width,
      tester
          .getSize(
            find.byKey(const ValueKey<String>('bluetooth-device-selector')),
          )
          .width,
    );
    final Text label = tester.widget<Text>(
      find.descendant(of: option, matching: find.text('BLE 温度传感器')),
    );
    expect(label.style?.fontSize, 12);
  });

  testWidgets('首页工具栏选择器与操作按钮使用统一尺寸和间距', (WidgetTester tester) async {
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
    for (final Finder control in controls) {
      expect(tester.getSize(control).width, 136);
    }
    final List<Rect> controlBounds = controls
        .map(tester.getRect)
        .toList(growable: false);
    for (var index = 1; index < controlBounds.length; index += 1) {
      expect(controlBounds[index].left - controlBounds[index - 1].right, 8);
    }
    final Text deviceLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('bluetooth-device-selector')),
        matching: find.text('BLE 温度传感器'),
      ),
    );
    final List<Text> toolbarLabels = <Text>[
      tester.widget<Text>(
        find.descendant(of: controls[0], matching: find.text('默认工作区')),
      ),
      deviceLabel,
      tester.widget<Text>(
        find.descendant(of: controls[2], matching: find.text('连接设备')),
      ),
      tester.widget<Text>(
        find.descendant(of: controls[3], matching: find.text('开始扫描')),
      ),
    ];
    for (final Text label in toolbarLabels) {
      expect(label.style?.fontSize, 12);
    }
    final shad.Button workspaceButton = tester.widget<shad.Button>(controls[0]);
    final EdgeInsetsGeometry workspacePadding = workspaceButton.style.padding(
      tester.element(controls[0]),
      <WidgetState>{},
    );
    final shad.Select<String> deviceSelect = tester.widget<shad.Select<String>>(
      controls[1],
    );
    expect(deviceSelect.padding, workspacePadding);

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
    for (final String message in <String>['选择工作区', '连接设备', '自动滚动']) {
      expect(
        find.descendant(
          of: findToolTooltip(message),
          matching: find.byType(shad.Tooltip),
        ),
        findsNothing,
      );
    }
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

  testWidgets('连接加载期间保持主按钮底色', (WidgetTester tester) async {
    final _ConnectedBeforeReadyBluetoothService bluetoothService =
        _ConnectedBeforeReadyBluetoothService();
    await pumpDesktopApp(tester, bluetoothService: bluetoothService);

    final Finder connectionButton = find.byKey(
      const ValueKey<String>('connection-action-button'),
    );
    await tester.tap(connectionButton);
    await tester.pump();
    await tester.pump();

    final BuildContext buttonContext = tester.element(connectionButton);
    final shad.Button button = tester.widget<shad.Button>(connectionButton);
    final BoxDecoration loadingDecoration =
        button.style.decoration(buttonContext, <WidgetState>{
              WidgetState.disabled,
            })
            as BoxDecoration;
    expect(loadingDecoration.color, AppTheme.colorsOf(buttonContext).primary);
    expect(button.onPressed, isNull);
    expect(
      find.descendant(of: connectionButton, matching: find.text('正在连接')),
      findsOneWidget,
    );

    bluetoothService.completeDiscovery();
    await tester.pumpAndSettle();
  });

  testWidgets('断开设备期间显示正在断开', (WidgetTester tester) async {
    final _DelayedBluetoothService bluetoothService =
        _DelayedBluetoothService();
    await pumpDesktopApp(tester, bluetoothService: bluetoothService);

    final Finder connectionButton = find.byKey(
      const ValueKey<String>('connection-action-button'),
    );
    await tester.tap(connectionButton);
    await tester.pump();
    bluetoothService.completeConnection();
    await tester.pumpAndSettle();

    await tester.tap(connectionButton);
    await tester.pump();

    expect(
      find.descendant(of: connectionButton, matching: find.text('正在断开')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: connectionButton, matching: find.text('正在连接')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: connectionButton,
        matching: find.byType(ToolLoadingIcon),
      ),
      findsOneWidget,
    );
    final BuildContext buttonContext = tester.element(connectionButton);
    final shad.Button button = tester.widget<shad.Button>(connectionButton);
    final BoxDecoration loadingDecoration =
        button.style.decoration(buttonContext, <WidgetState>{
              WidgetState.disabled,
            })
            as BoxDecoration;
    final shad.ColorScheme colors = AppTheme.colorsOf(buttonContext);
    expect(loadingDecoration.color, colors.secondary);
    expect(
      (loadingDecoration.border! as Border).top.color,
      colors.secondaryForeground,
    );

    bluetoothService.completeDisconnection();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: connectionButton, matching: find.text('连接设备')),
      findsOneWidget,
    );
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
    final List<Rect> destinations =
        <String>['debug', 'configure', 'records', 'settings']
            .map(
              (String mode) => tester.getRect(
                find.byKey(ValueKey<String>('app-mode-$mode')),
              ),
            )
            .toList(growable: false);
    for (final Rect destination in destinations.skip(1)) {
      expect(destination.width, closeTo(destinations.first.width, 0.1));
    }
    expect(destinations.first.left, greaterThanOrEqualTo(8));
    expect(destinations.last.right, lessThanOrEqualTo(367));
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.byKey(const ValueKey<String>('app-mode-debug')),
          )
          .value,
      isTrue,
    );
    final Text sendLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('console-send-button')),
        matching: find.text('发送数据'),
      ),
    );
    expect(sendLabel.maxLines, 1);
    expect(sendLabel.softWrap, isFalse);
    final Finder writeTargetStatus = find.byKey(
      const ValueKey<String>('console-write-target-status'),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('console-send-area')),
        matching: writeTargetStatus,
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getRect(writeTargetStatus)
          .overlaps(
            tester.getRect(
              find.byKey(const ValueKey<String>('console-mode-toggle')),
            ),
          ),
      isFalse,
    );
    await openWorkspaceSelector(tester);
    expect(
      tester.getSize(find.byType(shad.DropdownMenu)).width,
      greaterThan(
        tester
            .getSize(find.byKey(const ValueKey<String>('workspace-selector')))
            .width,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('窗口缩放时调试区按可用宽度切换且不产生溢出', (WidgetTester tester) async {
    await pumpDesktopApp(tester);
    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('debug-workspace-pane-layout')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('log-line-wide')), findsWidgets);

    tester.view.physicalSize = const Size(1160, 900);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('debug-workspace-tab-layout')),
      findsOneWidget,
    );
    expect(findToolTooltip('收起特征面板'), findsNothing);
    expect(findToolTooltip('收起上下文面板'), findsNothing);
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('console-header-actions')))
          .right,
      closeTo(
        tester
                .getRect(find.byKey(const ValueKey<String>('console-header')))
                .right -
            8,
        0.1,
      ),
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(720, 900);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('bluetooth-device-selector')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('workspace-selector')))
          .width,
      lessThan(136),
    );
    expect(
      find.byKey(const ValueKey<String>('app-mode-navigation-mobile')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('log-line-wide')), findsWidgets);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('log-line-compact')),
      findsWidgets,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('console-header-actions')))
          .right,
      closeTo(
        tester
                .getRect(find.byKey(const ValueKey<String>('console-header')))
                .right -
            12,
        0.1,
      ),
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('debug-workspace-pane-layout')),
      findsOneWidget,
    );
    expect(findToolTooltip('收起特征面板'), findsOneWidget);
    expect(findToolTooltip('收起上下文面板'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主导航跨越桌面断点时保持调试工作区状态', (WidgetTester tester) async {
    await pumpDesktopApp(tester);
    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(920, 900);
    await tester.pump();

    final Finder contentShell = find.byKey(
      const ValueKey<String>('app-workspace-content-shell'),
    );
    final Finder debugTabs = find.byKey(
      const ValueKey<String>('debug-workspace-tabs'),
    );
    final Element contentElement = tester.element(contentShell);
    expect(
      find.byKey(const ValueKey<String>('app-mode-navigation')),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: debugTabs, matching: find.text('设备')));
    await tester.pump();
    final Finder characteristicFilter = find.byKey(
      const ValueKey<String>('characteristic-filter'),
    );
    await tester.enterText(characteristicFilter, 'fff');
    await tester.pump();
    expect(tester.widget<shad.Tabs>(debugTabs).index, 1);

    tester.view.physicalSize = const Size(880, 900);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('app-mode-navigation-mobile')),
      findsOneWidget,
    );
    expect(tester.element(contentShell), same(contentElement));
    expect(tester.widget<shad.Tabs>(debugTabs).index, 1);
    final ToolTextField filterAfterResize = tester.widget<ToolTextField>(
      find.descendant(
        of: characteristicFilter,
        matching: find.byType(ToolTextField),
      ),
    );
    expect(filterAfterResize.controller?.text, 'fff');
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(920, 900);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('app-mode-navigation')),
      findsOneWidget,
    );
    expect(tester.element(contentShell), same(contentElement));
    expect(tester.widget<shad.Tabs>(debugTabs).index, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('控制台右侧操作与 Inspector 开关保持对齐和稳定边距', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    void expectTrailingActionsAligned(String inspectorTooltip) {
      final Rect header = tester.getRect(
        find.byKey(const ValueKey<String>('console-header')),
      );
      final Rect actionGroup = tester.getRect(
        find.byKey(const ValueKey<String>('console-header-actions')),
      );
      final Rect autoScroll = tester.getRect(findToolTooltip('自动滚动'));
      final Rect exportButton = tester.getRect(findToolTooltip('导出日志'));
      final Rect clearButton = tester.getRect(findToolTooltip('清空'));
      final Rect inspectorToggle = tester.getRect(
        findToolTooltip(inspectorTooltip),
      );

      expect(actionGroup.right, closeTo(header.right - 8, 0.1));
      expect(inspectorToggle.right, closeTo(header.right - 8, 0.1));
      expect(clearButton.right, closeTo(inspectorToggle.left - 4, 0.1));
      expect(autoScroll.center.dy, closeTo(inspectorToggle.center.dy, 0.1));
      expect(exportButton.center.dy, closeTo(inspectorToggle.center.dy, 0.1));
      expect(clearButton.center.dy, closeTo(inspectorToggle.center.dy, 0.1));
      expect(clearButton.overlaps(inspectorToggle), isFalse);
    }

    expectTrailingActionsAligned('收起上下文面板');

    await tester.tap(findToolTooltip('收起上下文面板'));
    await tester.pumpAndSettle();

    expect(findToolTooltip('收起上下文面板'), findsNothing);
    expectTrailingActionsAligned('展开上下文面板');
  });

  testWidgets('桌面特征面板可收起和展开且控制台右侧操作位置稳定', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    final Finder panel = find.byKey(
      const ValueKey<String>('characteristic-panel'),
    );
    final Finder header = find.byKey(const ValueKey<String>('console-header'));
    final Finder actions = find.byKey(
      const ValueKey<String>('console-header-actions'),
    );
    final double initialHeaderLeft = tester.getRect(header).left;
    final double initialActionsRight = tester.getRect(actions).right;

    expect(panel, findsOneWidget);
    expect(findToolTooltip('收起特征面板'), findsOneWidget);

    await tester.tap(findToolTooltip('收起特征面板'));
    await tester.pumpAndSettle();

    expect(panel, findsNothing);
    expect(findToolTooltip('展开特征面板'), findsOneWidget);
    expect(tester.getRect(header).left, lessThan(initialHeaderLeft));
    expect(tester.getRect(actions).right, closeTo(initialActionsRight, 0.1));

    await tester.tap(findToolTooltip('展开特征面板'));
    await tester.pumpAndSettle();

    expect(panel, findsOneWidget);
    expect(findToolTooltip('收起特征面板'), findsOneWidget);
    expect(tester.getRect(header).left, closeTo(initialHeaderLeft, 0.1));
    expect(tester.getRect(actions).right, closeTo(initialActionsRight, 0.1));
  });

  testWidgets('发送区模式与行尾控件使用紧凑统一尺寸', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    final Finder input = find.byKey(const ValueKey<String>('console-input'));
    final Finder sendButton = find.byKey(
      const ValueKey<String>('console-send-button'),
    );
    final Finder modeToggle = find.byKey(
      const ValueKey<String>('console-mode-toggle'),
    );
    final Finder lineEnding = find.byKey(
      const ValueKey<String>('console-line-ending'),
    );

    expect(tester.getSize(input).height, 36);
    expect(tester.getSize(sendButton), const Size(100, 36));
    expect(
      tester.getRect(input).top,
      closeTo(tester.getRect(sendButton).top, 0.1),
    );
    final ToolTextField inputField = tester.widget<ToolTextField>(input);
    expect(inputField.padding, ToolTextField.defaultPadding);
    expect(inputField.style?.fontSize, 12);
    expect(
      inputField.style?.fontFamily,
      'packages/shadcn_flutter/${AppFonts.mono}',
    );
    final ToolButton send = tester.widget<ToolButton>(sendButton);
    expect(send.compact, isTrue);
    expect(send.padding, const EdgeInsets.symmetric(horizontal: 10));
    final Text sendText = tester.widget<Text>(
      find.descendant(of: sendButton, matching: find.text('发送数据')),
    );
    expect(sendText.style?.fontSize, 12);
    final Rect modeToggleRect = tester.getRect(modeToggle);
    final Rect lineEndingRect = tester.getRect(lineEnding);
    expect(modeToggleRect.height, 32);
    expect(lineEndingRect.height, 32);
    expect(lineEndingRect.width, 96);
    expect(modeToggleRect.center.dy, closeTo(lineEndingRect.center.dy, 2));
    expect(modeToggleRect.width, lessThan(140));
    final Text modeLabel = tester.widget<Text>(
      find.descendant(of: modeToggle, matching: find.text('HEX')),
    );
    expect(modeLabel.style?.fontSize, 12);
    final ToolSegmentedControl<bool> segmentedControl = tester
        .widget<ToolSegmentedControl<bool>>(modeToggle);
    expect(
      segmentedControl.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
    expect(segmentedControl.height, 32);
    final ToolSelect<String> lineEndingSelect = tester
        .widget<ToolSelect<String>>(
          find.descendant(
            of: lineEnding,
            matching: find.byType(ToolSelect<String>),
          ),
        );
    expect(
      lineEndingSelect.padding,
      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
    expect(
      lineEndingSelect.itemPadding,
      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    );
    expect(lineEndingSelect.itemHeight, 28);
    final Text lineEndingValue = tester.widget<Text>(
      find.descendant(of: lineEnding, matching: find.text('无')),
    );
    expect(lineEndingValue.style?.fontSize, 12);
    await tester.tap(lineEnding);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    for (final String value in <String>['none', 'lf', 'crlf']) {
      expect(
        tester
            .getSize(find.byKey(ValueKey<String>('tool-select-option-$value')))
            .height,
        28,
      );
    }
    final Finder crlfLabel = find.descendant(
      of: find.byKey(const ValueKey<String>('tool-select-option-crlf')),
      matching: find.text('CRLF'),
    );
    final Text crlf = tester.widget<Text>(crlfLabel);
    expect(crlf.maxLines, 1);
    expect(crlf.softWrap, isFalse);
    final TextStyle effectiveCrlfStyle = DefaultTextStyle.of(
      tester.element(crlfLabel),
    ).style.merge(crlf.style);
    final TextPainter crlfPainter = TextPainter(
      text: TextSpan(text: 'CRLF', style: effectiveCrlfStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    expect(
      tester.getSize(crlfLabel).width,
      greaterThanOrEqualTo(crlfPainter.width),
    );
    final Finder writeTargetStatus = find.byKey(
      const ValueKey<String>('console-write-target-status'),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('console-header')),
        matching: writeTargetStatus,
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('console-send-area')),
        matching: writeTargetStatus,
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(writeTargetStatus).center.dy,
      closeTo(modeToggleRect.center.dy, 2),
    );
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
    expect(
      tester.getRect(find.text('英文').last).top,
      greaterThanOrEqualTo(
        tester
            .getRect(find.byKey(const ValueKey<String>('language-selector')))
            .bottom,
      ),
    );
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

    final Text settingsTitle = tester.widget<Text>(
      find.byKey(const ValueKey<String>('settings-workspace-title')),
    );
    expect(settingsTitle.style?.fontSize, 16);
    final Finder themeRow = find.byKey(
      const ValueKey<String>('settings-theme-row'),
    );
    final Finder languageRow = find.byKey(
      const ValueKey<String>('settings-language-row'),
    );
    expect(themeRow, findsOneWidget);
    expect(languageRow, findsOneWidget);
    expect(
      tester
              .getRect(
                find.byKey(const ValueKey<String>('theme-mode-selector')),
              )
              .left -
          tester.getRect(themeRow).left,
      closeTo(108, 1),
    );
    expect(
      find.byKey(const ValueKey<String>('theme-mode-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('language-selector')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('language-selector')))
          .width,
      180,
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

  testWidgets('工作区设置使用紧凑标题和单项横向表单行', (WidgetTester tester) async {
    await pumpDesktopApp(tester);
    await selectAppMode(tester, 'configure');

    final Text title = tester.widget<Text>(find.text('工作区设置'));
    expect(title.style?.fontSize, 16);

    final Finder nameRow = find.byKey(
      const ValueKey<String>('workspace-name-row'),
    );
    final Finder modelRow = find.byKey(
      const ValueKey<String>('workspace-device-model-row'),
    );
    final Finder descriptionRow = find.byKey(
      const ValueKey<String>('workspace-description-row'),
    );
    final Finder tagsRow = find.byKey(
      const ValueKey<String>('workspace-tags-row'),
    );
    final List<Finder> rows = <Finder>[
      nameRow,
      modelRow,
      descriptionRow,
      tagsRow,
    ];
    for (final Finder row in rows) {
      expect(
        find.descendant(of: row, matching: find.byType(ToolTextField)),
        findsOneWidget,
      );
    }
    expect(
      tester.getRect(modelRow).top,
      greaterThan(tester.getRect(nameRow).top),
    );
    expect(
      tester.getRect(descriptionRow).top,
      greaterThan(tester.getRect(modelRow).top),
    );
    expect(
      tester.getRect(tagsRow).top,
      greaterThan(tester.getRect(descriptionRow).top),
    );

    final Rect nameLabel = tester.getRect(
      find.descendant(of: nameRow, matching: find.text('工作区')).first,
    );
    final Rect nameField = tester.getRect(
      find.byKey(const ValueKey<String>('workspace-name-field')),
    );
    expect(nameLabel.center.dy, closeTo(nameField.center.dy, 1));
    expect(nameLabel.right, lessThan(nameField.left));
    expect(find.text('设备配置'), findsNothing);

    final Finder saveButton = find.byKey(
      const ValueKey<String>('workspace-save-button'),
    );
    final ToolButton save = tester.widget<ToolButton>(saveButton);
    expect(tester.getSize(saveButton).height, 34);
    expect(save.compact, isTrue);
    expect(save.padding, const EdgeInsets.symmetric(horizontal: 16));

    tester.view.physicalSize = const Size(520, 812);
    await tester.pumpAndSettle();
    final Rect narrowLabel = tester.getRect(
      find.descendant(of: nameRow, matching: find.text('工作区')).first,
    );
    final Rect narrowField = tester.getRect(
      find.byKey(const ValueKey<String>('workspace-name-field')),
    );
    expect(narrowLabel.bottom, lessThanOrEqualTo(narrowField.top));
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

  testWidgets('协议配置使用单项表单行和紧凑模式切换', (WidgetTester tester) async {
    await pumpDesktopApp(tester);
    await selectAppMode(tester, 'configure');
    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-section-1')),
    );
    await tester.pumpAndSettle();

    final Finder nameRow = find.byKey(
      const ValueKey<String>('protocol-name-row'),
    );
    final Finder descriptionRow = find.byKey(
      const ValueKey<String>('protocol-description-row'),
    );
    final Finder modeSection = find.byKey(
      const ValueKey<String>('protocol-mode-section'),
    );
    expect(
      tester.getRect(descriptionRow).top,
      greaterThan(tester.getRect(nameRow).top),
    );
    expect(
      tester.getRect(modeSection).top,
      greaterThan(tester.getRect(descriptionRow).bottom),
    );

    final Rect nameLabel = tester.getRect(
      find.descendant(of: nameRow, matching: find.text('协议名称')),
    );
    final Rect nameField = tester.getRect(
      find.byKey(const ValueKey<String>('protocol-name-field')),
    );
    expect(nameLabel.right, lessThan(nameField.left));
    expect(nameLabel.center.dy, closeTo(nameField.center.dy, 1));

    final Rect modeLabel = tester.getRect(
      find.descendant(of: modeSection, matching: find.text('协议模式')),
    );
    final Finder modeControl = find.byKey(
      const ValueKey<String>('protocol-mode-control'),
    );
    final Rect modeControlRect = tester.getRect(modeControl);
    expect(modeLabel.right, lessThanOrEqualTo(modeControlRect.left));
    expect(modeControlRect.left - modeLabel.right, closeTo(16, 1));
    expect(modeControlRect.height, 32);
    final List<ToolSelectedButton> modeButtons = tester
        .widgetList<ToolSelectedButton>(
          find.descendant(
            of: modeControl,
            matching: find.byType(ToolSelectedButton),
          ),
        )
        .toList(growable: false);
    expect(modeButtons, hasLength(2));
    expect(
      modeButtons.every(
        (ToolSelectedButton button) =>
            button.padding ==
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      isTrue,
    );
    expect(tester.widget<Text>(find.text('普通协议')).style?.fontSize, 12);
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('protocol-mode-note')))
          .left,
      tester.getRect(modeSection).left,
    );

    final Finder sendSection = find.byKey(
      const ValueKey<String>('protocol-send-section'),
    );
    final Finder receiveSection = find.byKey(
      const ValueKey<String>('protocol-receive-section'),
    );
    final Finder sendAddButton = find.byKey(
      const ValueKey<String>('protocol-send-add-segment'),
    );
    final Finder receiveAddButton = find.byKey(
      const ValueKey<String>('protocol-receive-add-segment'),
    );
    expect(tester.getRect(sendSection).left, tester.getRect(modeSection).left);
    expect(
      tester.getRect(sendSection).right,
      tester.getRect(modeSection).right,
    );
    expect(
      tester.getRect(sendAddButton).left,
      tester.getRect(sendSection).left,
    );
    expect(
      tester.getRect(receiveAddButton).left,
      tester.getRect(receiveSection).left,
    );
    final Finder sendEmptyState = find.descendant(
      of: sendSection,
      matching: find.text('尚未配置片段。'),
    );
    final Finder receiveEmptyState = find.descendant(
      of: receiveSection,
      matching: find.text('尚未配置片段。'),
    );
    expect(
      tester.getRect(sendAddButton).top,
      greaterThan(tester.getRect(sendEmptyState).bottom),
    );
    expect(
      tester.getRect(receiveAddButton).top,
      greaterThan(tester.getRect(receiveEmptyState).bottom),
    );

    await tester.tap(sendAddButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final Rect addMenuRect = tester.getRect(find.byType(shad.DropdownMenu));
    final Rect openAddButtonRect = tester.getRect(sendAddButton);
    expect(addMenuRect.left, lessThan(openAddButtonRect.right));
    expect(addMenuRect.right, greaterThan(openAddButtonRect.left));
    expect(addMenuRect.top, greaterThanOrEqualTo(openAddButtonRect.bottom));
    expect(addMenuRect.top - openAddButtonRect.bottom, lessThanOrEqualTo(8));
    await tester.tap(find.text('固定 HEX').last);
    await tester.pumpAndSettle();

    final Finder sendSegment = find.byWidgetPredicate((Widget widget) {
      final Key? key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('protocol-send-segment-');
    });
    final List<Rect> sendFieldRects = find
        .descendant(of: sendSegment, matching: find.byType(ToolTextField))
        .evaluate()
        .map((Element element) => tester.getRect(find.byWidget(element.widget)))
        .toList(growable: false);
    expect(sendFieldRects, hasLength(2));
    expect(
      sendFieldRects[0].center.dy,
      closeTo(sendFieldRects[1].center.dy, 1),
    );
    expect(
      tester.getRect(sendAddButton).top,
      greaterThan(tester.getRect(sendSegment).bottom),
    );

    await tester.tap(sendAddButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('长度字段').last);
    await tester.pumpAndSettle();
    final Finder lengthSegment = find.byWidgetPredicate((Widget widget) {
      final Key? key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('protocol-send-segment-');
    }).last;
    final Finder lengthInputs = find.descendant(
      of: lengthSegment,
      matching: find.byType(ToolTextField),
    );
    final Finder lengthSelects = find.descendant(
      of: lengthSegment,
      matching: find.byWidgetPredicate((Widget widget) => widget is ToolSelect),
    );
    expect(lengthInputs, findsNWidgets(2));
    expect(lengthSelects, findsNWidgets(2));
    final double fieldHeight = tester.getSize(lengthInputs.first).height;
    final double fieldCenterY = tester.getCenter(lengthInputs.first).dy;
    for (final Element selectElement in lengthSelects.evaluate()) {
      final Finder selectFinder = find.byWidget(selectElement.widget);
      expect(tester.getSize(selectFinder).height, closeTo(fieldHeight, 1));
      expect(tester.getCenter(selectFinder).dy, closeTo(fieldCenterY, 1));
    }
    final Text payloadSelectText = tester.widget<Text>(
      find.descendant(of: lengthSegment, matching: find.text('有效载荷')),
    );
    expect(payloadSelectText.style?.fontSize, 12);
    expect(payloadSelectText.style?.fontWeight, FontWeight.w400);

    tester.view.physicalSize = const Size(700, 900);
    await tester.pumpAndSettle();
    final List<Rect> narrowSendFieldRects = find
        .descendant(of: sendSegment, matching: find.byType(ToolTextField))
        .evaluate()
        .map((Element element) => tester.getRect(find.byWidget(element.widget)))
        .toList(growable: false);
    expect(
      narrowSendFieldRects[0].bottom,
      lessThanOrEqualTo(narrowSendFieldRects[1].top),
    );
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();

    final Finder standardIcon = find.descendant(
      of: modeControl,
      matching: find.byIcon(AppIcons.accountTree),
    );
    final Finder scriptIcon = find.descendant(
      of: modeControl,
      matching: find.byIcon(AppIcons.codeOutlined),
    );
    final shad.ColorScheme modeColors = AppTheme.colorsOf(
      tester.element(standardIcon),
    );
    expect(
      IconTheme.of(tester.element(standardIcon)).color,
      modeColors.secondaryForeground,
    );
    expect(
      IconTheme.of(tester.element(scriptIcon)).color,
      modeColors.foreground,
    );
    await tester.tap(find.text('脚本协议'));
    await tester.pumpAndSettle();
    expect(
      IconTheme.of(tester.element(standardIcon)).color,
      modeColors.foreground,
    );
    expect(
      IconTheme.of(tester.element(scriptIcon)).color,
      modeColors.secondaryForeground,
    );
    final Finder scriptTabs = find.byKey(
      const ValueKey<String>('script-protocol-tabs'),
    );
    final Finder scriptSampleAction = find.byKey(
      const ValueKey<String>('script-load-sample-action'),
    );
    expect(scriptTabs, findsOneWidget);
    expect(scriptSampleAction, findsOneWidget);
    expect(
      tester.getRect(scriptSampleAction).left,
      greaterThan(tester.getRect(scriptTabs).right),
    );
    expect(
      find.byKey(const ValueKey<String>('script-runtime-information-tab')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('script-before-send-tab')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: scriptTabs, matching: find.text('发送前脚本')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('script-before-send-tab')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is ToolTextField && widget.label == '发送前脚本',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: scriptTabs, matching: find.text('接收后脚本')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('script-after-receive-tab')),
      findsOneWidget,
    );
    expect(scriptSampleAction, findsOneWidget);

    tester.view.physicalSize = const Size(520, 812);
    await tester.pumpAndSettle();
    final Rect narrowLabel = tester.getRect(
      find.descendant(of: nameRow, matching: find.text('协议名称')),
    );
    final Rect narrowField = tester.getRect(
      find.byKey(const ValueKey<String>('protocol-name-field')),
    );
    expect(narrowLabel.bottom, lessThanOrEqualTo(narrowField.top));
    final Rect narrowModeLabel = tester.getRect(
      find.descendant(of: modeSection, matching: find.text('协议模式')),
    );
    expect(narrowModeLabel.bottom, lessThan(tester.getRect(modeControl).top));
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
    expect(find.widgetWithText(ToolButton, '新建指令'), findsOneWidget);
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
    final Finder formatOptions = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'tool-select-option-',
          ),
    );
    expect(formatOptions, findsNWidgets(2));
    await tester.tap(formatOptions.last);
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
    await tester.tap(formatOptions.first);
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
      'AA BB {{level}} 01',
    );
    await tester.tap(findToolTooltip('新增参数'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('add-command-parameter-button')),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'command-parameter-row-',
            ),
      ),
      findsNWidgets(2),
    );
    await tester.tap(findToolTooltip('删除参数').last);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('command-name-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('command-payload-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('command-parameter-row-0')),
      findsOneWidget,
    );
    final ToolTextField newParameterDefault = tester.widget<ToolTextField>(
      find.byWidgetPredicate(
        (Widget widget) => widget is ToolTextField && widget.label == '默认值',
      ),
    );
    expect(newParameterDefault.initialValue, isEmpty);
    expect(newParameterDefault.hintText, '可选');
    final ToolTextField newParameterKey = tester.widget<ToolTextField>(
      find.byWidgetPredicate(
        (Widget widget) => widget is ToolTextField && widget.label == 'key',
      ),
    );
    final ToolTextField newParameterLabel = tester.widget<ToolTextField>(
      find.byWidgetPredicate(
        (Widget widget) => widget is ToolTextField && widget.label == '名称',
      ),
    );
    expect(newParameterKey.initialValue, isEmpty);
    expect(newParameterLabel.initialValue, isEmpty);
    final ToolSelect<CommandParameterType> parameterTypeSelect = tester
        .widget<ToolSelect<CommandParameterType>>(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is ToolSelect<CommandParameterType> &&
                widget.label == '类型',
          ),
        );
    expect(parameterTypeSelect.expand, isTrue);
    expect(findToolTooltip('删除参数'), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) => widget is ToolTextField && widget.label == 'key',
      ),
      'level',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('command-parameter-token-0')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('command-parameter-token-0')),
    );
    expect(
      tester
          .widget<ToolTextField>(
            find.byKey(const ValueKey<String>('command-payload-field')),
          )
          .controller
          ?.text,
      contains('{{level}}'),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-payload-field')),
      'AA BB {{level}} 01',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) => widget is ToolTextField && widget.label == '名称',
      ),
      '级别',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) => widget is ToolTextField && widget.label == '默认值',
      ),
      '55',
    );
    await tester.tap(find.widgetWithText(ToolButton, '保存').first);
    await tester.pumpAndSettle();

    expect(find.text('查询'), findsOneWidget);
    expect(find.text('查询状态'), findsWidgets);
    expect(find.text('AA BB {{level}} 01'), findsOneWidget);

    final Finder commandItem = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'command-library-item-',
          ),
    );
    final Finder enabledControl = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'command-library-enabled-control-',
          ),
    );
    final Finder quickAccessControl = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'command-library-quick-access-control-',
          ),
    );
    final Finder statusControls = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'command-library-status-controls-',
          ),
    );
    final Finder commandActions = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'command-library-actions-',
          ),
    );
    expect(
      tester.widget<Container>(commandItem).padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
    expect(
      find.descendant(of: enabledControl, matching: find.text('启用')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: quickAccessControl, matching: find.text('快捷入口')),
      findsOneWidget,
    );
    expect(
      tester.getRect(quickAccessControl).left -
          tester.getRect(enabledControl).right,
      8,
    );
    expect(
      tester.getRect(commandActions).left -
          tester.getRect(statusControls).right,
      8,
    );

    await tester.tap(findToolTooltip('快捷入口'));
    await tester.pumpAndSettle();
    await selectAppMode(tester, 'debug');
    expect(find.bySemanticsLabel('查询状态：AA BB {{level}} 01'), findsOneWidget);
    expect(find.text('AA'), findsOneWidget);
    expect(find.text('BB'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    final Finder panel = find.byKey(
      const ValueKey<String>('quick-commands-panel'),
    );
    final Finder header = find.byKey(
      const ValueKey<String>('quick-commands-header'),
    );
    final Finder item = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'quick-command-item-',
          ),
    );
    final Finder scrollbar = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'quick-command-scrollbar-',
          ),
    );
    expect(tester.getRect(item).left, tester.getRect(panel).left);
    expect(tester.getRect(item).right, tester.getRect(panel).right);
    expect(tester.getRect(scrollbar).left, tester.getRect(item).left);
    expect(tester.getRect(scrollbar).right, tester.getRect(item).right);
    final Finder frameScroll = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'quick-command-frame-scroll-',
          ),
    );
    final Finder sendButton = find.byWidgetPredicate(
      (Widget widget) =>
          widget is ToolIconButton &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'quick-command-send-',
          ),
    );
    final Finder quickCommandsTitleFinder = find.descendant(
      of: header,
      matching: find.text('快捷指令'),
    );
    expect(
      tester.getRect(quickCommandsTitleFinder).left -
          tester.getRect(panel).left,
      8,
    );
    final Text quickCommandsTitle = tester.widget<Text>(
      quickCommandsTitleFinder,
    );
    expect(quickCommandsTitle.style?.fontSize, 12);
    final Text fixedByte = tester.widget<Text>(find.text('AA'));
    expect(fixedByte.style?.fontSize, 11);
    final Rect firstByteRect = tester.getRect(find.text('AA'));
    final Rect secondByteRect = tester.getRect(find.text('BB'));
    expect(secondByteRect.left - firstByteRect.right, lessThanOrEqualTo(16));
    final Finder parameterCell = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'quick-command-parameter-cell-',
          ),
    );
    final Finder parameterLabel = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'quick-command-parameter-label-',
          ),
    );
    final Finder parameterInput = find.byWidgetPredicate(
      (Widget widget) =>
          widget is ToolTextField &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'quick-command-parameter-',
          ),
    );
    final ToolTextField parameterField = tester.widget<ToolTextField>(
      parameterInput,
    );
    expect(tester.getSize(parameterCell).width, 36);
    expect(tester.getSize(parameterInput).height, 24);
    expect(
      parameterField.padding,
      const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
    );
    expect(parameterField.style?.fontSize, 11);
    expect(parameterField.placeholderStyle?.fontSize, 9);
    final Text parameterLabelText = tester.widget<Text>(
      find.descendant(of: parameterLabel, matching: find.text('级别')),
    );
    expect(parameterLabelText.style?.fontSize, 9);
    expect(
      tester.getRect(parameterLabel).center.dx,
      tester.getRect(parameterCell).center.dx,
    );
    expect(
      tester.getRect(parameterInput).center.dx,
      tester.getRect(parameterCell).center.dx,
    );
    expect(tester.getRect(parameterInput).center.dy, firstByteRect.center.dy);
    expect(
      tester.getRect(sendButton).center.dy,
      tester.getRect(parameterInput).center.dy,
    );
    expect(
      tester.getRect(frameScroll).bottom -
          tester.getRect(parameterInput).bottom,
      8,
    );
    expect(
      tester.getRect(parameterCell).right -
          tester.getRect(parameterInput).right,
      0,
    );
    expect(
      tester.getRect(find.text('01')).left -
          tester.getRect(parameterCell).right,
      greaterThanOrEqualTo(4),
    );
  });

  testWidgets('响应映射编辑器使用紧凑表单行和滚动弹窗', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await selectAppMode(tester, 'configure');
    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-section-3')),
    );
    await tester.pumpAndSettle();

    final Finder mappingList = find.byKey(
      const ValueKey<String>('response-mapping-library-list'),
    );
    final Finder newMappingButton = find.byKey(
      const ValueKey<String>('new-response-mapping-button'),
    );
    expect(mappingList, findsOneWidget);
    expect(
      tester.widget<ListView>(mappingList).padding,
      const EdgeInsets.all(12),
    );
    expect(tester.getSize(newMappingButton).height, 32);

    await tester.tap(newMappingButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('response-mapping-name-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('response-mapping-command-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('response-mapping-ascii-log-row')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('response-mapping-name-field')),
      '状态响应',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('response-mapping-command-field')),
      '90',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('add-response-mapping-field-button')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('response-mapping-field-row-0')),
      findsOneWidget,
    );
    final Finder mappingFieldRow = find.byKey(
      const ValueKey<String>('response-mapping-field-row-0'),
    );
    final ToolTextField keyField = tester.widget<ToolTextField>(
      find.descendant(
        of: mappingFieldRow,
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is ToolTextField && widget.label == 'key',
        ),
      ),
    );
    final ToolTextField labelField = tester.widget<ToolTextField>(
      find.descendant(
        of: mappingFieldRow,
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is ToolTextField && widget.label == '字段名称',
        ),
      ),
    );
    expect(keyField.initialValue, isEmpty);
    expect(keyField.hintText, 'key');
    expect(labelField.initialValue, isEmpty);
    expect(labelField.hintText, '字段名称');
    final Finder deleteFieldButton = find.descendant(
      of: mappingFieldRow,
      matching: find.byWidgetPredicate(
        (Widget widget) => widget is ToolIconButton && widget.tooltip == '删除字段',
      ),
    );
    expect(deleteFieldButton, findsOneWidget);
    expect(
      tester.getCenter(deleteFieldButton).dy,
      closeTo(tester.getRect(mappingFieldRow).center.dy, 1),
    );
    await tester.enterText(
      find.descendant(
        of: mappingFieldRow,
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is ToolTextField && widget.label == 'key',
        ),
      ),
      'status',
    );

    final Finder saveButton = find.widgetWithText(ToolButton, '保存').last;
    expect(tester.getSize(saveButton).height, 34);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('状态响应'), findsOneWidget);
    expect(find.text('CMD 90'), findsOneWidget);
    expect(find.text('DATA[0] status uint8'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('response-mapping-ascii-off')),
      findsOneWidget,
    );
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
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, 'Write'),
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
    await tester.tap(find.text('Write'));
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

  testWidgets('设备发送策略弹窗标题对齐且操作按钮保持紧凑', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    await tester.tap(findToolTooltip('设备发送策略'));
    await tester.pumpAndSettle();

    final Rect iconRect = tester.getRect(
      find.byKey(const ValueKey<String>('tool-alert-dialog-icon')),
    );
    final Rect titleRect = tester.getRect(find.text('设备发送策略').last);
    final Row titleRow = tester.widget<Row>(
      find.byKey(const ValueKey<String>('tool-alert-dialog-title-row')),
    );
    expect(titleRow.crossAxisAlignment, CrossAxisAlignment.center);
    expect(
      (iconRect.center.dy - titleRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    final Rect deviceSummaryRect = tester.getRect(find.text('设备：BLE 温度传感器'));
    expect(deviceSummaryRect.left, titleRect.left);

    final Finder cancel = find.widgetWithText(ToolButton, '取消');
    final Finder save = find.widgetWithText(ToolButton, '保存');
    final Size cancelSize = tester.getSize(cancel);
    final Size saveSize = tester.getSize(save);
    expect(cancelSize.height, 34);
    expect(saveSize.height, 34);
    expect(cancelSize.width, greaterThan(64));
    expect(saveSize.width, greaterThan(64));

    final Rect responseSwitchRect = tester.getRect(
      find.byKey(const ValueKey<String>('device-policy-response-switch')),
    );
    final Rect responseTitleRect = tester.getRect(find.text('只允许带响应写入'));
    expect(responseSwitchRect.right, lessThan(responseTitleRect.left));
    expect(
      (responseSwitchRect.center.dy - responseTitleRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );

    final Finder maxFrameRow = find.byKey(
      const ValueKey<String>('device-policy-max-frame-row'),
    );
    final Rect maxFrameLabelRect = tester.getRect(
      find.descendant(of: maxFrameRow, matching: find.text('最终帧最大字节数')),
    );
    final Rect maxFrameInputRect = tester.getRect(
      find.descendant(of: maxFrameRow, matching: find.byType(shad.TextField)),
    );
    expect(maxFrameLabelRect.right, lessThan(maxFrameInputRect.left));
    expect(
      (maxFrameLabelRect.center.dy - maxFrameInputRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('可在左侧新增协议定义', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await selectAppMode(tester, 'configure');
    await tester.tap(find.text('协议'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(shad.TextField).at(0), '主协议');
    await tester.enterText(find.byType(shad.TextField).at(1), '测试设备主链路');
    await tester.tap(
      find.byKey(const ValueKey<String>('protocol-send-add-segment')),
    );
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

    await tester.tap(find.text('Write'));
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

    final Text discoveryHint = tester.widget<Text>(
      find.text('连接设备后可发现其 GATT 特征。'),
    );
    expect(discoveryHint.style?.fontSize, lessThanOrEqualTo(12));
    final Finder statusIcon = find.byKey(
      const ValueKey<String>('characteristic-connection-status-icon'),
    );
    final Icon disconnectedStatusIcon = tester.widget<Icon>(statusIcon);
    expect(disconnectedStatusIcon.icon, AppIcons.bluetoothOutlined);
    expect(
      disconnectedStatusIcon.color,
      AppTheme.colorsOf(tester.element(statusIcon)).mutedForeground,
    );

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    final Icon connectedStatusIcon = tester.widget<Icon>(statusIcon);
    expect(connectedStatusIcon.icon, AppIcons.bluetoothConnected);
    expect(
      connectedStatusIcon.color,
      AppTheme.colorsOf(tester.element(statusIcon)).chart2,
    );

    final Finder filter = find.byKey(
      const ValueKey<String>('characteristic-filter'),
    );
    final Finder panel = find.byKey(
      const ValueKey<String>('characteristic-panel'),
    );
    final Finder pinnedHeader = find.byKey(
      const ValueKey<String>('characteristic-panel-pinned-header'),
    );
    final Finder characteristicList = find.byKey(
      const ValueKey<String>('characteristic-list'),
    );
    final Finder listScrollbar = find.byKey(
      const ValueKey<String>('characteristic-list-scrollbar'),
    );
    expect(
      find.descendant(of: characteristicList, matching: pinnedHeader),
      findsNothing,
    );
    expect(
      find.descendant(of: characteristicList, matching: filter),
      findsNothing,
    );
    expect(tester.getRect(listScrollbar).right, tester.getRect(panel).right);
    expect(
      tester.getRect(filter).left - tester.getRect(panel).left,
      greaterThanOrEqualTo(10),
    );
    final shad.TextField filterField = tester.widget<shad.TextField>(
      find.descendant(of: filter, matching: find.byType(shad.TextField)),
    );
    expect(filterField.style?.fontSize, 12);
    expect(tester.getSize(filter).height, lessThanOrEqualTo(36));
    await tester.tap(filter);
    await tester.pump();
    final shad.FocusOutline filterFocusOutline = tester
        .widget<shad.FocusOutline>(
          find.descendant(of: filter, matching: find.byType(shad.FocusOutline)),
        );
    expect(filterFocusOutline.focused, isTrue);
    expect(
      tester.getRect(filter).left - tester.getRect(pinnedHeader).left,
      greaterThanOrEqualTo(2),
    );

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

    final ToolSelectedButton writeMode = tester.widget<ToolSelectedButton>(
      find.widgetWithText(ToolSelectedButton, 'Write'),
    );
    expect(writeMode.compact, isTrue);
    expect(writeMode.emphasis, ToolSelectedEmphasis.subtle);
    expect(writeMode.minHeight, 28);
    expect(
      writeMode.padding,
      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    );
    expect(find.text('R←'), findsOneWidget);
    expect(find.text('W→'), findsOneWidget);
    expect(find.text('WNR→'), findsOneWidget);
    expect(find.text('N←'), findsNWidgets(2));
    expect(find.text('I←'), findsOneWidget);
    for (final String description in <String>[
      '读取：客户端拉取数据',
      '写入响应：客户端推送，服务端返回确认',
      '无响应写入：客户端推送，服务端不返回确认',
      '通知：服务端推送，客户端不返回确认',
      '指示：服务端推送，客户端返回确认',
    ]) {
      expect(findToolTooltip(description), findsWidgets);
    }
    for (final String label in <String>[
      'R/W',
      'Write',
      'Write No Response',
      'Notify',
      'Indicate',
    ]) {
      final Text actionLabel = tester.widget<Text>(
        find.descendant(
          of: find.widgetWithText(ToolSelectedButton, label).first,
          matching: find.text(label),
        ),
      );
      expect(actionLabel.style?.fontSize, lessThanOrEqualTo(12));
    }
    final ToolButton readButton = tester.widget<ToolButton>(
      find.widgetWithText(ToolButton, 'Read'),
    );
    expect(readButton.height, 28);
    for (final String label in <String>[
      'Write',
      'Write No Response',
      'Notify',
      'Indicate',
    ]) {
      expect(
        tester
            .getSize(find.widgetWithText(ToolSelectedButton, label).first)
            .height,
        28,
      );
    }
  });

  testWidgets('点击控制台日志后 Inspector 显示帧详情', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ToolSelectedButton, 'Write'), findsOneWidget);
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, 'Write'),
          )
          .value,
      isTrue,
    );
    expect(find.text('写入  0000FFF1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('console-send-area')),
        matching: find.text('写入  0000FFF1'),
      ),
      findsOneWidget,
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
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('console-log-details-button')).first,
      ),
      const Size.square(32),
    );
    await tester.tap(detailsButton.first);
    await tester.pump();
    expect(find.text('选中日志'), findsOneWidget);
    expect(find.textContaining('AA BB'), findsWidgets);
  });

  testWidgets('控制台可按 HEX 搜索、筛选方向并导出结果', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ToolSelectedButton>(
            find.widgetWithText(ToolSelectedButton, 'Write'),
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
    final Finder filterMenu = find.byKey(
      const ValueKey<String>('console-log-filter-menu'),
    );
    final Finder selectedIndicator = find.byKey(
      const ValueKey<String>('console-log-filter-indicator-all'),
    );
    final Finder allFilterLabel = find.descendant(
      of: find.byKey(const ValueKey<String>('console-log-filter-option-all')),
      matching: find.byType(Text),
    );
    expect(tester.getSize(filterMenu).width, 136);
    expect(
      tester.getRect(allFilterLabel).left -
          tester.getRect(selectedIndicator).right,
      4,
    );
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

  testWidgets('用户可在两种写入模式间互斥选择并按实际模式发送', (WidgetTester tester) async {
    final MockBluetoothService bluetoothService = MockBluetoothService();
    await pumpDesktopApp(tester, bluetoothService: bluetoothService);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();

    final Finder write = find.widgetWithText(ToolSelectedButton, 'Write');
    final Finder writeNoResponse = find.widgetWithText(
      ToolSelectedButton,
      'Write No Response',
    );
    expect(write, findsOneWidget);
    expect(writeNoResponse, findsOneWidget);

    await tester.tap(writeNoResponse);
    await tester.pumpAndSettle();
    expect(tester.widget<ToolSelectedButton>(writeNoResponse).value, isTrue);
    expect(tester.widget<ToolSelectedButton>(write).value, isFalse);
    await tester.enterText(
      find.byKey(const ValueKey<String>('console-input')),
      'AA',
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
    expect(
      bluetoothService.sentWriteModes.last,
      BluetoothWriteMode.withoutResponse,
    );

    await tester.tap(write);
    await tester.pumpAndSettle();
    expect(tester.widget<ToolSelectedButton>(write).value, isTrue);
    expect(tester.widget<ToolSelectedButton>(writeNoResponse).value, isFalse);
    await tester.enterText(
      find.byKey(const ValueKey<String>('console-input')),
      'BB',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('console-send-button')));
    await tester.pumpAndSettle();
    expect(
      bluetoothService.sentWriteModes.last,
      BluetoothWriteMode.withResponse,
    );
  });

  testWidgets('高风险命令在发送前要求确认', (WidgetTester tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(findToolTooltip('连接设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write'));
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
    await tester.tap(find.text('Write'));
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
        of: find.byKey(const ValueKey<String>('command-confirmation-row')),
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
    final Finder recordFilter = find.byKey(
      const ValueKey<String>('session-record-filter'),
    );
    expect(
      find.byKey(const ValueKey<String>('session-record-filter-toolbar')),
      findsOneWidget,
    );
    final double emptyFilterHeight = tester.getSize(recordFilter).height;
    await tester.enterText(recordFilter, 'session-record-filter-test');
    await tester.pumpAndSettle();

    expect(emptyFilterHeight, 32);
    expect(tester.getSize(recordFilter).height, emptyFilterHeight);
    expect(
      tester.getSize(find.widgetWithText(ToolSelectedButton, '全部')).height,
      32,
    );
    expect(tester.getSize(findToolTooltip('导出会话记录')).height, 32);
    expect(
      tester
          .getRect(
            find.byKey(
              const ValueKey<String>('session-record-toolbar-actions'),
            ),
          )
          .left,
      greaterThan(
        tester.getRect(find.widgetWithText(ToolSelectedButton, '书签')).right,
      ),
    );
    expect(
      tester.getSize(findToolTooltip('清除筛选')).height,
      lessThanOrEqualTo(24),
    );
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
    await tester.tap(find.text('Write'));
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
