// V2.7.1 S10 · N3：记账收件箱（先记后理 + 归类幂等 + pending 零污染）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/stats_calculator.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late String gid;
  late List<String> notified;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
    // 未挂载 SyncEngine 时 notifyWrite 为 no-op；注入 hook 捕获上行事件。
    notified = <String>[];
    SyncOutboxService.hook = (entity, rowId, op, updatedMs) =>
        notified.add('$entity:$rowId:$op');
    final g = await repo.addGroup('团', '📁');
    gid = g.id;
  });
  tearDown(() async {
    SyncOutboxService.hook = null;
    await db.close();
  });

  ExpensesCompanion draft(String gid, String memberId, int cents,
          {String title = '归类账单'}) =>
      ExpensesCompanion.insert(
        id: 'expense_${DateTime.now().microsecondsSinceEpoch}',
        groupId: gid,
        title: Value(title),
        amountCents: Value(cents),
        payersJson: Value('[{"memberId":"$memberId","cents":$cents}]'),
        sharesJson: Value('[{"memberId":"$memberId","cents":$cents}]'),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  group('S10 捕捉与暂存', () {
    test('捕捉一条 → inbox_items 出现 pending 行', () async {
      final id = await repo.captureInboxItem(gid: gid, amountCents: 2500, note: '打车');
      final item = (await repo.getInboxItem(id))!;
      expect(item.status, 'pending');
      expect(item.amountCents, 2500);
      expect(item.note, '打车');
      expect(item.source, 'manual');
      expect(item.convertedExpenseId, isNull);
      expect(notified, contains('inbox_items:$id:upsert'));
    });

    test('非法金额被拒绝', () async {
      await expectLater(
          repo.captureInboxItem(gid: gid, amountCents: 0), throwsA(isA<StateError>()));
      await expectLater(
          repo.captureInboxItem(gid: gid, amountCents: -5), throwsA(isA<StateError>()));
    });

    test('watchInboxItems 按捕捉时间降序', () async {
      final a = await repo.captureInboxItem(gid: gid, amountCents: 100, capturedAtMs: 1000);
      final b = await repo.captureInboxItem(gid: gid, amountCents: 200, capturedAtMs: 2000);
      final list = await repo.watchInboxItems(gid).first;
      expect(list.map((e) => e.id).toList(), [b, a]);
    });

    test('source 可标记 quick_action', () async {
      final id = await repo.captureInboxItem(
          gid: gid, amountCents: 300, source: 'quick_action');
      expect((await repo.getInboxItem(id))!.source, 'quick_action');
    });
  });

  group('S10 pending 零污染', () {
    test('pending 不进 expenses 表、不计入统计', () async {
      await repo.captureInboxItem(gid: gid, amountCents: 9999);
      expect(await db.select(db.expenses).get(), isEmpty);
      // 统计只读 expenses 表 → 自然为 0
      expect(totalCents(const <ExpenseRecord>[]), 0);
    });

    test('只有收件箱条目时 createSettlement 返回 null', () async {
      await repo.captureInboxItem(gid: gid, amountCents: 9999);
      expect(await repo.createSettlement(gid), isNull);
      expect(await db.select(db.settlements).get(), isEmpty);
    });

    test('未归类条目不进入备份快照（导出快照不含其金额）', () async {
      await repo.captureInboxItem(gid: gid, amountCents: 8888, note: '不该出现');
      final snap = await repo.exportGroupSnapshotJson(gid);
      expect(snap.contains('8888'), isFalse);
      expect(snap.contains('不该出现'), isFalse);
      final bytes = await repo.exportGroupBackupBytes(gid);
      expect(String.fromCharCodes(bytes).contains('8888'), isFalse);
    });

    test('未归类条目不进入 CSV（CSV 只由 expenses 构造）', () async {
      await repo.captureInboxItem(gid: gid, amountCents: 7777);
      expect(await db.select(db.expenses).get(), isEmpty);
    });
  });

  group('S10 归类转正', () {
    test('归类成功：账本恰好多一条、金额备注保真、条目转 converted', () async {
      final member = await repo.addMember(gid, '甲');
      final itemId = await repo.captureInboxItem(gid: gid, amountCents: 2500, note: '打车');
      final eid = await repo.convertInboxItem(
        itemId: itemId,
        expense: draft(gid, member, 2500, title: '打车'),
      );
      final expenses = await db.select(db.expenses).get();
      expect(expenses, hasLength(1));
      expect(expenses.single.id, eid);
      expect(expenses.single.amountCents, 2500);
      final item = (await repo.getInboxItem(itemId))!;
      expect(item.status, 'converted');
      expect(item.convertedExpenseId, eid);
      // 事务提交后：账单与条目都发了上行
      expect(notified.where((n) => n.startsWith('expenses:')).length, 1);
      expect(notified.contains('inbox_items:$itemId:upsert'), isTrue);
    });

    test('幂等：重复归类不重复生成账单', () async {
      final member = await repo.addMember(gid, '甲');
      final itemId = await repo.captureInboxItem(gid: gid, amountCents: 1500);
      final first = await repo.convertInboxItem(
          itemId: itemId, expense: draft(gid, member, 1500));
      final second = await repo.convertInboxItem(
          itemId: itemId, expense: draft(gid, member, 1500));
      expect(second, first, reason: '已转正 → 直接返回既有账单 id');
      expect(await db.select(db.expenses).get(), hasLength(1));
    });

    test('归类后计入统计（totalCents）', () async {
      final member = await repo.addMember(gid, '甲');
      final itemId = await repo.captureInboxItem(gid: gid, amountCents: 4200);
      await repo.convertInboxItem(
          itemId: itemId, expense: draft(gid, member, 4200));
      final rows = await db.select(db.expenses).get();
      final records = [
        for (final r in rows)
          ExpenseRecord(
            id: r.id,
            groupId: r.groupId,
            dateEpochDay: r.dateEpochDay,
            title: r.title,
            categoryKey: r.categoryKey,
            type: ExpenseType.normal,
            amountCents: r.amountCents,
            currency: r.currency,
            rate: r.rate,
            payers: const [],
            shares: const [],
          ),
      ];
      expect(totalCents(records), 4200);
    });

    test('条目不存在时报错', () async {
      await expectLater(
        repo.convertInboxItem(
            itemId: 'nope', expense: draft(gid, 'm', 100)),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('S10 批量与移除', () {
    test('批量归类逐条生成账单', () async {
      final member = await repo.addMember(gid, '甲');
      final a = await repo.captureInboxItem(gid: gid, amountCents: 100);
      final b = await repo.captureInboxItem(gid: gid, amountCents: 200);
      await repo.convertInboxItem(itemId: a, expense: draft(gid, member, 100));
      await repo.convertInboxItem(itemId: b, expense: draft(gid, member, 200));
      expect(await db.select(db.expenses).get(), hasLength(2));
    });

    test('pending 条目不可删除（必须先归类）', () async {
      final id = await repo.captureInboxItem(gid: gid, amountCents: 100);
      await expectLater(repo.deleteInboxItem(id),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('先归类'))));
      expect(await repo.getInboxItem(id), isNotNull);
    });

    test('converted 条目可删除并发行墓碑', () async {
      final member = await repo.addMember(gid, '甲');
      final id = await repo.captureInboxItem(gid: gid, amountCents: 100);
      await repo.convertInboxItem(itemId: id, expense: draft(gid, member, 100));
      await repo.deleteInboxItem(id);
      expect(await repo.getInboxItem(id), isNull);
      expect(notified.contains('inbox_items:$id:delete'), isTrue);
    });

    test('删团级联清理收件箱与公款池', () async {
      final member = await repo.addMember(gid, '甲');
      await repo.captureInboxItem(gid: gid, amountCents: 100);
      await repo.addFund(gid: gid, name: '池', managerMemberId: member, targetCents: null);
      await repo.deleteGroup(gid);
      expect(await db.select(db.inboxItems).get(), isEmpty);
      expect(await db.select(db.funds).get(), isEmpty);
    });
  });
}
