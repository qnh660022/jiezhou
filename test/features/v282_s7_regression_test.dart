// V2.8.2 S7 全局回归门禁（配额 ≥12）：
// 版本号 / 图标码点冻结 / 金额 Hero 文本规格 / 天气映射 / 路由注册 /
// 页签定义面 / MoneyFormat 口径回归。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/features/today/widgets/money_hero_text.dart';
import 'package:travel_assistant/shared/widgets/money_text.dart'
    show MoneyFormat;
import 'package:travel_assistant/features/trips/screens/trip_detail_screen.dart';
import 'package:travel_assistant/features/trips/widgets/trip_detail_tabs.dart';
import 'package:travel_assistant/theme/app_icons.dart';
import 'package:travel_assistant/theme/tokens.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('S7-1 版本号（2.8.3.1 → pubspec 2.8.3+2831，.1 由 build 承载）', () {
    test('pubspec version 已升版', () {
      final src = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'version:\s*(\S+)').firstMatch(src);
      expect(match, isNotNull);
      expect(match!.group(1), '2.8.3+2831');
    });
  });

  group('S7-2 AppIcons 码点冻结（提交后防漂移）', () {
    test('底栏五码点', () {
      expect(AppIcons.boat.codePoint, 0xe900);
      expect(AppIcons.spark.codePoint, 0xe901);
      expect(AppIcons.clip.codePoint, 0xe902);
      expect(AppIcons.compass.codePoint, 0xe903);
      expect(AppIcons.wallet.codePoint, 0xe904);
    });

    test('功能码点（S5 页签 + S4 双动作用）', () {
      expect(AppIcons.calendar.codePoint, 0xe910);
      expect(AppIcons.clock.codePoint, 0xe912);
      expect(AppIcons.bolt.codePoint, 0xe913);
      expect(AppIcons.bag.codePoint, 0xe90a);
      expect(AppIcons.bookmark.codePoint, 0xe911);
      expect(AppIcons.camera.codePoint, 0xe91c);
      expect(AppIcons.coins.codePoint, 0xe916);
    });

    test('分类映射完整（7 内置分类 + 自定义兜底）', () {
      expect(AppIcons.categoryIcons.length, 7);
      expect(AppIcons.forCategory('food'), AppIcons.food);
      expect(AppIcons.forCategory('__custom__'), AppIcons.tag);
    });
  });

  group('S7-3 金额 Hero 文本规格（MoneyHeroText 同口径）', () {
    testWidgets('整数大 / 小数缩半 + ¥ 缩小', (tester) async {
      await tester.pumpWidget(_host(const MoneyHeroText(128050, fontSize: 24)));
      final text = tester.widget<Text>(find.byType(Text));
      final span = text.textSpan! as TextSpan;
      final children = span.children!;
      // [¥, 1,280, .50]
      expect(children.length, 3);
      final symbol = children[0] as TextSpan;
      final dec = children[2] as TextSpan;
      expect(symbol.style!.fontSize, closeTo(24 * 0.55, 0.01));
      expect(dec.style!.fontSize, closeTo(24 * 0.5, 0.01));
    });

    testWidgets('负数（退款冲减）显示前导负号', (tester) async {
      await tester.pumpWidget(_host(const MoneyHeroText(-500, fontSize: 24)));
      final text = tester.widget<Text>(find.byType(Text));
      final span = text.textSpan! as TextSpan;
      expect((span.children![0] as TextSpan).text, '-');
    });
  });

  group('S7-4 天气 emoji → 图标映射（S1 渲染层）', () {
    test('8 常见天气映射', () {
      expect(weatherIconFor('☀️'), Icons.wb_sunny_rounded);
      expect(weatherIconFor('⛅'), Icons.cloud_rounded);
      expect(weatherIconFor('🌧'), Icons.water_drop_rounded);
      expect(weatherIconFor('⛈'), Icons.bolt_rounded);
      expect(weatherIconFor('❄️'), Icons.ac_unit_rounded);
      expect(weatherIconFor('🌫'), Icons.blur_on_rounded);
      expect(weatherIconFor('多云'), Icons.cloud_rounded);
    });

    test('未知 emoji → null（原样回退显示 emoji，静默降级）', () {
      expect(weatherIconFor('🛸'), isNull);
      expect(weatherIconFor(''), isNull);
    });
  });

  group('S7-5 路由与组件面回归', () {
    test('顶层 /guide 与 /expenses 注册保持（多入口不切 Tab 口径）', () {
      final src = File('lib/router.dart').readAsStringSync();
      expect(src.contains("path: '/guide'"), isTrue);
      expect(src.contains("path: '/expenses'"), isTrue);
      expect(src.contains('GuideRouteArgs'), isTrue);
    });

    test('TripDetailTabs.kTabs 四页签定义（viewer/editor 可见性口径不变）', () {
      expect(TripDetailTabs.kTabs.length, 4);
      expect(TripDetailTabs.kTabs[0].label, '时间轴');
      expect(TripDetailTabs.kTabs[3].label, '锦囊');
      expect(TripDetailTabs.kTabs[0].icon, AppIcons.clock);
    });

    test('锁屏抖动触发已接线（S2 收尾回归）', () {
      final src = File('lib/features/lock/lock_screen.dart').readAsStringSync();
      expect(src.contains('_shake.forward(from: 0)'), isTrue);
      expect(src.contains('sin(t * pi * 4) * 6 * (1 - t)'), isTrue,
          reason: '±6 衰减抖动公式保持');
    });

    test('fenToYuan 千分位口径回归（金额展示统一出口）', () {
      expect(MoneyFormat.fenToYuan(128050), contains('1,280.50'));
      expect(MoneyFormat.fenToYuan(5), '0.05');
    });
  });
}
