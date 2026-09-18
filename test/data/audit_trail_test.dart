// V2.7.1 S12.3：审计轨迹（仅本地 / 只记变更字段 / 批量只记一条汇总 / 2000 条裁剪）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/observability_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_models.dart';
import 'package:travel_assistant/export/backup_format.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() async {
    auditEnabled = true;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
  });

  tearDown(() async {
    auditEnabled = true;
    await db.close();
  });

  Future<List<AuditLog>> logsOf(String gid, {String? entity}) =>
      getAuditLogs(db, gid, entity: entity);

  Future<({Group group, String m1, String m2})> seed() async {
    final g = await repo.addGroup('旅行团', '🧭');
    final m1 = await repo.addMember(g.id, '张三');
    final m2 = await repo.addMember(g.id, '李四');
    return (group: g, m1: m1, m2: m2);
  }

  group('团 / 成员记录点', () {
    test('1. 团：新增 → 改名 → 归档 → 恢复，四类动作各留一条', () async {
      final s = await seed();
      await repo.updateGroup(s.group.id, '新名字', '🏝️');
      await repo.archiveGroup(s.group.id, true);
      await repo.archiveGroup(s.group.id, false);

      final logs = await logsOf(s.group.id, entity: AuditEntity.group);
      expect(logs.map((l) => l.action).toSet(),
          {AuditAction.create, AuditAction.update, AuditAction.archive, AuditAction.restore});
      final created = logs.firstWhere((l) => l.action == AuditAction.create);
      expect(decodeAuditFields(created.changedFieldsJson)['name'], '旅行团');
    });

    test('2. 成员：新增 / 改名 / 移除 / 删除', () async {
      final s = await seed();
      final m3 = await repo.addMember(s.group.id, '王五');
      await repo.renameMember(m3, '王五五');
      await repo.archiveMember(m3);
      await repo.deleteMember(m3);

      final logs = await logsOf(s.group.id, entity: AuditEntity.member)
        ..sort((a, b) => a.atMs.compareTo(b.atMs));
      expect(logs.where((l) => l.entityId == m3).map((l) => l.action).toList(),
          containsAll([AuditAction.create, AuditAction.update, AuditAction.archive, AuditAction.delete]));
      final renamed = logs.firstWhere(
          (l) => l.entityId == m3 && l.action == AuditAction.update);
      expect(decodeAuditFields(renamed.changedFieldsJson)['name'], '王五五');
    });

    test('3. 成员删除被拦截时不产生审计（只记真正发生的变更）', () async {
      final s = await seed();
      // m1 被账单引用 → deleteMember 抛错
      await repo.addExpense(ExpensesCompanion.insert(
        id: 'e1',
        groupId: s.group.id,
        dateEpochDay: const Value(1),
        title: const Value('午饭'),
        categoryKey: const Value('food'),
        amountCents: const Value(1000),
        payersJson: Value('[{"memberId":"${s.m1}","cents":1000}]'),
        sharesJson: Value('[{"memberId":"${s.m1}","cents":1000}]'),
        createdAt: 100,
      ));
      await expectLater(repo.deleteMember(s.m1), throwsStateError);
      final logs = await logsOf(s.group.id, entity: AuditEntity.member);
      expect(logs.where((l) => l.action == AuditAction.delete), isEmpty);
    });
  });

  group('账单 / 结算记录点', () {
    test('4. 账单：新增 / 编辑（只含变更字段）/ 删除', () async {
      final s = await seed();
      await repo.addExpense(ExpensesCompanion.insert(
        id: 'e1',
        groupId: s.group.id,
        dateEpochDay: const Value(1),
        title: const Value('午饭'),
        categoryKey: const Value('food'),
        amountCents: const Value(1000),
        createdAt: 100,
      ));
      await repo.updateExpense('e1', const ExpensesCompanion(title: Value('晚饭')));
      await repo.deleteExpense('e1');

      final logs = await logsOf(s.group.id, entity: AuditEntity.expense);
      expect(logs.length, 3);
      final created = logs.firstWhere((l) => l.action == AuditAction.create);
      expect(decodeAuditFields(created.changedFieldsJson)['title'], '午饭');

      final updated = logs.firstWhere((l) => l.action == AuditAction.update);
      final fields = decodeAuditFields(updated.changedFieldsJson);
      expect(fields.keys, ['title'], reason: '只记本次改动的字段，不是整行快照');
      expect(fields['title'], '晚饭');

      final deleted = logs.firstWhere((l) => l.action == AuditAction.delete);
      expect(decodeAuditFields(deleted.changedFieldsJson)['title'], '晚饭');
    });

    test('5. 结算：创建 → 转账确认 → 完成 → 撤销', () async {
      final s = await seed();
      await repo.addExpense(ExpensesCompanion.insert(
        id: 'e1',
        groupId: s.group.id,
        dateEpochDay: const Value(1),
        title: const Value('门票'),
        categoryKey: const Value('ticket'),
        amountCents: const Value(1000),
        payersJson: Value('[{"memberId":"${s.m1}","cents":1000}]'),
        sharesJson: Value(
            '[{"memberId":"${s.m1}","cents":500},{"memberId":"${s.m2}","cents":500}]'),
        createdAt: 100,
      ));
      final settle = await repo.createSettlement(s.group.id);
      expect(settle, isNotNull);
      await repo.markTransferDone(settle!.id, 0, true);
      await repo.completeSettlement(settle.id);
      await repo.undoLastSettlement(s.group.id);

      final actions = (await logsOf(s.group.id, entity: AuditEntity.settlement))
          .map((l) => l.action)
          .toList();
      expect(actions, containsAll([AuditAction.settle, AuditAction.update, AuditAction.complete, AuditAction.undo]));
      final settleLog = (await logsOf(s.group.id, entity: AuditEntity.settlement))
          .firstWhere((l) => l.action == AuditAction.settle);
      expect(decodeAuditFields(settleLog.changedFieldsJson)['strategy'], 'minTransfers');
    });
  });

  group('公款池 / 收件箱 / 批量导入', () {
    test('6. 公款池：新增 → 入金 → 出金 → 关闭', () async {
      final s = await seed();
      final fund = await repo.addFund(
          gid: s.group.id, name: '旅行基金', managerMemberId: s.m1, targetCents: 200000);
      await repo.addFundContribution(
          fundId: fund.id, contributions: {s.m1: 100000, s.m2: 100000});
      await repo.addFundExpense(
        fundId: fund.id,
        title: '景点门票',
        categoryKey: 'ticket',
        amountCents: 50000,
        shareMemberIds: [s.m1, s.m2],
      );
      await repo.closeFund(fund.id);

      final logs = await logsOf(s.group.id, entity: AuditEntity.fund);
      // getAuditLogs 按 atMs 倒序（最新在前）
      final actions = logs.map((l) => l.action).toList();
      expect(actions.first, AuditAction.close);
      expect(actions.last, AuditAction.create);
      expect(logs.length, 4);
      final contribution =
          logs.firstWhere((l) => decodeAuditFields(l.changedFieldsJson).containsKey('入金'));
      expect(decodeAuditFields(contribution.changedFieldsJson)['入金'], '200000');
    });

    test('7. 收件箱：归类转正记 convert；幂等重试不产生重复记录', () async {
      final s = await seed();
      final itemId = await repo.captureInboxItem(gid: s.group.id, amountCents: 8800);
      final expense = ExpensesCompanion.insert(
        id: 'e-cv',
        groupId: s.group.id,
        dateEpochDay: const Value(1),
        title: const Value('归类后的账单'),
        categoryKey: const Value('other'),
        amountCents: const Value(8800),
        createdAt: 100,
      );
      await repo.convertInboxItem(itemId: itemId, expense: expense);
      await repo.convertInboxItem(itemId: itemId, expense: expense); // 重试

      final logs = await logsOf(s.group.id, entity: AuditEntity.inbox);
      expect(logs.where((l) => l.action == AuditAction.convert).length, 1,
          reason: '幂等：已转正的重试走 early-return，不再写审计');
    });

    test('8. CSV 批量导入只记一条 import 汇总（不逐条记）', () async {
      final s = await seed();
      await repo.bulkImportExpenses(s.group.id, rows: [
        {
          'title': 'A',
          'amountCents': 1000,
          'dateEpochDay': 1,
          'categoryKey': 'food',
          'type': 'normal',
          'payerNames': ['张三'],
          'shareMode': 'equal',
          'shareNames': ['张三', '李四'],
          'currency': 'CNY',
          'rate': 1.0,
          'note': '',
        },
        {
          'title': 'B',
          'amountCents': 2000,
          'dateEpochDay': 2,
          'categoryKey': 'food',
          'type': 'normal',
          'payerNames': ['李四'],
          'shareMode': 'equal',
          'shareNames': ['张三', '李四'],
          'currency': 'CNY',
          'rate': 1.0,
          'note': '',
        },
      ]);

      final logs = await logsOf(s.group.id, entity: AuditEntity.backup);
      expect(logs.length, 1, reason: '批量导入只记一条汇总');
      final fields = decodeAuditFields(logs.first.changedFieldsJson);
      expect(fields['来源'], 'CSV');
      expect(fields['expenses'], '2');
    });
  });

  group('体积、开关与隐私边界', () {
    test('9. 单团超 2000 条按 atMs 裁剪最旧，业务数据不受影响', () async {
      final s = await seed();
      for (var i = 0; i < kAuditRetentionPerGroup + 5; i++) {
        await recordAudit(
          db,
          groupId: s.group.id,
          entity: AuditEntity.expense,
          entityId: 'e$i',
          action: AuditAction.create,
          changedFields: {'i': i},
          // 用递增时间戳确保裁剪顺序确定
        );
      }
      final logs = await getAuditLogs(db, s.group.id);
      expect(logs.length <= kAuditRetentionPerGroup + 1, isTrue,
          reason: '裁剪后不超过上限（容一次写入窗口）');
      expect((await repo.getMembers(s.group.id)).length, 2, reason: '业务数据完好');
      expect((await db.select(db.groups).get()).length, 1);
    });

    test('10. 关闭审计开关后停止写入', () async {
      final s = await seed();
      final before = (await getAuditLogs(db, s.group.id)).length;
      auditEnabled = false;
      await repo.renameMember(s.m1, '不该被记录');
      expect((await getAuditLogs(db, s.group.id)).length, before);
    });

    test('11. actor 缺失不崩：字段解码降级为空表', () async {
      final s = await seed();
      final logs = await getAuditLogs(db, s.group.id);
      expect(logs.first.actorMemberId, isNull, reason: '仓库层写审计不带 actor（无当前成员身份）');
      expect(decodeAuditFields('{坏 JSON'), isEmpty);
      expect(decodeAuditFields(''), isEmpty);
    });

    test('12. 变更字段做截断与限量（单条体积有界）', () {
      final long = 'x' * 500;
      final fields = <String, Object?>{
        'k0': long,
        for (var i = 1; i < 40; i++) 'k$i': i,
      };
      final encoded = encodeAuditFields(fields);
      final decoded = decodeAuditFields(encoded);
      expect(decoded.length <= 24, isTrue);
      expect(decoded['k0']!.length < long.length, isTrue);
      expect(decoded['k0']!.endsWith('…'), isTrue);
    });

    test('13. 不登记 SyncEntity，也不进备份包', () async {
      final s = await seed();
      expect(SyncEntity.values.map((e) => e.localKey),
          isNot(contains(anyOf('audit_logs', 'conflict_records'))));

      // 备份包（.tav）结构里不应出现审计/回执键。
      final bytes = await repo.exportGroupBackupBytes(s.group.id);
      final root = decodeBackup(bytes, acceptedMagics: [kGroupBackupMagic]);
      expect(root.keys, isNot(contains(anyOf('auditLogs', 'audit_logs'))));
      expect(root.keys, isNot(contains(anyOf('conflicts', 'conflict_records'))));
      expect((await getAuditLogs(db, s.group.id)).isNotEmpty, isTrue,
          reason: '本地确有审计行，但没被带进备份');
    });
  });
}
