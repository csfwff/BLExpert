import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'package:blexpert/app/app_theme.dart';
import 'package:blexpert/app/design/tool_button.dart';
import 'package:blexpert/app/design/tool_toggle.dart';
import 'package:blexpert/app/design/tool_tooltip.dart';

double _contrastRatio(Color first, Color second) {
  final double lighter = first.computeLuminance() + 0.05;
  final double darker = second.computeLuminance() + 0.05;
  return lighter > darker ? lighter / darker : darker / lighter;
}

Color _compositeOver(Color foreground, Color background) =>
    Color.alphaBlend(foreground, background);

Widget _themedHarness({
  required Widget child,
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) {
  return shad.ShadcnApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(brightness, platform: TargetPlatform.linux),
    darkTheme: buildAppTheme(brightness, platform: TargetPlatform.linux),
    themeMode: brightness == Brightness.dark
        ? shad.ThemeMode.dark
        : shad.ThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Center(child: child),
    ),
  );
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    test('$brightness 主题满足文字和状态对比度', () {
      final shad.ColorScheme colors = buildAppTheme(brightness).colorScheme;
      expect(
        _contrastRatio(colors.foreground, colors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.mutedForeground, colors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.primaryForeground, colors.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.secondaryForeground, colors.secondary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.popoverForeground, colors.popover),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.primary, colors.card),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(colors.ring, colors.background),
        greaterThanOrEqualTo(3),
      );

      final Color hoveredUnselected = _compositeOver(
        colors.primary.withValues(alpha: 0.10),
        colors.card,
      );
      final Color disabledSelected = _compositeOver(
        colors.secondary.withValues(alpha: 0.48),
        colors.background,
      );
      expect(
        _contrastRatio(colors.foreground, hoveredUnselected),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.secondaryForeground, disabledSelected),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.primary, disabledSelected),
        greaterThanOrEqualTo(3),
      );
    });
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('$brightness Tooltip 使用有背景的主题容器', (WidgetTester tester) async {
      await tester.pumpWidget(
        _themedHarness(
          brightness: brightness,
          child: const ToolTooltip(
            message: '悬浮说明',
            child: ColoredBox(
              key: ValueKey<String>('tooltip-trigger'),
              color: Color(0x01000000),
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );

      final Finder tooltipFinder = find.byType(shad.Tooltip);
      final shad.Tooltip tooltip = tester.widget<shad.Tooltip>(tooltipFinder);
      final Widget tooltipContent = tooltip.tooltip(
        tester.element(tooltipFinder),
      );
      expect(tooltipContent, isA<Container>());

      await tester.pumpWidget(
        _themedHarness(brightness: brightness, child: tooltipContent),
      );
      await tester.pump();

      final Finder surfaceFinder = find.byKey(
        const ValueKey<String>('tool-tooltip-surface'),
      );
      expect(surfaceFinder, findsOneWidget);
      expect(find.text('悬浮说明'), findsOneWidget);
      final Container surface = tester.widget<Container>(surfaceFinder);
      final BoxDecoration decoration = surface.decoration! as BoxDecoration;
      expect(
        surface.padding,
        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      );
      expect(decoration.color, buildAppTheme(brightness).colorScheme.popover);
      expect(decoration.border, isNotNull);
    });
  }

  testWidgets('已有可见标签时 Tooltip 只保留语义', (WidgetTester tester) async {
    await tester.pumpWidget(
      _themedHarness(
        child: const ToolTooltip(
          message: '可见标签',
          showVisual: false,
          child: Text('可见标签'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(shad.Tooltip), findsNothing);
    expect(tester.getSemantics(find.text('可见标签')).tooltip, '可见标签');
  });

  testWidgets('选择按钮公开持久选中语义', (WidgetTester tester) async {
    await tester.pumpWidget(
      _themedHarness(
        child: ToolSelectedButton(
          value: true,
          onChanged: (_) {},
          child: const Text('当前模式'),
        ),
      ),
    );
    await tester.pump();

    final SemanticsNode semantics = tester.getSemantics(find.text('当前模式'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('选择按钮禁用态保留语义且不响应点击', (WidgetTester tester) async {
    bool changed = false;
    await tester.pumpWidget(
      _themedHarness(
        child: ToolSelectedButton(
          value: true,
          enabled: false,
          onChanged: (_) => changed = true,
          child: const Text('禁用模式'),
        ),
      ),
    );
    await tester.pump();

    final SemanticsNode semantics = tester.getSemantics(find.text('禁用模式'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(find.text('禁用模式'));
    expect(changed, isFalse);
  });

  testWidgets('选择按钮通过键盘获得焦点环', (WidgetTester tester) async {
    await tester.pumpWidget(
      _themedHarness(
        child: ToolSelectedButton(
          value: false,
          onChanged: (_) {},
          child: const Text('键盘模式'),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final shad.FocusOutline outline = tester.widget<shad.FocusOutline>(
      find.byType(shad.FocusOutline),
    );
    expect(outline.focused, isTrue);
  });

  testWidgets('Switch 在中间帧移动并在 200ms 到达终态', (WidgetTester tester) async {
    bool value = false;
    await tester.pumpWidget(
      _themedHarness(
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => ToolSwitch(
            value: value,
            onChanged: (bool next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder thumb = find.byKey(
      const ValueKey<String>('tool-switch-thumb-position'),
    );
    final double start = tester.getCenter(thumb).dx;
    await tester.tap(find.byType(ToolSwitch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final double middle = tester.getCenter(thumb).dx;
    await tester.pump(const Duration(milliseconds: 100));
    final double end = tester.getCenter(thumb).dx;

    expect(middle, greaterThan(start));
    expect(middle, lessThan(end));
    expect(value, isTrue);
  });

  testWidgets('减少动态效果时 Switch 直接到达终态', (WidgetTester tester) async {
    bool value = false;
    await tester.pumpWidget(
      _themedHarness(
        disableAnimations: true,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => ToolSwitch(
            value: value,
            onChanged: (bool next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder thumb = find.byKey(
      const ValueKey<String>('tool-switch-thumb-position'),
    );
    final double start = tester.getCenter(thumb).dx;
    await tester.tap(find.byType(ToolSwitch));
    await tester.pump();
    final double end = tester.getCenter(thumb).dx;

    expect(end, greaterThan(start));
    expect(value, isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('亮暗主题组件边界 Golden', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final Brightness brightness in Brightness.values) {
      await tester.pumpWidget(
        _themedHarness(
          brightness: brightness,
          child: RepaintBoundary(
            key: const ValueKey<String>('ui-state-golden'),
            child: shad.Card(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ToolSelectedButton(
                    value: false,
                    onChanged: (_) {},
                    child: const Text('Inactive'),
                  ),
                  const SizedBox(width: 8),
                  ToolSelectedButton(
                    value: true,
                    onChanged: (_) {},
                    child: const Text('Selected'),
                  ),
                  const SizedBox(width: 16),
                  ToolSwitch(value: true, onChanged: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey<String>('ui-state-golden')),
        matchesGoldenFile('goldens/ui_states_${brightness.name}.png'),
      );
    }
  });
}
