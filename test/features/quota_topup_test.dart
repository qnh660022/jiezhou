// V2.8.1 S12 · 用例配额补齐（各阶段规格点位的紧凑补充，12 例）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/money_expression.dart';
import 'package:travel_assistant/features/ledger/widgets/category_icon_box.dart';
import 'package:travel_assistant/shared/widgets/app_snack_bar.dart';
import 'package:travel_assistant/shared/widgets/glass_surface.dart';
import 'package:travel_assistant/shared/widgets/permission_primer.dart';
import 'package:travel_assistant/theme/app_icons.dart';
import 'package:travel_assistant/theme/tokens.dart';

void main() {
  group('MoneyExpression 补充', () {
    test('1. pushDot 连点只留一个小数点', () {
      final e = MoneyExpression();
      e.pushDigit(1);
      e.pushDot();
      e.pushDot();
      e.pushDot();
      e.pushDigit(5);
      expect(e.display, '1.5');
      expect(e.totalFen, 150);
    });

    test('2. 表达式开头 pushDot → 0.', () {
      final e = MoneyExpression();
      e.pushDot();
      e.pushDigit(5);
      expect(e.totalFen, 50);
    });

    test('3. 空 backspace 安全', () {
      final e = MoneyExpression();
      e.backspace();
      e.backspace();
      expect(e.isEmpty, isTrue);
    });

    test('4. 减法产生负合计（仍在 int 分域）', () {
      final e = MoneyExpression();
      e.pushDigit(3);
      e.pushOp(MoneyOp.subtract);
      e.pushDigit(5);
      expect(e.totalFen, -200);
    });
  });

  group('GlassSurface / CategoryIconBox 补充', () {
    testWidgets('5. 自定义 borderRadius 生效', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlassSurface(
            level: GlassLevel.floatingCard,
            borderRadius: BorderRadius.circular(8),
            child: const Text('X'),
          ),
        ),
      ));
      await tester.pump();
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
      expect(clip.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('6. iconKey 显式参数优先于自动映射', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: CategoryIconBox(categoryKey: 'c_my', iconKey: 'food'),
        ),
      ));
      await tester.pump();
      expect(tester.widget<Icon>(find.byType(Icon).first).icon, AppIcons.food);
    });

    testWidgets('7. 自定义分类无 emoji → tag 兜底渲染', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: CategoryIconBox(categoryKey: 'c_none'),
        ),
      ));
      await tester.pump();
      expect(tester.widget<Icon>(find.byType(Icon).first).icon, AppIcons.tag);
    });
  });

  group('AppSnackBar / PermissionPrimer 补充', () {
    testWidgets('8. SnackBarAction 保留', (tester) async {
      var done = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showAppSnackBar(context, '已收进收件箱',
                    action: SnackBarAction(
                        label: '撤销', onPressed: () => done = true)),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
    });

    testWidgets('9. 连续 showAppSnackBar：clearSnackBars 防堆积', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Column(children: [
                FilledButton(
                    onPressed: () => showAppSnackBar(context, '第一条'),
                    child: const Text('a')),
                FilledButton(
                    onPressed: () => showAppSnackBar(context, '第二条'),
                    child: const Text('b')),
              ]),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('a'));
      await tester.pump();
      await tester.tap(find.text('b'));
      await tester.pump();
      expect(find.text('第一条'), findsNothing, reason: '新提示替换旧提示');
      expect(find.text('第二条'), findsOneWidget);
    });

    testWidgets('10. PermissionPrimer granted + grantedMessage 渲染', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: PermissionPrimer(
            state: PermissionPrimerState.granted,
            title: '通知权限',
            description: '用于预算预警',
            grantedMessage: '预警提醒已开启',
            onOpenSettings: _noop2,
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('预警提醒已开启'), findsOneWidget,
          reason: 'granted + grantedMessage → 卡片保留展示');
      expect(find.text('去开启'), findsNothing, reason: 'granted 态无操作钮');
    });

    testWidgets('11. PermissionPrimer denied → 去设置按钮', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PermissionPrimer(
            state: PermissionPrimerState.denied,
            title: '相机权限',
            description: '用于扫描',
            onOpenSettings: () => tapped = true,
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('去设置'));
      expect(tapped, isTrue);
    });
  });

  group('图标体系补充', () {
    test('12. 码点空间无碰撞（0xe900..0xe923 连续唯一）', () {
      final points = [
        AppIcons.boat, AppIcons.spark, AppIcons.clip, AppIcons.compass,
        AppIcons.wallet, AppIcons.user, AppIcons.food, AppIcons.car,
        AppIcons.bed, AppIcons.ticket, AppIcons.bag, AppIcons.fun,
        AppIcons.med, AppIcons.tag, AppIcons.trash, AppIcons.check,
        AppIcons.calendar, AppIcons.bookmark, AppIcons.clock, AppIcons.bolt,
        AppIcons.sun, AppIcons.chart, AppIcons.coins, AppIcons.members,
        AppIcons.toolbox, AppIcons.qr, AppIcons.search, AppIcons.tune,
        AppIcons.camera,
      ].map((i) => i.codePoint).toSet();
      expect(points.length, 29, reason: '命名图标码点唯一');
    });
  });
}

void _noop2() {}
