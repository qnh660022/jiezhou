// V2.8.1 S8：SubBudgets 全量同步登记。
//
// 覆盖四条线：
// 1) repo 写路径（add/update/delete）逐个产生 entity='sub_budgets' 的 outbox 事件；
// 2) SyncCodec.subBudgetToCloud → subBudgetFromCloud round-trip 字段逐一对回
//    （列名与 docs/db_v281.sql 云表 DDL 对齐，deleted=false 由信封恒带）；
// 3) 契约钉死：localKey='sub_budgets'、云表 'sub_budgets_sync'、不在
//    isCollabMirror、pullOrder 位于 settlements 之后 trips 之前；
// 4) 删团级联：sub_budgets 行清空且逐行发出 delete 墓碑。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_codec.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';

class _NotifySpy {
  final events = <(String, String, String)>[];
  void attach() {
    SyncOutboxService.hook =
        (entity, rowId, op, ms) => events.add((entity, rowId, op));
  }

  void detach() => SyncOutboxService.hook = null;
}

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  final spy = _NotifySpy();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
    spy.attach();
  });
  tearDown(() async {
    spy.detach();
    await db.close();
  });

  test('1. add/update/delete 分别产生 upsert/upsert/delete 事件（entity=sub_budgets）',
      () async {
    final g = await repo.addGroup('团', '📁');
    spy.events.clear();

    final b = await repo.addSubBudget(g.id, 'food', 50000);
    expect(spy.events.single, ('sub_budgets', b.id, 'upsert'));
    expect(b.amount, 50000);
    expect(b.categoryKey, 'food');
    expect(b.groupId, g.id);

    // updatedAt 推进（LWW 基准），createdAt 不变
    await Future<void>.delayed(const Duration(milliseconds: 3));
    final before = await (db.select(db.subBudgets)
          ..where((x) => x.id.equals(b.id)))
        .getSingle();
    spy.events.clear();
    await repo.updateSubBudget(b.id, 80000);
    expect(spy.events.single, ('sub_budgets', b.id, 'upsert'));
    final after = await (db.select(db.subBudgets)
          ..where((x) => x.id.equals(b.id)))
        .getSingle();
    expect(after.amount, 80000);
    expect(after.createdAt, before.createdAt);
    expect(after.updatedAt, greaterThan(before.createdAt));

    spy.events.clear();
    await repo.deleteSubBudget(b.id);
    expect(spy.events.single, ('sub_budgets', b.id, 'delete'));
    expect(await db.select(db.subBudgets).get(), isEmpty);
  });

  test('2. codec round-trip：toCloud → 信封 → fromCloud 字段逐一对回', () {
    const row = SubBudget(
      id: 'subbud_x',
      groupId: 'g1',
      categoryKey: 'food',
      amount: 12345,
      createdAt: 111,
      updatedAt: 222,
    );
    final cloud = SyncCodec.subBudgetToCloud(row);
    // 列名与 docs/db_v281.sql DDL 对齐（snake_case）
    expect(cloud, {
      'group_id': 'g1',
      'category_key': 'food',
      'amount': 12345,
      'created_ms': 111,
      'updated_ms': 222,
    });

    final env = SyncEnvelope(
      entity: SyncEntity.subBudgets,
      rowId: row.id,
      op: SyncOutboxOp.upsert,
      updatedMs: 222,
      row: cloud,
    );
    final wire = env.toCloudJson();
    expect(wire['deleted'], false, reason: '上行 upsert 信封恒带 deleted=false');
    expect(wire['id'], 'subbud_x');
    expect(wire['created_ms'], 111, reason: '行内已有 created_ms 不被信封覆盖');

    final back = SyncCodec.subBudgetFromCloud(wire);
    expect(back.id.value, row.id);
    expect(back.groupId.value, row.groupId);
    expect(back.categoryKey.value, row.categoryKey);
    expect(back.amount.value, row.amount, reason: '金额 int 分原样对回');
    expect(back.createdAt.value, row.createdAt);
    expect(back.updatedAt.value, row.updatedAt);
  });

  test('3. 契约钉死：localKey / 云表 / 非协作镜像 / pullOrder 次序', () {
    expect(SyncEntity.subBudgets.localKey, 'sub_budgets');
    expect(SyncEntity.subBudgets.cloudTable, 'sub_budgets_sync');
    expect(SyncEntity.byLocalKey('sub_budgets'), SyncEntity.subBudgets);
    expect(SyncEntity.subBudgets.isCollabMirror, isFalse,
        reason: '团级账本域实体，不走红像镜像表');
    final order = SyncEntity.pullOrder;
    expect(order.indexOf(SyncEntity.subBudgets),
        greaterThan(order.indexOf(SyncEntity.settlements)));
    expect(order.indexOf(SyncEntity.subBudgets),
        lessThan(order.indexOf(SyncEntity.trips)));
  });

  test('4. 删团级联：sub_budgets 行清空且逐行发出 delete 墓碑', () async {
    final g = await repo.addGroup('团', '📁');
    await repo.addSubBudget(g.id, 'food', 10000);
    await repo.addSubBudget(g.id, 'stay', 20000);
    expect(await db.select(db.subBudgets).get().then((l) => l.length), 2);

    spy.events.clear();
    await repo.deleteGroup(g.id);

    expect(await db.select(db.subBudgets).get(), isEmpty,
        reason: '删团必须级联清理该团子预算行');
    final deletes = spy.events
        .where((e) => e.$1 == 'sub_budgets' && e.$3 == 'delete')
        .map((e) => e.$2)
        .toSet();
    expect(deletes.length, 2, reason: '两条子预算逐行发出 delete 墓碑');
  });

  test('5. watchSubBudgets：按团过滤且 updatedAt 升序', () async {
    final g = await repo.addGroup('团', '📁');
    final b1 = await repo.addSubBudget(g.id, 'food', 100);
    await Future<void>.delayed(const Duration(milliseconds: 3));
    final b2 = await repo.addSubBudget(g.id, 'stay', 200);

    final other = await repo.addGroup('别的团', '📁');
    await repo.addSubBudget(other.id, 'food', 999);

    final rows = await repo.watchSubBudgets(g.id).first;
    expect(rows.map((r) => r.id), [b1.id, b2.id],
        reason: '只含本团行，updatedAt 升序');
  });
}
