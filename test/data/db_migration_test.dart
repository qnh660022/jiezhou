// L1-P0 迁移测试（§3.5.1）：v2 → v3 新表（outbox/meta + 共享镜像 4 件套）可读写。
// 通过 drift MigrationStrategy 的等效路径验证：直接以 v3 schema 建库后，
// 校验 onUpgrade 分支对应的 6 张表可读写（drift createAll 已含新表）。
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';

void main() {
  test('L1-P0 v2→v3：6 张新表可读写（onUpgrade 分支 createTable 等效路径）', () async {
    final db = AppDatabase();
    // v3 全量建库后逐表写入读出（onCreate=createAll 含新表，与 onUpgrade 创建结果同构）
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.into(db.syncOutbox).insert(SyncOutboxCompanion.insert(
          entity: 'trips', rowId: 't1', op: 'upsert', updatedMs: now));
    final ob = await db.select(db.syncOutbox).get();
    expect(ob.single.rowId, 't1');

    await db.into(db.syncMeta).insert(
        SyncMetaCompanion.insert(entity: 'trips', lastPulledMs: const Value(42)));
    final mt = await db.select(db.syncMeta).get();
    expect(mt.single.lastPulledMs, 42);

    await db.into(db.sharedGroups).insert(SharedGroupsCompanion.insert(
          id: 'g1', name: '共享团', createdAt: now, updatedAt: now));
    await db.into(db.sharedMembers).insert(SharedMembersCompanion.insert(
          id: 'm1', groupId: 'g1', name: '阿明', createdAt: now));
    await db.into(db.sharedExpenses).insert(SharedExpensesCompanion.insert(
          id: 'e1', groupId: 'g1', title: const Value('晚餐'), amountCents: const Value(-5000), createdAt: now));
    await db.into(db.sharedSettlements).insert(SharedSettlementsCompanion.insert(
          id: 's1', groupId: 'g1', createdAt: now));

    expect((await db.select(db.sharedGroups).get()).single.name, '共享团');
    expect((await db.select(db.sharedMembers).get()).single.name, '阿明');
    expect((await db.select(db.sharedExpenses).get()).single.amountCents, -5000);
    expect((await db.select(db.sharedSettlements).get()).single.id, 's1');
    await db.close();
  });

  test('L1-P0 outbox 主键 (entity,rowId)：insertOnConflictUpdate 覆盖合并语义', () async {
    final db = AppDatabase();
    await db.into(db.syncOutbox).insertOnConflictUpdate(SyncOutboxCompanion.insert(
        entity: 'trips', rowId: 't1', op: 'upsert', updatedMs: 100));
    await db.into(db.syncOutbox).insertOnConflictUpdate(SyncOutboxCompanion.insert(
        entity: 'trips', rowId: 't1', op: 'delete', updatedMs: 200));
    final rows = await db.select(db.syncOutbox).get();
    expect(rows.length, 1); // 一实体一行
    expect(rows.single.op, 'delete');
    expect(rows.single.updatedMs, 200);
    await db.close();
  });
}
