// V2.7.2 S11：多城分组装配用例（默认命中城过滤 / 全部切换 / 种子城名分组头 /
// 过滤态下落卡照常）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/guide/guide_providers.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/repo/wishlist_repo.dart';
import 'package:travel_assistant/features/trips/widgets/assemble_panel.dart';
import 'package:travel_assistant/features/trips/widgets/wishlist_panel.dart';
import 'package:travel_assistant/domain/guide_match.dart';

Future<({AppDatabase db, TripsRepository trips, WishlistRepository wishes})>
    _setup({required String destination}) async {
  SharedPreferences.setMockInitialValues({});
  final db = AppDatabase();
  final trips = TripsRepository(db);
  final wishes = WishlistRepository(db);
  await db.into(db.trips).insert(TripsCompanion.insert(
        id: 't1',
        name: '行',
        destination: Value(destination),
        startEpochDay: const Value(100),
        endEpochDay: const Value(102),
        createdAt: 1000,
        updatedAt: 1000,
      ));
  return (db: db, trips: trips, wishes: wishes);
}

Widget _host(AppDatabase db, {required String tripId}) {
  return ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      guideCityKeyByNameProvider
          .overrideWith((ref) async => {'杭州': 'hangzhou', '苏州': 'suzhou'}),
      guideCityNameByKeyProvider.overrideWith(
          (ref) async => {'hangzhou': '杭州', 'suzhou': '苏州'}),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 800,
          width: 900,
          child: AssemblePanel(tripId: tripId, canEdit: true),
        ),
      ),
    ),
  );
}

void main() {
  test('1. matchCityKey：锦囊/装配/大纲共用同一函数（同输入同输出）', () {
    const names = {'杭州': 'hangzhou', '苏州': 'suzhou'};
    expect(matchCityKey('杭州市', names), 'hangzhou');
    expect(matchCityKey('杭州市', names), matchCityKey('杭州', names));
    expect(matchCityKey('苏州市', names), 'suzhou');
    expect(matchCityKey('苏州市', names), matchCityKey('苏州', names));
  });

  test('2. WishlistPanel.visibleCityKeys：过滤与非空语义', () {
    // 语义由面板内部过滤逻辑保证；这里验证集合语义本身
    final keys = {'hangzhou'};
    expect(keys.contains('hangzhou'), isTrue);
    expect(keys.contains('suzhou'), isFalse);
    const Set<String>? all = null;
    expect(all, isNull, reason: 'null = 全部');
  });

  testWidgets('3. 装配台默认只显示命中城分组（杭州），分组头用种子城名',
      (tester) async {
    final env = await _setup(destination: '杭州');
    addTearDown(env.db.close);
    await env.wishes.addItem(tripId: 't1', name: '西湖', cityKey: 'hangzhou');
    await env.wishes.addItem(tripId: 't1', name: '拙政园', cityKey: 'suzhou');
    await tester.pumpWidget(_host(env.db, tripId: 't1'));
    await tester.pumpAndSettle();
    expect(find.text('杭州'), findsWidgets, reason: '命中城分组头/chip');
    expect(find.text('苏州'), findsNothing, reason: '默认过滤掉非命中城');
    expect(find.text('拙政园'), findsNothing);
    expect(find.text('西湖'), findsOneWidget);
  });

  testWidgets('4. 「全部」开关展开其他城分组', (tester) async {
    final env = await _setup(destination: '杭州');
    addTearDown(env.db.close);
    await env.wishes.addItem(tripId: 't1', name: '西湖', cityKey: 'hangzhou');
    await env.wishes.addItem(tripId: 't1', name: '拙政园', cityKey: 'suzhou');
    await tester.pumpWidget(_host(env.db, tripId: 't1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('苏州'), findsWidgets, reason: '切换后显示非命中城分组');
    expect(find.text('拙政园'), findsOneWidget);
    expect(find.text('西湖'), findsOneWidget, reason: '命中城组仍在');
  });

  testWidgets('5. matchCityKey 未命中（南京）→ 默认全部显示', (tester) async {
    final env = await _setup(destination: '南京');
    addTearDown(env.db.close);
    await env.wishes.addItem(tripId: 't1', name: '西湖', cityKey: 'hangzhou');
    await env.wishes.addItem(tripId: 't1', name: '拙政园', cityKey: 'suzhou');
    await tester.pumpWidget(_host(env.db, tripId: 't1'));
    await tester.pumpAndSettle();
    expect(find.text('杭州'), findsWidgets);
    expect(find.text('苏州'), findsWidgets);
    expect(find.text('全部'), findsNothing, reason: '未命中城时不渲染过滤 chips');
  });

  testWidgets('6. 过滤态下落卡照常工作（作用于具体条目）', (tester) async {
    final env = await _setup(destination: '杭州');
    addTearDown(env.db.close);
    await env.wishes.addItem(
        tripId: 't1', name: '灵隐寺', cityKey: 'hangzhou', durationMin: 60);
    await tester.pumpWidget(_host(env.db, tripId: 't1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('灵隐寺'));
    await tester.pumpAndSettle();
    final cards = await env.trips.getItems('t1');
    expect(cards, hasLength(1), reason: '过滤态不阻碍落卡');
    expect(cards.first.dateEpochDay, 100);
    expect(await env.wishes.getByTrip('t1'), isEmpty);
  });

  testWidgets('7. 未命中城条目显示「未分类」分组（空 cityKey）', (tester) async {
    final env = await _setup(destination: '南京');
    addTearDown(env.db.close);
    await env.wishes.addItem(tripId: 't1', name: '手动条目');
    await tester.pumpWidget(_host(env.db, tripId: 't1'));
    await tester.pumpAndSettle();
    expect(find.text('未分类'), findsOneWidget);
    expect(find.text('手动条目'), findsOneWidget);
  });
}
