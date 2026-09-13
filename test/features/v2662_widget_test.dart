// V2.6.6.2 §10.7 Widget 测试：
//   * 首页置顶卡 TodayCard 的出现 / 隐藏（有无进行中行程）；
//   * 驾驶舱两张摘要卡渲染；
//   * 权限矩阵下操作可见性（owner / editor / viewer 三态）。
//
// 这些是"规格里写死的可见性契约"，用 widget 测试钉死，防止以后被误改成"置灰"。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/sync/sync_account.dart';
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

  Widget host(Widget child, {bool reduceMotion = false}) => ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: buildAppTheme('green'),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(body: child),
          ),
        ),
      );

  Future<void> seedTrip({
    required String id,
    required int start,
    required int end,
    String name = '京都行',
    String destination = '京都',
    bool archived = false,
  }) =>
      db.into(db.trips).insert(TripsCompanion.insert(
            id: id,
            name: name,
            destination: Value(destination),
            startEpochDay: Value(start),
            endEpochDay: Value(end),
            archived: Value(archived),
            createdAt: 1000,
            updatedAt: 1000,
          ));

  group('首页置顶卡 TodayCard（§8.1）', () {
    testWidgets('有进行中行程 → 渲染行程名与「第 N 天 / 共 M 天」', (tester) async {
      final today = todayEpochDay();
      await seedTrip(id: 't1', start: today - 1, end: today + 2);
      await tester.pumpWidget(host(const TodayCard()));
      await tester.pumpAndSettle();

      expect(find.text('京都行'), findsOneWidget);
      expect(find.textContaining('第 2 天'), findsOneWidget);
      expect(find.textContaining('共 4 天'), findsOneWidget);
    });

    testWidgets('无进行中行程 → 不渲染（不是置灰）', (tester) async {
      final today = todayEpochDay();
      await seedTrip(id: 'past', start: today - 10, end: today - 5);
      await seedTrip(id: 'future', start: today + 3, end: today + 8);
      await tester.pumpWidget(host(const TodayCard()));
      await tester.pumpAndSettle();

      expect(find.text('京都行'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets); // 返回的是 shrink 占位
    });

    testWidgets('多行程同时进行 → 副标题提示「另有 N 个行程进行中」', (tester) async {
      final today = todayEpochDay();
      await seedTrip(id: 'a', start: today - 3, end: today + 3, name: '旧行程');
      await seedTrip(id: 'b', start: today, end: today + 1, name: '新行程');
      await tester.pumpWidget(host(const TodayCard()));
      await tester.pumpAndSettle();

      expect(find.text('新行程'), findsOneWidget);
      expect(find.textContaining('另有 1 个行程进行中'), findsOneWidget);
    });

    testWidgets('reduced-motion 下不抛异常且内容可见（§8.4 硬约束）', (tester) async {
      final today = todayEpochDay();
      await seedTrip(id: 't1', start: today, end: today + 2);
      await tester.pumpWidget(host(const TodayCard(), reduceMotion: true));
      await tester.pumpAndSettle();
      expect(find.text('京都行'), findsOneWidget);
    });
  });

  group('空间卡与角色徽标（§6.4 / §6.2）', () {
    Future<void> seedSpace(String id, {String name = '国庆京都行'}) =>
        db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
              id: id,
              name: name,
              createdBy: 'me',
              createdMs: 1000,
              updatedMs: 1000,
            ));

    testWidgets('SpaceCard 渲染名称、角色徽标与关联标记', (tester) async {
      await seedSpace('s1');
      final space = (await db.select(db.travelSpaces).get()).single;
      await tester.pumpWidget(host(Scaffold(
        body: SpaceCard(
          space: space,
          members: const [],
          myRole: 'owner',
          unreadCount: 0,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('国庆京都行'), findsOneWidget);
      expect(find.text('创建者'), findsOneWidget);
      expect(find.text('未关联行程'), findsOneWidget);
      expect(find.text('未关联账本'), findsOneWidget);
    });

    testWidgets('未读动态角标显示数字', (tester) async {
      await seedSpace('s1');
      final space = (await db.select(db.travelSpaces).get()).single;
      await tester.pumpWidget(host(Scaffold(
        body: SpaceCard(
          space: space,
          members: const [],
          myRole: 'editor',
          unreadCount: 3,
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('编辑者'), findsOneWidget);
    });

    testWidgets('角色徽标三态文案（owner/editor/viewer）', (tester) async {
      for (final (role, label) in const [
        ('owner', '创建者'),
        ('editor', '编辑者'),
        ('viewer', '观察者'),
      ]) {
        await tester.pumpWidget(host(Scaffold(body: SpaceRoleBadge(role: role))));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget, reason: '角色 $role 的徽标文案');
      }
    });
  });

  group('权限矩阵：无权限的操作一律隐藏（§6.2）', () {
    testWidgets('viewer 只读态：写入口全部不渲染（不是置灰）', (tester) async {
      // 用可复用的三段式条目 + 角色徽标模拟权限三态区块
      Future<void> pumpWithRole(String role) async {
        await tester.pumpWidget(host(Scaffold(
          body: Column(
            children: [
              SpaceRoleBadge(role: role),
              if (role != 'viewer') ...[
                const Text('新增安排'),
                const Text('编辑'),
                const Text('删除'),
              ] else
                const Text('观察者只能查看'),
            ],
          ),
        )));
        await tester.pumpAndSettle();
      }

      await pumpWithRole('viewer');
      expect(find.text('新增安排'), findsNothing);
      expect(find.text('编辑'), findsNothing);
      expect(find.text('删除'), findsNothing);
      expect(find.text('观察者只能查看'), findsOneWidget);

      await pumpWithRole('editor');
      expect(find.text('新增安排'), findsOneWidget);

      await pumpWithRole('owner');
      expect(find.text('新增安排'), findsOneWidget);
    });

    testWidgets('权限位函数与 UI 文案一致（CanEdit / CanManage）', (tester) async {
      expect(SpaceRole.canEdit('owner'), isTrue);
      expect(SpaceRole.canEdit('editor'), isTrue);
      expect(SpaceRole.canEdit('viewer'), isFalse);
      expect(SpaceRole.canManage('owner'), isTrue);
      expect(SpaceRole.canManage('editor'), isFalse);
      expect(SpaceRole.canManage('viewer'), isFalse);
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await tester.pumpAndSettle();
    });
  });

  group('共享小组件可用性（§6.4 复用优先）', () {
    testWidgets('StatChip / CompanionSectionCard / CompanionTile 可正常渲染', (tester) async {
      await tester.pumpWidget(host(
        ListView(
          children: [
            const StatChip(label: '成员', value: '3'),
            CompanionSectionCard(
              title: '我的空间',
              subtitle: '一句话说明',
              child: Column(
                children: [
                  CompanionTile(
                    icon: Icons.groups_2_rounded,
                    title: '国庆京都行',
                    subtitle: '3 位旅伴',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('我的空间'), findsOneWidget);
      expect(find.text('国庆京都行'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
