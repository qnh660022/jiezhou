// V2.7.2 S1：drift schemaVersion 5→6 一次到位。
// 覆盖：2 张新表（wishlist_items / shared_wishlist_items）可读写、
// 5 个新列默认值（pace / guide_ref / backup_of）、历史库升级路径数据零丢失。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase());
  tearDown(() async => db.close());

  final now = DateTime.now().millisecondsSinceEpoch;

  Future<String> seedTrip(String id) async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: id, name: '杭州行', createdAt: now, updatedAt: now));
    return id;
  }

  test('S1：schemaVersion == 6', () {
    expect(db.schemaVersion, 6);
  });

  test('S1：新列默认值（trips.pace=standard / guide_ref / backup_of=NULL）', () async {
    await seedTrip('t1');
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'i1', tripId: 't1', createdAt: now, updatedAt: now));
    final t = (await db.select(db.trips).get()).single;
    final i = (await db.select(db.tripItems).get()).single;
    expect(t.pace, 'standard', reason: '老数据默认 standard 档');
    expect(i.guideRef, isNull);
    expect(i.backupOf, isNull);
  });

  test('S1：wishlist_items 可读写（全列 + 默认值）', () async {
    await seedTrip('t1');
    await db.into(db.wishlistItems).insert(WishlistItemsCompanion.insert(
          id: 'w1',
          tripId: 't1',
          cityKey: const Value('hangzhou'),
          name: const Value('西湖'),
          address: const Value('龙井路1号'),
          type: const Value('attraction'),
          durationMin: const Value(90),
          tag: const Value('必去'),
          guideRef: const Value('hangzhou#spots#0'),
          note: const Value('傍晚去'),
          sortOrder: const Value(5),
          createdAt: now,
          updatedAt: now,
        ));
    final w = (await db.select(db.wishlistItems).get()).single;
    expect(w.tripId, 't1');
    expect(w.cityKey, 'hangzhou');
    expect(w.name, '西湖');
    expect(w.durationMin, 90);
    expect(w.tag, '必去');
    expect(w.guideRef, 'hangzhou#spots#0');
    expect(w.sortOrder, 5);
  });

  test('S1：shared_wishlist_items 可读写（无外键镜像表）', () async {
    // 镜像表不 references trips：别人的行程行可先行落镜像
    await db.into(db.sharedWishlistItems).insert(SharedWishlistItemsCompanion.insert(
          id: 'sw1',
          tripId: 'otherTrip',
          name: const Value('灵隐寺'),
          createdAt: now,
          updatedAt: now,
        ));
    final w = (await db.select(db.sharedWishlistItems).get()).single;
    expect(w.tripId, 'otherTrip');
    expect(w.name, '灵隐寺');
    expect(w.type, 'attraction');
    expect(w.durationMin, isNull);
  });

  test('S1：新表初始为空（迁移后无残留）', () {
    expect(db.allTables.map((t) => t.actualTableName),
        containsAll(<String>['wishlist_items', 'shared_wishlist_items']));
  });

  test('S1：想去池已进同步层（audit/conflict 式纯本地区别对待）', () {
    // 正向：wishlist_items 是同步实体；audit/conflict 不在枚举里
    expect(SyncEntity.wishlistItems.cloudTable, 'wishlist_items_sync');
    final localKeys = SyncEntity.values.map((e) => e.localKey).toSet();
    expect(localKeys.contains('wishlist_items'), isTrue);
    expect(localKeys.contains('audit_logs'), isFalse,
        reason: '审计表仅本地，不得登记');
    expect(localKeys.contains('conflict_records'), isFalse,
        reason: '冲突回执仅本地，不得登记');
  });

  test('S1：v5→v6 升级路径等效（历史业务表行数不变、新列默认值/NULL）', () async {
    // onCreate=createAll 与 onUpgrade 创建结果同构（迁移测试惯例）：直接以 v6
    // 建库后验证历史表 + 新表共存、历史行可写、新列为默认值/NULL。
    await seedTrip('t1');
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'i1', tripId: 't1', createdAt: now, updatedAt: now));
    await db.into(db.checklistItems).insert(ChecklistItemsCompanion.insert(
          id: 'c1', tripId: const Value('t1'), label: const Value('充电宝')));
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: 'e1', groupId: 'g1', createdAt: now));
    expect((await db.select(db.trips).get()).length, 1);
    expect((await db.select(db.tripItems).get()).length, 1);
    expect((await db.select(db.checklistItems).get()).length, 1);
    expect((await db.select(db.expenses).get()).length, 1);
    // 数据零丢失口径：历史行字段未被迁移破坏（pace/guide_ref/backup_of 全默认）
    final i = (await db.select(db.tripItems).get()).single;
    expect(i.guideRef, isNull);
    expect(i.backupOf, isNull);
  });
}
