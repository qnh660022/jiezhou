// V2.8.1 S2 · 玻璃基建（规格 §5.6，≥8 例）：
// GlassSurface 四档 decoration / 降级路径 / GlassAppBar 收缩 / SheetContainer 键盘避让 /
// 深色分档 / pageTransitionsTheme / tokens 纯追加回归。
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/shared/widgets/glass_app_bar.dart';
import 'package:travel_assistant/shared/widgets/glass_surface.dart';
import 'package:travel_assistant/shared/widgets/sheet.dart';
import 'package:travel_assistant/theme/tokens.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E7D5B),
        brightness: brightness,
      ),
    ),
    home: Scaffold(body: child),
  );
}

/// 取 GlassSurface 内部装饰 Container（BackdropFilter 的直接子级）。
BoxDecoration? _glassDecorationOf(WidgetTester tester) {
  final bf = tester.widgetList<BackdropFilter>(find.byType(BackdropFilter));
  if (bf.isEmpty) return null;
  final container = tester.widget<Container>(
      find.descendant(of: find.byType(BackdropFilter), matching: find.byType(Container)).first);
  return container.decoration as BoxDecoration?;
}

void main() {
  testWidgets('1. 四档 level：tint/阴影按修正表缩放', (tester) async {
    final expectTint = {
      GlassLevel.navBar: GlassTokens.tintAlphaLight * 1.0,
      GlassLevel.sheet: GlassTokens.tintAlphaLight * 1.0,
      GlassLevel.floatingCard: GlassTokens.tintAlphaLight * 0.92,
      GlassLevel.overlay: GlassTokens.tintAlphaLight * 0.95,
    };
    final expectShadowMul = {
      GlassLevel.navBar: 0.6,
      GlassLevel.sheet: 1.0,
      GlassLevel.floatingCard: 1.2,
      GlassLevel.overlay: 0.8,
    };
    for (final level in GlassLevel.values) {
      await tester.pumpWidget(_host(GlassSurface(level: level, child: const SizedBox())));
      await tester.pump();
      final deco = _glassDecorationOf(tester);
      expect(deco, isNotNull, reason: '$level 应有玻璃装饰');
      final base = deco!.color!;
      expect(base.alpha, ((expectTint[level]!) * 255).round(),
          reason: '$level tint α=${expectTint[level]}');
      expect(deco.boxShadow!.length, 2, reason: '$level 双层阴影');
      expect(deco.boxShadow![0].blurRadius, 40);
      expect(deco.boxShadow![0].offset, const Offset(0, 18));
      // 环影 α = 0.10 × 档位倍率（浅色）；α 有 8bit 量化，容差 1.5/255
      final ambient = deco.boxShadow![0].color.alpha / 255;
      expect(ambient, closeTo(0.10 * expectShadowMul[level]!, 1.5 / 255),
          reason: '$level 环影倍率');
      expect(deco.gradient, isA<LinearGradient>(), reason: '$level 前景高光');
      expect((deco.gradient as LinearGradient).stops!.last, 0.38);
    }
  });

  testWidgets('2. disableAnimations 降级：无 BackdropFilter、不透明表面', (tester) async {
    await tester.pumpWidget(_host(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: GlassSurface(child: const Text('降级')),
    )));
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('降级'), findsOneWidget);
  });

  testWidgets('3. fallbackOpaque 强制降级', (tester) async {
    await tester.pumpWidget(_host(GlassSurface(
      fallbackOpaque: true,
      child: const Text('静态'),
    )));
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('4. GlassAppBar 大标题随滚动收缩（回归）', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D5B)),
      ),
      home: Scaffold(
        appBar: GlassAppBar(
          title: '返回标题',
          largeTitle: '大标题',
          scrollController: controller,
        ),
        body: ListView(controller: controller, children: const [
          SizedBox(height: 2000),
        ]),
      ),
    ));
    await tester.pump();

    double titleOpacity() {
      final opacity = tester.widget<Opacity>(
        find.ancestor(
            of: find.text('大标题'), matching: find.byType(Opacity)).first,
      );
      return opacity.opacity;
    }

    expect(titleOpacity(), 1.0);
    controller.jumpTo(72);
    await tester.pumpAndSettle();
    expect(titleOpacity(), 0.0, reason: 'offset>36 后大标题完全隐去');
    expect(find.text('返回标题'), findsOneWidget);
  });

  testWidgets('5. SheetContainer 键盘避让回归（既有行为不变）', (tester) async {
    await tester.pumpWidget(_host(MediaQuery(
      data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 120)),
      child: SheetContainer(
        scrollController: ScrollController(),
        child: const Text('表单'),
      ),
    )));
    await tester.pump();
    final padding = tester.widget<Padding>(find.byWidgetPredicate(
      (w) => w is Padding && w.child is Column,
      description: 'SheetContainer 主 Padding',
    ));
    expect((padding.padding as EdgeInsets).bottom, 120, reason: '键盘 insets 全额避让');
  });

  testWidgets('6. 深色模式 tint/highlight 取深色档', (tester) async {
    await tester.pumpWidget(_host(
        GlassSurface(level: GlassLevel.sheet, child: const SizedBox()),
        brightness: Brightness.dark));
    await tester.pump();
    final deco = _glassDecorationOf(tester)!;
    expect(deco.color!.alpha, (GlassTokens.tintAlphaDark * 255).round(),
        reason: '深色 tint 档');
    final hl = (deco.gradient as LinearGradient).colors.first.alpha / 255;
    expect(hl, closeTo(GlassTokens.highlightAlphaDark, 0.001), reason: '深色高光档');
  });

  test('7. pageTransitionsTheme 双平台断言', () {
    final theme = buildAppTheme('mint');
    final builders = theme.pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>(),
        reason: 'iOS 获得右滑返回');
    expect(builders[TargetPlatform.android], isA<ZoomPageTransitionsBuilder>());
  });

  test('8. tokens 纯追加回归：既有令牌值逐一不变', () {
    // 圆角
    expect(AppRadius.cardValue, 24);
    expect(AppRadius.inputValue, 16);
    expect(AppRadius.buttonValue, 14);
    // 间距（4px 网格）
    expect(Spacing.xs, 4);
    expect(Spacing.sm, 8);
    expect(Spacing.md, 12);
    expect(Spacing.lg, 16);
    expect(Spacing.xl, 20);
    expect(Spacing.xxl, 24);
    expect(Spacing.xxxl, 32);
    expect(Spacing.huge, 48);
    // 新增玻璃令牌按规格逐字段
    expect(GlassTokens.sigma, 28);
    expect(GlassTokens.tintAlphaLight, 0.52);
    expect(GlassTokens.tintAlphaDark, 0.42);
    expect(GlassTokens.highlightAlphaLight, 0.65);
    expect(GlassTokens.highlightAlphaDark, 0.22);
    expect(GlassTokens.edgeAlphaLight, 0.28);
    expect(GlassTokens.edgeAlphaDark, 0.07);
    expect(GlassTokens.saturation, 1.35);
  });

  test('9. B1 收口：lib 内 BackdropFilter 仅 glass_surface.dart 一处实现', () {
    // 门禁随行测试（规格 §5.7）：业务层手写毛玻璃必须为 0
    final dirs = [
      'lib/features',
      'lib/shared',
      'lib/theme',
      'lib/core',
    ];
    for (final d in dirs) {
      final dir = Directory(d);
      if (!dir.existsSync()) continue;
      final files = dir.listSync(recursive: true).whereType<File>().where(
          (f) => f.path.endsWith('.dart') && !f.path.endsWith('glass_surface.dart'));
      for (final f in files) {
        expect(f.readAsStringSync().contains('BackdropFilter('), isFalse,
            reason: '${f.path} 仍手写 BackdropFilter（应改用 GlassSurface）');
      }
    }
  });
}
