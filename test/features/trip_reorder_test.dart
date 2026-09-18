// V2.7.2 S4：拖拽排序与跨天批量（repo 层，规格 §七 7.3 验收）。
// 全量导入（不能只 show OrderingTerm/Value）：布尔表达式需要 drift 的 `&`
// 运算符扩展，只 show 具体符号会把它过滤掉（V2.7.2 S4 测试编译修复）。
// hide isNull：drift 的同名顶层函数与 flutter_test 的匹配器同名，会判为歧义。
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';

class _NotifySpy {
  final events = <(String, String, String)>[];
  void attach() {
    SyncOutboxService.hook = (entity, rowId, op, ms) => events.add((entity, rowId, op));
  }

  void detach() => SyncOutboxService.hook = null;
}

void main() {
  late AppDatabase db;
  late TripsRepository repo;
  final spy = _NotifySpy();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = TripsRepository(db);
    spy.attach();
  });
  tearDown(() async {
    spy.detach();
    await db.close();
  });

  final now = DateTime.now().millisecondsSinceEpoch;
  const tripId = 't1';
  const day = 100;

  Future<List<String>> seedDay(List<String> ids, {int at = day}) async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: tripId,
          name: '行',
          startEpochDay: const Value(day),
          endEpochDay: const Value(day + 2),
          createdAt: now,
          updatedAt: now));
    var o = 0;
    for (final id in ids) {
      o += 10;
      await db.into(db.tripItems).insert(TripItemsCompanion.insert(
            id: id,
            tripId: tripId,
            dateEpochDay: Value(at),
            name: Value(id),
            sortOrder: Value(o),
            createdAt: now,
            updatedAt: now,
          ));
    }
    return ids;
  }

  List<String> ordersOf(List<TripItem> rows) =>
      [for (final r in rows) ...[r.id, r.sortOrder.toString()]];

  test('1/2. 拖拽重排：sortOrder 步长 10 整体重编且刷新后保持', () async {
    await seedDay(['a', 'b', 'c']);
    spy.events.clear();
    await repo.reorderDay(tripId, day, ['c', 'a', 'b']);
    final rows = await (db.select(db.tripItems)
          ..where((t) => t.tripId.equals(tripId) & t.dateEpochDay.equals(day))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect(rows.map((r) => r.id).toList(), ['c', 'a', 'b']);
    expect(rows.map((r) => r.sortOrder).toList(), [10, 20, 30]);
    // 仅变更行上行（c:10→? b 未动? a/b/c 全部重编 → 3 行 upsert）
    expect(spy.events.where((e) => e.$3 == 'upsert').length, 3);
  });

  test('3. 重排不动其他天的行', () async {
    await seedDay(['a', 'b']);
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'z',
          tripId: tripId,
          dateEpochDay: const Value(day + 1),
          sortOrder: const Value(10),
          createdAt: now,
          updatedAt: now,
        ));
    spy.events.clear();
    await repo.reorderDay(tripId, day, ['b', 'a']);
    final z = (await (db.select(db.tripItems)..where((t) => t.id.equals('z'))).get()).single;
    expect(z.sortOrder, 10, reason: '其他天行不受影响');
    expect(spy.events.any((e) => e.$2 == 'z'), isFalse);
  });

  test('4. moveItemToDay：dateEpochDay 更新 + sortOrder 追加目标天末尾', () async {
    await seedDay(['a', 'b']);
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 't2x',
          tripId: tripId,
          dateEpochDay: const Value(day + 1),
          sortOrder: const Value(20),
          createdAt: now,
          updatedAt: now,
        ));
    await repo.moveItemToDay(tripId, 'a', day + 1);
    final a = (await (db.select(db.tripItems)..where((t) => t.id.equals('a'))).get()).single;
    expect(a.dateEpochDay, day + 1);
    expect(a.sortOrder, 30, reason: '目标天原最大 20 → 追加 30');
  });

  test('5. 批量移动：单事务内多行依次追加目标天末尾', () async {
    await seedDay(['a', 'b', 'c']);
    await db.into(db.tripItems).insert(TripItemsCompanion.insert(
          id: 'd',
          tripId: tripId,
          dateEpochDay: const Value(day + 1),
          createdAt: now,
          updatedAt: now,
        ));
    await repo.batchMove(tripId, ['a', 'c'], day + 1);
    final rows = await (db.select(db.tripItems)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.dateEpochDay), (t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final moved = rows.where((r) => r.dateEpochDay == day + 1).toList();
    expect(moved.map((r) => r.id).toList(), ['d', 'a', 'c']);
    expect(moved.map((r) => r.sortOrder).toList(), [0, 10, 20],
        reason: 'd 默认 0；批量移动依次追加 10/20');
  });

  test('6. 批量移动墓碑口径：upsert 逐行发出', () async {
    await seedDay(['a', 'b']);
    spy.events.clear();
    await repo.batchMove(tripId, ['a'], day + 2);
    expect(
        spy.events.where((e) => e.$2 == 'a').map((e) => e.$3).toList(), ['upsert']);
  });

  test('7. 批量删除：物理删 + 关联账单摘链 + 逐行墓碑', () async {
    await seedDay(['a', 'b']);
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: 'e1',
          groupId: 'g1',
          tripItemId: const Value('a'),
          createdAt: now,
        ));
    spy.events.clear();
    await repo.batchDelete(tripId, ['a', 'b']);
    expect(await db.select(db.tripItems).get(), isEmpty);
    final e = (await db.select(db.expenses).get()).single;
    expect(e.tripItemId, isNull, reason: '关联账单保留但摘链');
    expect(
        spy.events.where((e) => e.$1 == 'trip_items' && e.$3 == 'delete').map((e) => e.$2),
        unorderedEquals(['a', 'b']));
  });

  test('8. 空批量短路（无事务无通知）', () async {
    spy.events.clear();
    await repo.batchMove(tripId, const [], day);
    await repo.batchDelete(tripId, const []);
    expect(spy.events, isEmpty);
  });

  test('9. reorderDay 传缺失 id：跳过未知行不崩溃', () async {
    await seedDay(['a', 'b']);
    await repo.reorderDay(tripId, day, ['b', 'a', 'ghost']);
    final rows = await (db.select(db.tripItems)
          ..where((t) => t.tripId.equals(tripId) & t.dateEpochDay.equals(day))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect(ordersOf(rows).whereType<String>().where((s) => s == 'ghost'), isEmpty);
    expect(rows.map((r) => r.id).toList(), ['b', 'a']);
  });

  test('10. 重排幂等：同序重发不产生写事件', () async {
    await seedDay(['a', 'b']);
    spy.events.clear();
    await repo.reorderDay(tripId, day, ['a', 'b']);
    expect(spy.events.where((e) => e.$1 == 'trip_items'), isEmpty,
        reason: '顺序未变 → 无 upsert');
  });

  test('11. 批量移动后源天/目标天计数正确（空源天成行）', () async {
    await seedDay(['a', 'b']);
    await repo.batchMove(tripId, ['a', 'b'], day + 2);
    final rows = await db.select(db.tripItems).get();
    expect(rows.where((r) => r.dateEpochDay == day), isEmpty,
        reason: '源天清空（该天成空天）');
    expect(rows.where((r) => r.dateEpochDay == day + 2).length, 2);
  });
}
