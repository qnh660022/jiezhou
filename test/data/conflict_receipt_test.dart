// V2.7.1 S12.2：冲突回执（仅提示不干预 / 仅本地 / 纯观测）。
//
// 判定精确化：`local != null && pending != null && cloudMs > localMs` →
// 本地有未上行改动且被云端胜出。本地胜与「无 pending」都不记录。
//
// 用「账单」做主线（有 group_id，正是 UI 要挂小标记的实体）；
// 「无团归属不记」单独用行程验证。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/observability_repo.dart';
import 'package:travel_assistant/data/sync/db_access.dart';
import 'package:travel_assistant/data/sync/sync_merger.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxService outbox;
  late SyncMerger merger;

  setUp(() async {
    conflictDetectionEnabled = true;
    auditEnabled = true;
    db = AppDatabase();
    outbox = SyncOutboxService(db);
    merger = SyncMerger(db, outbox)
      ..refreshContext(userId: 'u1', collabGroups: {});
    await db.into(db.groups).insert(GroupsCompanion.insert(
          id: 'g1',
          name: '团',
          createdAt: 1,
          updatedAt: 1,
        ));
  });

  tearDown(() async {
    conflictDetectionEnabled = true;
    auditEnabled = true;
    await db.close();
  });

  Future<void> seedExpense(String id, int createdAt,
          {String title = '本地标题'}) =>
      db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: id,
            groupId: 'g1',
            dateEpochDay: const Value(1),
            title: Value(title),
            categoryKey: const Value('food'),
            amountCents: const Value(1000),
            createdAt: createdAt,
          ));

  Map<String, dynamic> cloudExpense(String id, int updatedMs,
          {String title = '云端标题'}) =>
      {
        'id': id,
        'group_id': 'g1',
        'date_epoch_day': 1,
        'title': title,
        'category_key': 'food',
        'type': 'normal',
        'amount_cents': 1200,
        'currency': 'CNY',
        'rate': 1.0,
        'payers_json': '[]',
        'shares_json': '[]',
        'share_mode': 'equal',
        'note': '',
        'created_ms': 100,
        'updated_ms': updatedMs,
        'deleted': false,
      };

  group('冲突回执 · 判定', () {
    test('1. 双端并发：本地有未上行事件 + 云端更新 → 恰好 1 条，winner=remote', () async {
      await seedExpense('e1', 100);
      // 本地改到 150 但还没上行
      await outbox.enqueue('expenses', 'e1', 'upsert', 150);

      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));

      final all = await db.select(db.conflictRecords).get();
      expect(all.length, 1);
      final c = all.first;
      expect(c.groupId, 'g1');
      expect(c.entity, 'expenses');
      expect(c.entityId, 'e1');
      expect(c.winner, kConflictWinnerRemote);
      expect(c.localUpdatedMs, 150);
      expect(c.remoteUpdatedMs, 200);
      expect(c.acknowledged, 0);
      expect(c.detectedAtMs, greaterThan(0));

      // 纯观测：合并结果照旧是云端胜。
      final row = await (db.select(db.expenses)..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(row.title, '云端标题');
      expect(row.amountCents, 1200);
    });

    test('2. 本地胜（cloudMs < localMs）不记录，且本地值保留', () async {
      await seedExpense('e1', 500);
      await outbox.enqueue('expenses', 'e1', 'upsert', 500);

      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));

      expect(await db.select(db.conflictRecords).get(), isEmpty);
      final row = await (db.select(db.expenses)..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(row.title, '本地标题');
    });

    test('3. 无未上行事件（只改过云端）不误报', () async {
      await seedExpense('e1', 100);

      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));

      expect(await db.select(db.conflictRecords).get(), isEmpty);
    });

    test('4. 首次下行（本地无行）不记录', () async {
      await outbox.enqueue('expenses', 'e1', 'upsert', 150);
      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));
      expect(await db.select(db.conflictRecords).get(), isEmpty);
    });

    test('5. 同一实体多次冲突：追加不覆盖', () async {
      await seedExpense('e1', 100);
      await outbox.enqueue('expenses', 'e1', 'upsert', 150);
      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));

      // 第二次并发：本地再改（不能重插同 id）
      await (db.update(db.expenses)..where((t) => t.id.equals('e1'))).write(
        ExpensesCompanion(createdAt: const Value(200), title: const Value('本地二次')),
      );
      await outbox.enqueue('expenses', 'e1', 'upsert', 250);
      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 300));

      final all = await db.select(db.conflictRecords).get();
      expect(all.length, 2, reason: '两条独立回执，不是覆盖成一条');
      expect(all.map((c) => c.remoteUpdatedMs).toSet(), {200, 300});
    });

    test('6. 确认后未确认集合清空（「知道了」语义）', () async {
      await seedExpense('e1', 100);
      await outbox.enqueue('expenses', 'e1', 'upsert', 150);
      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));

      expect((await conflictsOfEntity(db, 'e1')).length, 1);
      await acknowledgeConflictsOfEntity(db, 'e1');
      expect(await conflictsOfEntity(db, 'e1'), isEmpty);
      final row = (await db.select(db.conflictRecords).get()).first;
      expect(row.acknowledged, 1, reason: '置位而非删除（保留历史事实）');
      expect(await watchUnacknowledgedConflictCount(db, groupId: 'g1').first, 0);
    });

    test('7. 关闭检测：无回执，且合并产物与开启时逐字段相同', () async {
      await seedExpense('e1', 100);
      await outbox.enqueue('expenses', 'e1', 'upsert', 150);
      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));
      final onOpen = await (db.select(db.expenses)..where((t) => t.id.equals('e1')))
          .getSingle();

      conflictDetectionEnabled = false;
      await db.delete(db.conflictRecords).go();
      await db.delete(db.expenses).go();
      await seedExpense('e1', 100);
      await outbox.enqueue('expenses', 'e1', 'upsert', 150);
      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));
      final onClosed = await (db.select(db.expenses)..where((t) => t.id.equals('e1')))
          .getSingle();

      expect(await db.select(db.conflictRecords).get(), isEmpty);
      expect(onClosed.title, onOpen.title);
      expect(onClosed.amountCents, onOpen.amountCents);
      expect(onClosed.createdAt, onOpen.createdAt);
      expect(onClosed.settledRoundId, onOpen.settledRoundId);
    });

    test('8. 无团归属（独立行程）不记录，避免孤儿回执', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 't1',
            name: '本地名',
            createdAt: 10,
            updatedAt: 100,
          ));
      await outbox.enqueue('trips', 't1', 'upsert', 150);

      await merger.mergeRow(SyncEntity.trips, {
        'id': 't1',
        'name': '云端名',
        'updated_ms': 200,
        'created_ms': 100,
        'deleted': false,
      });

      expect(await db.select(db.conflictRecords).get(), isEmpty);
    });
  });

  group('冲突回执 · 隐私与同步边界', () {
    test('9. 不登记为 SyncEntity（键名都拿不到）', () {
      final keys = SyncEntity.values.map((e) => e.localKey).toSet();
      expect(keys.contains('conflict_records'), isFalse);
      expect(keys.contains('audit_logs'), isFalse);
    });

    test('10. assemble 读不出回执行（不会上行成云端行）', () async {
      await seedExpense('e1', 100);
      await outbox.enqueue('expenses', 'e1', 'upsert', 150);
      await merger.mergeRow(SyncEntity.expenses, cloudExpense('e1', 200));
      final conflict = (await db.select(db.conflictRecords).get()).first;

      final accessor = SyncDbAccessor(db);
      expect(await accessor.readBusinessRow('conflict_records', conflict.id), isNull);
      expect(await accessor.readBusinessRow('audit_logs', 'whatever'), isNull);
      expect(await accessor.readBusinessRow('expenses', 'e1'), isNotNull,
          reason: '对照组：业务表正常可读');
    });

    test('11. 未确认计数按团隔离', () async {
      for (final g in const ['g1', 'g2']) {
        await db.into(db.conflictRecords).insert(ConflictRecordsCompanion.insert(
              id: 'c-$g',
              groupId: g,
              entity: 'expenses',
              entityId: 'e-$g',
              localUpdatedMs: 100,
              remoteUpdatedMs: 200,
              winner: kConflictWinnerRemote,
              detectedAtMs: 300,
            ));
      }

      expect(await watchUnacknowledgedConflictCount(db, groupId: 'g1').first, 1);
      expect(await watchUnacknowledgedConflictCount(db).first, 2);
      expect(await watchUnacknowledgedConflictEntityIds(db, 'g1').first, {'e-g1'});
      expect(await watchUnacknowledgedConflictEntityIds(db, 'g2').first, {'e-g2'});
    });

    test('12. 退团清理：该团回执按团清除，不影响其它团', () async {
      for (final g in const ['g1', 'g2']) {
        await db.into(db.conflictRecords).insert(ConflictRecordsCompanion.insert(
              id: 'c-$g',
              groupId: g,
              entity: 'expenses',
              entityId: 'e-$g',
              localUpdatedMs: 1,
              remoteUpdatedMs: 2,
              winner: kConflictWinnerRemote,
              detectedAtMs: 3,
            ));
      }
      await clearObservabilityOfGroup(db, 'g1');
      expect(await getConflicts(db, 'g1'), isEmpty);
      expect((await getConflicts(db, 'g2')).length, 1);
    });
  });
}
