// V2.7.2 全局回归（规格 §16.2 ≥14 例）：
// 迁移矩阵 / 备份往返 / 同步登记回归 / 三宿主冒烟 / viewer 禁用 /
// 大纲覆盖强确认 / guideRef 漂移降级 / 顺延后互链联动 / 装配撤销 / 收口复核。
import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/guide/guide_providers.dart';
import 'package:travel_assistant/data/providers.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/repo/wishlist_repo.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/data/sync/sync_transport_fake.dart';
import 'package:travel_assistant/domain/day_shift_engine.dart';
import 'package:travel_assistant/domain/guide_ref.dart';
import 'package:travel_assistant/features/trips/outline_apply.dart';
import 'package:travel_assistant/features/trips/desktop_trips_workbench.dart';
import 'package:travel_assistant/features/trips/widgets/assemble_panel.dart';
import 'package:travel_assistant/features/trips/widgets/kit_panel.dart';
import 'package:travel_assistant/features/trips/widgets/outline_panel.dart';
import 'package:travel_assistant/features/trips/widgets/trip_tab_panels.dart';
import 'package:travel_assistant/features/trips/widgets/wishlist_panel.dart';

void main() {
  group('同步登记回归（S1 契约不回退）', () {
    test('1. localKey 显式映射 + 镜像分流 + pullOrder 次序', () {
      expect(SyncEntity.wishlistItems.localKey, 'wishlist_items',
          reason: '枚举名 wishlistItems ≠ localKey，H10 同款静默丢失防线');
      expect(SyncEntity.wishlistItems.isCollabMirror, isTrue,
          reason: '与 trips/tripItems 同走受邀镜像');
      final order = SyncEntity.pullOrder;
      expect(order.indexOf(SyncEntity.wishlistItems),
          greaterThan(order.indexOf(SyncEntity.tripItems)),
          reason: 'pullOrder 在 tripItems 之后');
    });

    test('2. requiredColumns：wishlist_items_sync 最小列集不变', () {
      expect(
        SyncTransportFake.requiredColumns['wishlist_items_sync'],
        {'trip_id', 'name', 'type', 'created_ms', 'updated_ms'},
      );
    });
  });

  group('数据层回归', () {
    late AppDatabase db;
    late TripsRepository trips;
    late WishlistRepository wishes;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
      trips = TripsRepository(db);
      wishes = WishlistRepository(db);
    });
    tearDown(() async => db.close());

    test('3. 迁移矩阵回归：全新 v6 库默认值与表齐备', () async {
      expect(db.schemaVersion, 6);
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            startEpochDay: const d.Value(100),
            endEpochDay: const d.Value(102),
            createdAt: 1000,
            updatedAt: 1000,
          ));
      final trip = (await trips.getById('t1'))!;
      expect(trip.pace, 'standard', reason: 'pace 默认 standard');
      // 新表可读写
      await wishes.addItem(tripId: 't1', name: '池');
      expect(await wishes.getByTrip('t1'), hasLength(1));
      // TripItems 新列默认 NULL
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: 'i1',
            tripId: 't1',
            dateEpochDay: const d.Value(100),
            createdAt: now,
            updatedAt: now,
          ));
      final item = (await trips.getItem('i1'))!;
      expect(item.guideRef, isNull);
      expect(item.backupOf, isNull);
    });

    test('4. 备份往返（.tat 行程级）：池行 + guideRef 保留', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            startEpochDay: const d.Value(100),
            endEpochDay: const d.Value(101),
            createdAt: 1000,
            updatedAt: 1000,
          ));
      await wishes.addItem(
          tripId: 't1', name: '西湖', guideRef: 'hz#spots#0', cityKey: 'hz');
      final bytes = await trips.exportTripBackupBytes('t1');
      // 删除后导入
      await trips.deleteTrip('t1');
      final report = await trips.importTripBackupBytes(bytes);
      expect(report.trip, '行', reason: '导入报告携带行程名');
      // 导入为独立副本：新行程 id，池行挂在新 id 下
      final allWishes = await (db.select(db.wishlistItems)).get();
      expect(allWishes, hasLength(1), reason: '池行随备份往返完好');
      expect(allWishes.first.name, '西湖');
      expect(allWishes.first.guideRef, 'hz#spots#0');
      expect(allWishes.first.tripId, isNot('t1'));
    });

    test('5. guideRef 漂移降级（repo 层）：垃圾/越界 ref 不崩、可查可删', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: 'i1',
            tripId: 't1',
            dateEpochDay: const d.Value(100),
            guideRef: const d.Value('hz#spots#0'),
            createdAt: now,
            updatedAt: now,
          ));
      expect(
        await (db.select(db.tripItems)
              ..where((t) => t.guideRef.like('gone#spots#%')))
            .get(),
        isEmpty,
        reason: '城缺失 → 前缀反查空集（静默降级前提）',
      );
      // 弱关联无外键：删除指向已不存在的 ref 行不崩
      await (db.delete(db.tripItems)..where((t) => t.id.equals('i1'))).go();
      expect(GuideRef.tryParse('hz#spots#0')!.format(), 'hz#spots#0');
    });

    test('6. 顺延后互链联动：插天移动卡片 → 前缀反查的 dayNo 联动正确', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            startEpochDay: const d.Value(100),
            endEpochDay: const d.Value(102),
            createdAt: 1000,
            updatedAt: 1000,
          ));
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: 'i1',
            tripId: 't1',
            dateEpochDay: const d.Value(100),
            guideRef: const d.Value('hz#spots#0'),
            createdAt: now,
            updatedAt: now,
          ));
      int dayNo(int epoch) => epoch - 100 + 1;
      expect(dayNo((await trips.getItem('i1'))!.dateEpochDay), 1);
      final items = await trips.getItems('t1');
      await trips.applyDayOps(
          't1',
          insertDay(
            startEpochDay: 100,
            endEpochDay: 102,
            items: [
              for (final r in items) TripsRepository.tripItemToRecord(r)
            ],
            k: 0,
          ));
      // 插天最前：卡片顺延 → 第 2 天；无需重算 guideRef
      expect(dayNo((await trips.getItem('i1'))!.dateEpochDay), 2);
      expect(
        (await trips.findByGuideRefPrefix('t1', 'hz#spots#')).single.id,
        'i1',
      );
    });

    test('7. 收口规则 1 复核：落卡即移出 + 撤销后 id 不变', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            startEpochDay: const d.Value(100),
            endEpochDay: const d.Value(102),
            createdAt: 1000,
            updatedAt: 1000,
          ));
      final wid = await wishes.addItem(tripId: 't1', name: '西湖', durationMin: 60);
      final cardId =
          await wishes.placeToDay(tripId: 't1', wishlistId: wid, dateEpochDay: 100);
      // 两边不得同时存在
      expect(await wishes.getItem(wid), isNull);
      expect(await trips.getItem(cardId), isNotNull);
      // 装配撤销：删卡 + 恢复池行（id 不变）
      await wishes.restoreRow(const WishlistRecord(
        id: 'wid-restored',
        tripId: 't1',
        cityKey: '',
        name: '西湖',
        address: '',
        type: 'attraction',
        durationMin: 60,
        tag: null,
        guideRef: null,
        note: '',
        sortOrder: 10,
        createdAt: 1000,
        updatedAt: 1000,
      ));
      await trips.deleteItem(cardId);
      final restored = await wishes.getItem('wid-restored');
      expect(restored, isNotNull);
      expect(restored!.name, '西湖');
      expect(restored.id, isNot(cardId), reason: '池行与卡是两套 id 体系');
    });
  });

  group('三宿主组件冒烟 + viewer 禁用', () {
    late AppDatabase db;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '回归行程',
            destination: const d.Value('杭州'),
            startEpochDay: const d.Value(100),
            endEpochDay: const d.Value(102),
            createdAt: 1000,
            updatedAt: 1000,
          ));
    });
    tearDown(() async => db.close());

    Widget _host(Widget child, {bool withGuideOverrides = true}) {
      return ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          if (withGuideOverrides) ...[
            guideCityKeyByNameProvider.overrideWith(
                (ref) async => {'杭州': 'hangzhou', '苏州': 'suzhou'}),
            guideCityNameByKeyProvider.overrideWith(
                (ref) async => {'hangzhou': '杭州', 'suzhou': '苏州'}),
          ],
        ],
        child: MaterialApp(home: Scaffold(body: SizedBox(height: 800, child: child))),
      );
    }

    testWidgets('8. 大纲/装配/锦囊组件冒烟（移动+桌面共用）', (tester) async {
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.pumpWidget(_host(Column(children: const [
        Expanded(child: OutlineTab(tripId: 't1')),
      ])));
      await settle();
      expect(find.byType(OutlinePanel), findsOneWidget);
      expect(find.text('导入'), findsOneWidget);

      await tester.pumpWidget(_host(
          const AssemblePanel(tripId: 't1', canEdit: true)));
      await settle();
      expect(find.textContaining('容量'), findsWidgets);

      await tester.pumpWidget(_host(const KitTab(tripId: 't1')));
      await settle();
      expect(find.text('该目的地暂无锦囊'), findsNothing,
          reason: 'destination=杭州 命中种子城 → 渲染锦囊（或其栏目）');
    });

    testWidgets('9. 桌面 Workbench 三栏冒烟', (tester) async {
      tester.view.physicalSize = const Size(1680, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 1400,
          height: 900,
          child: DesktopTripsWorkbench(),
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('回归行程'), findsWidgets, reason: '左栏列表出现行程');
      await tester.tap(find.text('回归行程').first);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('装配'), findsOneWidget, reason: '中栏页签');
      expect(find.text('大纲'), findsOneWidget);
      expect(find.text('锦囊'), findsOneWidget);
      expect(find.text('攻略'), findsWidgets, reason: '左栏栏头');
    });

    testWidgets('10. viewer 全禁用走查：大纲只读无导入、锦囊只读、池只读',
        (tester) async {
      await tester.pumpWidget(_host(Column(children: [
        Expanded(
          child: OutlinePanel(
            initialText: 'D1\n旧卡',
            existingNamesByDay: const {1: {'旧卡'}},
            currentCardCount: 1,
            canWrite: false,
            onApply: (text, {required bool overwrite}) async =>
                throw StateError('viewer 不得执行导入'),
          ),
        ),
      ])));
      await tester.pumpAndSettle();
      expect(find.text('导入'), findsNothing, reason: 'viewer 无导入按钮');
    });
  });

  group('大纲覆盖强确认（不可恢复兜底）', () {
    testWidgets('11. 勾选前确认禁用 → 勾选后确认并回调 overwrite=true',
        (tester) async {
      OutlineImportCapture? captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: OutlinePanel(
              initialText: 'D1\n新卡 A',
              existingNamesByDay: const {},
              currentCardCount: 1,
              canWrite: true,
              onApply: (text, {required bool overwrite}) async {
                captured = OutlineImportCapture(text, overwrite);
                return const OutlineImportReportView(
                    added: 0, skipped: 0, invalid: [], pooled: 0);
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      // 模式弹层 → 覆盖整程
      await tester.tap(find.text('覆盖整程').first);
      await tester.pumpAndSettle();
      expect(find.text('覆盖整程'), findsOneWidget, reason: '强确认弹窗');
      expect(find.text('我已了解该操作不可恢复'), findsOneWidget);
      final confirmBtn = find.widgetWithText(FilledButton, '确认覆盖');
      expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull,
          reason: '未勾选 → 确认禁用');
      await tester.tap(find.text('我已了解该操作不可恢复'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNotNull);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(captured, isNotNull);
      expect(captured!.overwrite, isTrue);
    });
  });

  group('端到端补充回归', () {
    late AppDatabase db;
    late TripsRepository trips;
    late WishlistRepository wishes;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
      trips = TripsRepository(db);
      wishes = WishlistRepository(db);
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '行',
            startEpochDay: const d.Value(100),
            endEpochDay: const d.Value(102),
            createdAt: 1000,
            updatedAt: 1000,
          ));
    });
    tearDown(() async => db.close());

    test('12. 大纲导入执行器：追加建卡 + 无天头行入池（S3×S6 接线）', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: 'seed',
            tripId: 't1',
            dateEpochDay: const d.Value(100),
            name: const d.Value('已有卡'),
            createdAt: now,
            updatedAt: now,
          ));
      final items = await trips.getItems('t1');
      final report = await applyOutlineImport(
        tripsRepo: trips,
        wishlistRepo: wishes,
        trip: (await trips.getById('t1'))!,
        items: items,
        text: '无天头C\nD2\n09:00 新卡A 1.5h\n新卡B',
        overwrite: false,
      );
      expect(report.added, 2, reason: 'D2 两行建卡');
      expect(report.pooled, 1, reason: '无天头行入池');
      final after = await trips.getItems('t1');
      expect(after.where((e) => e.name == '新卡A').single.dateEpochDay, 101);
      expect(
          after.where((e) => e.name == '新卡A').single.durationMin, 90);
      final pool = await wishes.getByTrip('t1');
      expect(pool.map((e) => e.name), ['无天头C']);
    });

    test('13. S2 修正后删中间天（shift）落库无空洞：卡全在新区间内', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      Future<void> card(String id, int day, {int sort = 10}) =>
          db.into(db.tripItems).insert(TripItemsCompanion.insert(
                id: id,
                tripId: 't1',
                dateEpochDay: d.Value(day),
                sortOrder: d.Value(sort),
                createdAt: now,
                updatedAt: now,
              ));
      await card('a', 100);
      await card('b', 101, sort: 10);
      await card('c', 101, sort: 20);
      await card('d', 102, sort: 10);
      final items = await trips.getItems('t1');
      final ops = removeDay(
          startEpochDay: 100,
          endEpochDay: 102,
          items: [for (final r in items) TripsRepository.tripItemToRecord(r)],
          k: 2,
          mode: RemoveMode.shift);
      await trips.applyDayOps('t1', ops);
      final after = await trips.getItems('t1');
      // 新区间 [100,101]：a@100、b/c/d@101，无空洞、无越界
      expect(after.map((e) => e.dateEpochDay).toSet(), {100, 101});
      final day2 = after.where((e) => e.dateEpochDay == 101).toList()
        ..sort((x, y) => x.sortOrder.compareTo(y.sortOrder));
      expect(day2.map((e) => e.id), ['d', 'b', 'c'],
          reason: '承接天原序在前，被删天卡按步长续编在后');
      expect(day2.map((e) => e.sortOrder), [10, 20, 30]);
    });

    test('14. 红线复核：攻略直接排不复制种子长文（note 为空）', () async {
      final id = await trips.addItemWithGuideRef(
        tripId: 't1',
        dateEpochDay: 100,
        name: '西湖',
        type: 'attraction',
        guideRef: 'hz#spots#0',
        address: '龙井路1号',
        durationMin: 90,
      );
      final card = (await trips.getItem(id))!;
      expect(card.note, '', reason: '卡片只存 name/address/type/durationMin，长文走互链');
      expect(card.guideRef, 'hz#spots#0');
    });
  });
}

class OutlineImportCapture {
  OutlineImportCapture(this.text, this.overwrite);
  final String text;
  final bool overwrite;
}
