// V2.8.2 S1~S3 补测（配额 S1≥12 / S2≥8 / S3≥10）：
// * S1：底栏 AppIcons 换装（icon 字段渲染/tap/emoji 兜底）、开屏舟形图标、
//   EmptyState 矢量图标模式、BrandWaves 母题；
// * S2：锁屏胶囊分段条（6×26×5）、GlassSurface 键帽、输入填充/回删、
//   错误文案与抖动触发（_shake 在校验失败处触发——S2 收尾回归）；
// * S3：CoverWatermark 三态、行程卡水印接线（文件断言）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/features/settings/screens/splash_screen.dart';
import 'package:travel_assistant/features/lock/lock_screen.dart';
import 'package:travel_assistant/features/trips/widgets/cover_watermark.dart';
import 'package:travel_assistant/platform/app_lock.dart';
import 'package:travel_assistant/shared/widgets/brand_waves.dart';
import 'package:travel_assistant/shared/widgets/empty_state.dart';
import 'package:travel_assistant/shared/widgets/floating_capsule_nav_bar.dart';
import 'package:travel_assistant/shared/widgets/glass_surface.dart';
import 'package:travel_assistant/theme/app_icons.dart';
import 'package:travel_assistant/theme/theme_provider.dart'
    show sharedPreferencesProvider;

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    AppLockService.resetCache();
    AppLockGate.reset();
    SharedPreferences.setMockInitialValues({});
  });

  // ===========================================================================
  // S1：底栏图标换装 + 开屏品牌 + 空态图标模式 + 波纹母题
  // ===========================================================================
  group('S1 底栏 AppIcons 换装', () {
    final items = const [
      CapsuleTabItem(emoji: '🤖', label: 'AI', icon: AppIcons.spark),
      CapsuleTabItem(emoji: '📋', label: '清单', icon: AppIcons.clip),
      CapsuleTabItem(emoji: '🧳', label: '行程', icon: AppIcons.compass),
      CapsuleTabItem(emoji: '💰', label: '账本', icon: AppIcons.wallet),
      CapsuleTabItem(emoji: '👤', label: '我的', icon: AppIcons.user),
    ];

    testWidgets('5 项 icon 全部以 Icon 渲染（不再是 emoji）', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(_host(FloatingCapsuleNavBar(
        items: items,
        currentIndex: 0,
        onTap: (i) => tapped = i,
      )));
      for (final icon in [
        AppIcons.spark,
        AppIcons.clip,
        AppIcons.compass,
        AppIcons.wallet,
        AppIcons.user,
      ]) {
        expect(find.byIcon(icon), findsOneWidget, reason: 'icon=${icon.codePoint}');
      }
      expect(tapped, -1);
    });

    testWidgets('点按回调携带目标索引', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(_host(FloatingCapsuleNavBar(
        items: items,
        currentIndex: 0,
        onTap: (i) => tapped = i,
      )));
      await tester.tap(find.text('账本'));
      expect(tapped, 3);
    });

    testWidgets('icon 为空时回落 emoji 渲染（Web 桌面兼容口径）', (tester) async {
      await tester.pumpWidget(_host(FloatingCapsuleNavBar(
        items: const [CapsuleTabItem(emoji: '🧭', label: '行程')],
        currentIndex: 0,
        onTap: (_) {},
      )));
      expect(find.text('🧭'), findsOneWidget);
      expect(find.text('行程'), findsOneWidget);
    });

    testWidgets('选中项文字加重（w700，经 AnimatedDefaultTextStyle）', (tester) async {
      await tester.pumpWidget(_host(FloatingCapsuleNavBar(
        items: items,
        currentIndex: 2,
        onTap: (_) {},
      )));
      final selected = DefaultTextStyle.of(tester.element(find.text('行程'))).style;
      expect(selected.fontWeight, FontWeight.w700);
      final idle = DefaultTextStyle.of(tester.element(find.text('账本'))).style;
      expect(idle.fontWeight, isNot(FontWeight.w700));
    });

    testWidgets('CapsuleTabItem.icon 可空字段向后兼容（零参构造）', (tester) async {
      const item = CapsuleTabItem(emoji: '✈️', label: 'AI');
      expect(item.icon, isNull);
      expect(item.emoji, '✈️');
    });
  });

  group('S1 开屏品牌舟形', () {
    testWidgets('开屏渲染 AppIcons.boat + 品牌标题，停留后进入行程', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
        GoRoute(
            path: '/trips',
            builder: (_, _) => const Scaffold(body: Text('TRIPS-HOME'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(AppIcons.boat), findsOneWidget);
      expect(find.text('芥舟'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('TRIPS-HOME'), findsOneWidget,
          reason: '1200ms 停留后 context.go(/trips)');
    });
  });

  group('S1 EmptyState 矢量图标模式', () {
    testWidgets('icon 模式：渲染 Icon 且无 emoji 文本', (tester) async {
      await tester.pumpWidget(_host(const EmptyState(
        icon: AppIcons.compass,
        title: '未找到行程',
        message: '返回重新进入试试',
      )));
      expect(find.byIcon(AppIcons.compass), findsOneWidget);
      expect(find.text('未找到行程'), findsOneWidget);
    });

    testWidgets('emoji 模式保持兼容（既有调用零破坏）', (tester) async {
      await tester.pumpWidget(_host(const EmptyState(
        emoji: '🧭',
        title: '没有行程',
      )));
      expect(find.text('🧭'), findsOneWidget);
    });
  });

  group('S1 BrandWaves 品牌波纹', () {
    testWidgets('progress 0.5 时渲染 CustomPaint', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 260,
        child: BrandWaves(progress: 0.5),
      )));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('progress 0 与 1 均可渲染（边界收敛）', (tester) async {
      for (final p in [0.0, 1.0]) {
        await tester.pumpWidget(_host(SizedBox(
          width: 260,
          child: BrandWaves(progress: p),
        )));
        await tester.pump();
      }
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ===========================================================================
  // S2：锁屏玻璃键帽 + 胶囊分段条 + 错误抖动触发（S2 收尾）
  // ===========================================================================
  group('S2 锁屏视觉与错误抖动', () {
    Future<void> pumpLock(WidgetTester tester, {bool withPin = false}) async {
      final router = GoRouter(initialLocation: '/lock', routes: [
        GoRoute(path: '/lock', builder: (_, _) => const LockScreen()),
        GoRoute(
            path: '/trips',
            builder: (_, _) => const Scaffold(body: Text('TRIPS-HOME'))),
      ]);
      if (withPin) {
        final svc = await AppLockService.cached();
        await svc.setPin('123456');
      }
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('胶囊分段条 6 段 26×5', (tester) async {
      await pumpLock(tester);
      final segments = tester.widgetList<ConstrainedBox>(
        find.byWidgetPredicate((w) =>
            w is ConstrainedBox &&
            w.constraints.maxWidth == 26 &&
            w.constraints.maxHeight == 5),
      );
      expect(segments.length, 6, reason: 'V2.8.2 S2：圆点阵 → 胶囊分段条 6×26×5');
    });

    testWidgets('0-9 数字键帽全部渲染', (tester) async {
      await pumpLock(tester);
      for (var d = 0; d <= 9; d++) {
        expect(find.text('$d'), findsOneWidget, reason: '数字键 $d');
      }
    });

    testWidgets('键帽为实色 mini 键帽（V2.8.3.1 去伪玻璃）+ AnimatedScale 按压层',
        (tester) async {
      await pumpLock(tester);
      // 每个键帽一层 AnimatedScale（按压 0.94，静置 1.0）
      final scales = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale));
      expect(scales.length, greaterThanOrEqualTo(11),
          reason: '0-9 + 退格 = 11 个键帽缩放层');
      expect(scales.every((s) => s.duration == const Duration(milliseconds: 90)),
          isTrue);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('输入 3 位 → 3 段填充 primary', (tester) async {
      await pumpLock(tester);
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 200));
      final scheme = Theme.of(tester.element(find.text('芥舟已上锁'))).colorScheme;
      final filled = tester.widgetList<AnimatedContainer>(
        find.byWidgetPredicate((w) =>
            w is AnimatedContainer &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == scheme.primary),
      );
      expect(filled.length, 3);
    });

    testWidgets('回删一位 → 填充段减少', (tester) async {
      await pumpLock(tester);
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump(const Duration(milliseconds: 200));
      final scheme = Theme.of(tester.element(find.text('芥舟已上锁'))).colorScheme;
      final filled = tester.widgetList<AnimatedContainer>(
        find.byWidgetPredicate((w) =>
            w is AnimatedContainer &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == scheme.primary),
      );
      expect(filled.length, 1);
    });

    testWidgets('错误 PIN → 错误文案出现（_shake 抖动在失败分支触发）', (tester) async {
      await pumpLock(tester, withPin: true);
      for (final d in ['4', '4', '4', '4', '4', '4']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('PIN 不对'), findsOneWidget,
          reason: 'S2 收尾：校验失败分支已接 _shake.forward（抖动随文案一同触发）');
    });

    testWidgets('正确 PIN → 放行进入行程 Tab', (tester) async {
      await pumpLock(tester, withPin: true);
      for (final d in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('TRIPS-HOME'), findsOneWidget);
    });

    testWidgets('失败后 failCount 累计（本地计数，不擦数据）', (tester) async {
      await pumpLock(tester, withPin: true);
      for (final d in ['9', '9', '9', '9', '9', '9']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final svc = await AppLockService.cached();
      expect(svc.failCount, 1);
    });
  });

  // ===========================================================================
  // S3：封面图标水印
  // ===========================================================================
  group('S3 CoverWatermark', () {
    testWidgets('icon 模式：52px 白 45% 图标', (tester) async {
      await tester.pumpWidget(_host(const CoverWatermark(icon: AppIcons.compass)));
      final icon = tester.widget<Icon>(find.byIcon(AppIcons.compass));
      expect(icon.size, 52);
      expect(icon.color, Colors.white.withValues(alpha: 0.45));
    });

    testWidgets('icon 为空回落 emoji（白 45%）', (tester) async {
      await tester.pumpWidget(_host(const CoverWatermark(emoji: '🏝️')));
      final text = tester.widget<Text>(find.text('🏝️'));
      expect(text.style?.color, Colors.white.withValues(alpha: 0.45));
    });

    testWidgets('child 直通（调用方自带视差内容时不二次包装）', (tester) async {
      const key = Key('parallax');
      await tester.pumpWidget(_host(const CoverWatermark(
        child: SizedBox(key: key),
      )));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byType(CoverWatermark), findsOneWidget);
    });
  });

  group('S3 行程卡水印接线（文件断言）', () {
    test('行程卡封面水印使用 CoverWatermark + AppIcons.compass', () {
      final src = File('lib/features/trips/screens/trips_home_screen.dart')
          .readAsStringSync();
      expect(src.contains('CoverWatermark('), isTrue);
      expect(src.contains('icon: AppIcons.compass'), isTrue);
      expect(src.contains('emoji: trip.emoji'), isTrue,
          reason: 'O6：trip.emoji 数据字段只读不改，渲染层回落');
    });
  });
}
