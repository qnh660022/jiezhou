// V2.9.0 清单 scope 收口回归（P0）：
//   1) addItem('global') 强制 tripId=null（仓储层收口，行李页选中行程 id 不再混入）；
//   2) deleteTrip 只级联清 scope='trip' 的清单，全局待办不被连带清光；
//   3) copyFromTrip 二次复制不撞唯一主键（新 id 用 newId），同 label 去重；
//   4) addItem 的 done 可选参数回填（删除撤销恢复完成态）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/checklist_repo.dart';
import 'package:travel_assistant/data/repo/trips_repo.dart';

void main() {
  late AppDatabase db;
  late ChecklistRepository repo;
  late TripsRepository tripsRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = ChecklistRepository(db);
    tripsRepo = TripsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  final now = DateTime.now().millisecondsSinceEpoch;

  Future<String> seedTrip(String id) async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: id, name: '行程$id', createdAt: now, updatedAt: now));
    return id;
  }

  Future<void> seedItem({
    required String id,
    String? tripId,
    required String scope,
    String label = '条目',
    bool done = false,
    int sortOrder = 0,
    String category = 'other',
  }) =>
      db.into(db.checklistItems).insert(ChecklistItemsCompanion.insert(
            id: id,
            tripId: Value(tripId),
            scope: Value(scope),
            category: Value(category),
            label: Value(label),
            done: Value(done),
            sortOrder: Value(sortOrder),
          ));

  Future<List<ChecklistItem>> allItems() => db.select(db.checklistItems).get();

  test('addItem：scope=global 时强制 tripId 落 null（传了行程 id 也收口）', () async {
    await seedTrip('t1');
    // 模拟行李页持久化了选中行程 id 后新增全局待办（原 bug：global 条目写入 tripId）。
    await repo.addItem('t1', 'global', 'other', '买旅行险', 0);
    final rows = await allItems();
    expect(rows, hasLength(1));
    expect(rows.single.scope, 'global');
    expect(rows.single.tripId, isNull, reason: 'global 条目不得携带 tripId');
  });

  test('addItem：scope=trip 保留 tripId（向后兼容）', () async {
    await seedTrip('t1');
    await repo.addItem('t1', 'trip', 'clothes', '冲锋衣', 3);
    final rows = await allItems();
    expect(rows.single.scope, 'trip');
    expect(rows.single.tripId, 't1');
    expect(rows.single.category, 'clothes');
  });

  test('addItem：done 可选参数回填（删除撤销恢复完成态，默认 false 向后兼容）', () async {
    await seedTrip('t1');
    await repo.addItem('t1', 'trip', 'other', '已完成项', 0, done: true);
    await repo.addItem('t1', 'trip', 'other', '未完成项', 1);
    final rows = await allItems();
    final byLabel = {for (final r in rows) r.label: r.done};
    expect(byLabel['已完成项'], isTrue);
    expect(byLabel['未完成项'], isFalse);
  });

  test('deleteTrip：只清 scope=trip 清单，全局待办（含历史脏数据行）不被连带清光', () async {
    await seedTrip('t1');
    await seedTrip('t2');
    // 行程域条目：随行程删除
    await seedItem(id: 'check_a', tripId: 't1', scope: 'trip', label: '护照');
    // 干净的全局待办（tripId=null）
    await seedItem(id: 'check_g1', tripId: null, scope: 'global', label: '订机票');
    // 历史脏数据：global 条目曾被写入 tripId（升级用户可能存在）
    await seedItem(id: 'check_g2', tripId: 't1', scope: 'global', label: '买旅行险');

    await tripsRepo.deleteTrip('t1');

    final rows = await allItems();
    final ids = rows.map((r) => r.id).toSet();
    expect(ids, containsAll(['check_g1', 'check_g2']),
        reason: '删行程不得清掉全局待办（含被历史 bug 写入 tripId 的行）');
    expect(ids.contains('check_a'), isFalse, reason: '行程域条目应随行程级联删除');
  });

  test('copyFromTrip：二次复制不撞唯一主键，同 label 去重不重复落库', () async {
    await seedTrip('src');
    await seedTrip('dst');
    await seedItem(id: 's1', tripId: 'src', scope: 'trip', label: '护照', sortOrder: 0);
    await seedItem(id: 's2', tripId: 'src', scope: 'trip', label: '充电宝', sortOrder: 1);

    // 第一次复制成功
    await repo.copyFromTrip('src', 'dst');
    // 二次复制：原实现 i.id+"_cp" 撞唯一约束抛异常
    await repo.copyFromTrip('src', 'dst');

    final dstRows = await allItems();
    final dstTrip = dstRows.where((r) => r.tripId == 'dst' && r.scope == 'trip').toList();
    expect(dstTrip, hasLength(2), reason: '同 label 二次复制应去重跳过');
    final labels = dstTrip.map((r) => r.label).toSet();
    expect(labels, {'护照', '充电宝'});
    // 新 id 必须是全新生成（不再是 srcId+"_cp" 的可撞键模式）
    expect(dstTrip.every((r) => r.id != 's1_cp' && r.id != 's2_cp'), isTrue);
  });

  test('copyFromTrip：只复制 scope=trip 条目，global 行不混入', () async {
    await seedTrip('src');
    await seedTrip('dst');
    await seedItem(id: 's1', tripId: 'src', scope: 'trip', label: '护照');
    // 历史脏数据：global 行带 src 的 tripId
    await seedItem(id: 'g1', tripId: 'src', scope: 'global', label: '订机票');

    await repo.copyFromTrip('src', 'dst');

    final dstRows = await allItems();
    final dstTrip = dstRows.where((r) => r.tripId == 'dst').toList();
    expect(dstTrip, hasLength(1));
    expect(dstTrip.single.label, '护照');
  });

  test('getAllByScope：global 查询不串行程域数据', () async {
    await seedTrip('t1');
    await seedItem(id: 's1', tripId: 't1', scope: 'trip', label: '护照');
    await seedItem(id: 'g1', tripId: null, scope: 'global', label: '订机票');
    final global = await repo.getAllByScope('global');
    expect(global.map((r) => r.id), ['g1']);
  });
}
