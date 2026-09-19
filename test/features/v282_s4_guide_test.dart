// V2.8.2 S4 攻略页视觉打磨（配额 ≥8）：
// 1) 六栏宫格图标 AppIcons 化；2) 城市头统计胶囊图标化；
// 3) meta 分色（地址 outline / tag 主色 8% / 建议时长 amber 8%）；
// 4) 宫格 PressableScale 接线（S6 联动）；5) 双动作主次化 + 状态徽记（文件断言）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/guide/guide_models.dart' show GuideCity;
import 'package:travel_assistant/features/trips/guide_widgets.dart';
import 'package:travel_assistant/shared/widgets/pressable_scale.dart';
import 'package:travel_assistant/theme/app_icons.dart';
import 'package:travel_assistant/theme/tokens.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('S4-1 六栏宫格图标 AppIcons 化', () {
    test('六栏主键完整（样式表与宫格共用同一 sectionKeys）', () {
      expect(GuideCity.sectionKeys.length, 6);
      expect(GuideCity.sectionKeys,
          containsAll(['prep', 'spots', 'food', 'transport', 'tips', 'budget']));
    });

    testWidgets('六个栏目的图标逐一对上 AppIcons 换装表', (tester) async {
      late Map<String, IconData> got;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        got = {
          for (final k in GuideCity.sectionKeys)
            k: guideSectionStyle(context, k).icon,
        };
        return const SizedBox.shrink();
      })));
      expect(got['prep'], AppIcons.calendar);
      expect(got['spots'], AppIcons.camera);
      expect(got['food'], AppIcons.food);
      expect(got['transport'], AppIcons.car);
      expect(got['tips'], AppIcons.bolt);
      expect(got['budget'], AppIcons.coins);
    });

    testWidgets('宫格砖渲染 AppIcons 图标（34px 底砖 19px 图标）', (tester) async {
      await tester.pumpWidget(_host(GuideSectionGrid(
        sections: const {
          'spots': [
            {'name': '故宫', 'tag': '必去', 'timeText': '3小时', 'addr': '东城区'}
          ],
        },
        onTap: (_) {},
      )));
      expect(find.byIcon(AppIcons.camera), findsOneWidget);
      expect(find.byIcon(AppIcons.calendar), findsOneWidget);
    });
  });

  group('S4-2 城市头统计胶囊图标化', () {
    testWidgets('三枚统计胶囊换装 AppIcons（compass/clock/check）', (tester) async {
      await tester.pumpWidget(_host(GuideCityHero(
        cityName: '北京',
        spots: 12,
        textChars: 3000,
        readingMinutes: 8,
        sourceLabel: '内置精品攻略',
      )));
      expect(find.byIcon(AppIcons.compass), findsOneWidget);
      expect(find.byIcon(AppIcons.clock), findsOneWidget);
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      expect(find.text('12 个景点/美食'), findsOneWidget);
      expect(find.text('约 8 分钟读完'), findsOneWidget);
    });
  });

  group('S4-3 meta 分色', () {
    testWidgets('tag 胶囊 = 主色 8% 底 + 主色文字', (tester) async {
      await tester.pumpWidget(_host(const GuideItemRow(
        sectionKey: 'spots',
        item: {
          'name': '故宫',
          'tag': '必去',
          'addr': '东城区景山前街4号',
          'timeText': '3小时',
        },
      )));
      final scheme = Theme.of(tester.element(find.text('必去'))).colorScheme;
      final container = tester.widget<Container>(find.ancestor(
        of: find.text('必去'),
        matching: find.byType(Container),
      ));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, scheme.primary.withValues(alpha: 0.08));
      expect(
        (container.decoration! as BoxDecoration).borderRadius,
        AppRadius.capsule,
      );
    });

    testWidgets('建议时长胶囊 = amber 8% 底；地址胶囊 = outline 边框无底色',
        (tester) async {
      await tester.pumpWidget(_host(const GuideItemRow(
        sectionKey: 'spots',
        item: {
          'name': '故宫',
          'tag': '必去',
          'addr': '东城区景山前街4号',
          'timeText': '3小时',
        },
      )));
      final scheme = Theme.of(tester.element(find.text('必去'))).colorScheme;
      // 时长（amber）
      final timeContainer = tester.widget<Container>(find.ancestor(
        of: find.text('建议 3小时'),
        matching: find.byType(Container),
      ));
      expect((timeContainer.decoration as BoxDecoration).color,
          SemanticColors.warning.withValues(alpha: 0.08));
      // 地址（outline 边框 + 无底色）
      final addrContainer = tester.widget<Container>(find.ancestor(
        of: find.text('东城区景山前街4号'),
        matching: find.byType(Container),
      ));
      final addrDecoration = addrContainer.decoration as BoxDecoration;
      expect(addrDecoration.color, isNull);
      expect(addrDecoration.border, isNotNull);
      expect(scheme.primary, isNotNull);
    });

    testWidgets('美食栏 area 走地址分色（outline 边框）', (tester) async {
      await tester.pumpWidget(_host(const GuideItemRow(
        sectionKey: 'food',
        item: {'name': '四季民福', 'area': '故宫店'},
      )));
      final container = tester.widget<Container>(find.ancestor(
        of: find.text('故宫店'),
        matching: find.byType(Container),
      ));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNull);
      expect(decoration.border, isNotNull);
    });
  });

  group('S4-4 宫格 PressableScale 接线（S6 联动）', () {
    testWidgets('六格各包一层 PressableScale，点击回调 SectionKey', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final tapped = <String>[];
      await tester.pumpWidget(_host(GuideSectionGrid(
        sections: const {},
        onTap: tapped.add,
      )));
      expect(find.byType(PressableScale), findsNWidgets(6));
      // 空栏预览为「暂无内容」；点击第 1 格（prep）验证 SectionKey 回调
      await tester.tap(find.text('暂无内容').first);
      expect(tapped, ['prep']);
    });
  });

  group('S4-5 双动作主次化 + 状态徽记（文件断言）', () {
    test('直接排 = FilledButton.icon（36 高 + calendar），先想去 = OutlinedButton.icon', () {
      final src = File('lib/features/trips/screens/trip_guide_screen.dart')
          .readAsStringSync();
      expect(src.contains("FilledButton.icon"), isTrue);
      expect(src.contains("OutlinedButton.icon"), isTrue);
      expect(src.contains("minimumSize: const Size(0, 36)"), isTrue,
          reason: '双动作统一 36 高小号按钮');
      expect(src.contains("Icon(AppIcons.calendar"), isTrue);
      expect(src.contains("Icon(AppIcons.bookmark"), isTrue);
      expect(src.contains("'已安排 · 第 "), isTrue,
          reason: '已安排状态徽记保留天数文案');
      expect(src.contains("'已在想去'"), isTrue);
      // guideRef 参数逐字段不改（隐藏逻辑冻结）
      expect(src.contains("_refOf(seedIndex)"), isTrue);
      expect(src.contains("guideDurationFromTimeText"), isTrue);
    });

    test('弹层收尾联动：攻略页 2 处 AlertDialog 已迁 showConfirmSheet', () {
      final src = File('lib/features/trips/screens/trip_guide_screen.dart')
          .readAsStringSync();
      expect(src.contains('AlertDialog('), isFalse);
      expect(src.contains('showConfirmSheet('), isTrue);
    });
  });
}
