import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blexpert/app/design/tool_button.dart';
import 'package:blexpert/app/design/tool_tooltip.dart';
import 'package:blexpert/app/design/tool_toggle.dart';
import 'package:blexpert/main.dart';
import 'package:blexpert/services/bluetooth_service.dart';

void main() {
  Finder findToolTooltip(String message) => find.byWidgetPredicate(
    (Widget widget) => widget is ToolTooltip && widget.message == message,
    description: 'ToolTooltip with message "$message"',
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    required Brightness brightness,
    BluetoothService? bluetoothService,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      BlexpertApp(
        locale: const Locale('zh'),
        bluetoothService: bluetoothService ?? MockBluetoothService(),
        shadcnPlatform: TargetPlatform.linux,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> selectMode(WidgetTester tester, String mode) async {
    await tester.tap(find.byKey(ValueKey<String>('app-mode-$mode')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('桌面调试工作台 ${brightness.name} 页面 Golden', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        size: const Size(1440, 900),
        brightness: brightness,
      );

      await tester.tap(findToolTooltip('连接设备'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('写入目标'));
      await tester.pumpAndSettle();
      await tester.tap(findToolTooltip('清空'));
      await tester.pumpAndSettle();

      expect(find.byType(shad.NavigationRail), findsOneWidget);
      expect(find.byType(ToolSelectedButton), findsAtLeastNWidgets(4));
      expect(find.byType(ToolSwitch), findsAtLeastNWidgets(1));
      expect(find.text('写入目标'), findsOneWidget);
      expect(
        tester
            .widget<ToolSelectedButton>(
              find.widgetWithText(ToolSelectedButton, '写入目标'),
            )
            .value,
        isTrue,
      );

      await expectLater(
        find.byType(shad.Scaffold),
        matchesGoldenFile('goldens/ui_page_desktop_${brightness.name}.png'),
      );
    });

    testWidgets('窄屏记录工作台 ${brightness.name} 页面 Golden', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, size: const Size(375, 812), brightness: brightness);

      await selectMode(tester, 'records');

      expect(
        find.byKey(const ValueKey<String>('app-mode-navigation-mobile')),
        findsOneWidget,
      );
      expect(find.byType(ToolSelectedButton), findsAtLeastNWidgets(6));
      expect(find.text('会话记录'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);

      await expectLater(
        find.byType(shad.Scaffold),
        matchesGoldenFile('goldens/ui_page_mobile_${brightness.name}.png'),
      );
    });
  }
}
