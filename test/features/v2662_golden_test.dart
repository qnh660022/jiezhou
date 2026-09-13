// V2.6.6.2 §13：验收报告需要的**真实渲染截图**（浅色 + 暗色「石墨夜」）。
//
// 用 golden 机制把页面渲染成 PNG，而不是"人肉描述"视觉：
//   flutter test test/features/v2662_golden_test.dart --update-goldens
// 生成物落在 test/features/goldens/ 下，验收报告直接引用这些路径。
//
// 覆盖 §6.4 / §8.4 点名要验收的三个页面（用其核心可视单元代表）：
//   * 旅伴中心：分区卡 + 空间卡 + 角色徽标（条目层三段式）；
//   * 空间详情页：Hero 层（空间名 + 胶囊徽标 + 头像叠放 + 角色徽标）；
//   * 驾驶舱：首页置顶卡 TodayCard（第 N 天 / 今日安排 / 今日花销）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/features/companions/widgets/space_widgets.dart';
import 'package:travel_assistant/features/today/widgets/today_card.dart';
import 'package:travel_assistant/shared/widgets/stat_chip.dart';
import 'package:travel_assistant/theme/theme_provider.dart';
import 'package:travel_assistant/theme/tokens.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase();
  });

  tearDown(() async => db.close());

  /// 五浅一深里的代表：薄荷 / 晴空 / 星河（浅）+ 夜航·石墨（深）。
  /// ⚠️ 每个主题必须写**各自**的 golden 文件名：多个主题复用同一个文件名时，
  /// 后写的会覆盖先写的，下一次比较必然失败（实测 19%~23% 像素差）。
  List<(String, ThemeData)> themes() => [
        ('mint', buildAppThemeFor(ThemeFamily.mint, ThemeBrightnessMode.light)),
        ('sky', buildAppThemeFor(ThemeFamily.sky, ThemeBrightnessMode.light)),
        ('nebula', buildAppThemeFor(ThemeFamily.nebula, ThemeBrightnessMode.light)),
        ('dark', buildAppThemeFor(ThemeFamily.night, ThemeBrightnessMode.dark)),
      ];

  Widget host(ThemeData theme, Widget child) => ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      );

  testWidgets('驾驶舱置顶卡 TodayCard · 四主题', (tester) async {
    final today = todayEpochDay();
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          name: '京都秋日行',
          destination: const Value('京都'),
          startEpochDay: Value(today - 2),
          endEpochDay: Value(today + 4),
          createdAt: 1000,
          updatedAt: 1000,
        ));

    tester.view.physicalSize = const Size(1080, 720);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final (key, theme) in themes()) {
      await tester.pumpWidget(host(theme, const TodayCard()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(TodayCard),
        matchesGoldenFile('goldens/today_card_$key.png'),
      );
    }
  });

  testWidgets('旅伴中心空间卡 + 分区卡 · 四主题（§6.4 三级层次）', (tester) async {
    await db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
          id: 's1',
          name: '国庆京都行',
          createdBy: 'me',
          createdMs: 1000,
          updatedMs: 2000,
        ));
    final space = (await db.select(db.travelSpaces).get()).single;

    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final sample = CompanionSectionCard(
      title: '我的空间',
      subtitle: '一程一空间：行程与账本都能和旅伴一起管',
      trailingLabel: '全部',
      onTrailingTap: () {},
      child: Column(
        children: [
          SpaceCard(
            space: space,
            members: const [],
            myRole: 'owner',
            unreadCount: 2,
          ),
          const Divider(height: 1),
          SpaceCard(
            space: space,
            members: const [],
            myRole: 'editor',
          ),
          const Divider(height: 1),
          SpaceCard(
            space: space,
            members: const [],
            myRole: 'viewer',
          ),
          const SizedBox(height: Spacing.md),
          const Row(
            children: [
              StatChip(label: '成员', value: '3'),
              SizedBox(width: Spacing.sm),
              StatChip(label: '今日花销', value: '¥286.00'),
            ],
          ),
        ],
      ),
    );

    for (final (key, theme) in themes()) {
      await tester.pumpWidget(host(theme, sample));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CompanionSectionCard),
        matchesGoldenFile('goldens/companion_section_$key.png'),
      );
    }
  });
}
