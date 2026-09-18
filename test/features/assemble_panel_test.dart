// V2.7.2 S7：装配台面板 Widget 用例（容量条 / 点击落点 / 补时长 / 备胎口径）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/repo/wishlist_repo.dart';
import 'package:travel_assistant/features/trips/widgets/assemble_panel.dart';

Future<({AppDatabase db, TripsRepository trips, WishlistRepository wishes})>
    _setup() async {
  SharedPreferences.setMockInitialValues({});
  final db = AppDatabase();
  final trips = TripsRepository(db);
  final wishes = WishlistRepository(db);
  await db.into(db.trips).insert(TripsCompanion.insert(
        id: 't1',
        name: '行',
        startEpochDay: const Value(100),
        endEpochDay: const Value(102),
        createdAt: 1000,
        updatedAt: 1000,
      ));
  return (db: db, trips: trips, wishes: wishes);
}

Widget _host(AppDatabase db, {bool canEdit = true}) {
  return ProviderScope(
    overrides: [dbProvider.overrideWithValue(db)],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 800,
          width: 900,
          child: AssemblePanel(tripId: 't1', canEdit: canEdit),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('1. 容量条与天数选择渲染（空天 0 h / 容量 8 h）', (tester) async {
    final env = await _setup();
    addTearDown(env.db.close);
    await tester.pumpWidget(_host(env.db));
    await tester.pumpAndSettle();
    expect(find.text('已排 0 h / 容量 8 h'), findsOneWidget);
    expect(find.text('第 1 天'), findsOneWidget);
    expect(find.text('第 3 天'), findsOneWidget);
  });

  testWidgets('2. 点击候选自动落点：建卡 startTimeMin=420 + 删池行', (tester) async {
    final env = await _setup();
    addTearDown(env.db.close);
    final wid = await env.wishes.addItem(
        tripId: 't1', name: '西湖', durationMin: 60);
    await tester.pumpWidget(_host(env.db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('西湖'));
    await tester.pumpAndSettle();
    final cards = await env.trips.getItems('t1');
    expect(cards, hasLength(1));
    expect(cards.first.name, '西湖');
    expect(cards.first.startTimeMin, 420, reason: '空天 attraction 首点 07:00');
    expect(cards.first.dateEpochDay, 100);
    expect(await env.wishes.getByTrip('t1'), isEmpty, reason: '落卡即移出');
    expect(find.textContaining('已排入'), findsOneWidget, reason: '落点 toast');
    expect(find.text('撤销'), findsOneWidget);
    expect(wid, isNotEmpty);
  });

  testWidgets('3. 未估时候选：补时长弹层 → 落点', (tester) async {
    final env = await _setup();
    addTearDown(env.db.close);
    await env.wishes.addItem(tripId: 't1', name: '灵隐寺');
    await tester.pumpWidget(_host(env.db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('灵隐寺'));
    await tester.pumpAndSettle();
    expect(find.text('预估停留时长'), findsOneWidget);
    await tester.tap(find.text('2 小时'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    final cards = await env.trips.getItems('t1');
    expect(cards, hasLength(1));
    expect(cards.first.durationMin, 120);
    expect(cards.first.startTimeMin, 420);
  });

  testWidgets('4. 单步撤销：删卡 + 池行恢复（id 不变）', (tester) async {
    final env = await _setup();
    addTearDown(env.db.close);
    final wid = await env.wishes.addItem(
        tripId: 't1', name: '可撤销', durationMin: 60);
    await tester.pumpWidget(_host(env.db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('可撤销'));
    await tester.pumpAndSettle();
    expect(await env.trips.getItems('t1'), hasLength(1));
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(await env.trips.getItems('t1'), isEmpty);
    final restored = await env.wishes.getItem(wid);
    expect(restored, isNotNull, reason: '恢复池行且 id 不变');
    expect(restored!.name, '可撤销');
  });

  testWidgets('5. 容量超限警示色文案（已排 > 容量）', (tester) async {
    final env = await _setup();
    addTearDown(env.db.close);
    final now = DateTime.now().millisecondsSinceEpoch;
    await env.db.into(env.db.tripItems).insert(TripItemsCompanion.insert(
          id: 'big',
          tripId: 't1',
          dateEpochDay: const Value(100),
          startTimeMin: const Value(420),
          durationMin: const Value(700),
          createdAt: now,
          updatedAt: now,
        ));
    await tester.pumpWidget(_host(env.db));
    await tester.pumpAndSettle();
    expect(find.text('已排 11.7 h / 容量 8 h（已超）'), findsOneWidget);
  });

  testWidgets('6. 备胎不计容量、不进当天缩略', (tester) async {
    final env = await _setup();
    addTearDown(env.db.close);
    final now = DateTime.now().millisecondsSinceEpoch;
    await env.db.into(env.db.tripItems).insert(TripItemsCompanion.insert(
          id: 'bk',
          tripId: 't1',
          dateEpochDay: const Value(100),
          startTimeMin: const Value(420),
          durationMin: const Value(480),
          backupOf: const Value(''),
          createdAt: now,
          updatedAt: now,
        ));
    await tester.pumpWidget(_host(env.db));
    await tester.pumpAndSettle();
    expect(find.text('已排 0 h / 容量 8 h'), findsOneWidget,
        reason: '备胎不参与容量口径');
    expect(find.text('bk'), findsNothing, reason: '备胎不出现在当天缩略');
  });

  testWidgets('7. viewer 只读：候选不可点（无落点发生）', (tester) async {
    final env = await _setup();
    addTearDown(env.db.close);
    await env.wishes.addItem(tripId: 't1', name: '只读候选', durationMin: 60);
    await tester.pumpWidget(_host(env.db, canEdit: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('只读候选'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await env.trips.getItems('t1'), isEmpty);
  });
}
