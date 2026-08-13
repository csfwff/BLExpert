import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blexpert/main.dart';

void main() {
  Future<void> pumpDesktopApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BlexpertApp(locale: Locale('zh')));
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
}
