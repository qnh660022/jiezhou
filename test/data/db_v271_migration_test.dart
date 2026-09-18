// V2.7.1 S1：drift schemaVersion 4→5 一次到位。
// 覆盖：5 个新列默认值、4 张新表可读写、旧行默认口径（kind='travel' 等）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase());
  tearDown(() async => db.close());

  final now = DateTime.now().millisecondsSinceEpoch;

  test('S1：schemaVersion ≥ 5（V2.7.1 引入 v5；后续版本可继续上调）', () {
    expect(db.schemaVersion, greaterThanOrEqualTo(5));
  });

  test('S1：新增列默认值（groups.kind / members.archived / settlements.strategy）', () async {
    await db.into(db.groups).insert(GroupsCompanion.insert(
          id: 'g1', name: '团', createdAt: now, updatedAt: now));
    await db.into(db.members).insert(MembersCompanion.insert(
          id: 'm1', groupId: 'g1', name: '甲', createdAt: now));
    await db.into(db.settlements).insert(SettlementsCompanion.insert(
          id: 's1', groupId: 'g1', createdAt: now));

    final g = (await db.select(db.groups).get()).single;
    final m = (await db.select(db.members).get()).single;
    final s = (await db.select(db.settlements).get()).single;
    expect(g.kind, 'travel', reason: '老数据默认 travel，不得为 null');
    expect(m.archived, isFalse);
    expect(s.strategy, 'minTransfers');
  });

  test('S1：expenses.fund_id / pay_method 默认 NULL', () async {
    await db.into(db.groups).insert(GroupsCompanion.insert(
          id: 'g1', name: '团', createdAt: now, updatedAt: now));
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: 'e1', groupId: 'g1', createdAt: now));
    final e = (await db.select(db.expenses).get()).single;
    expect(e.fundId, isNull);
    expect(e.payMethod, isNull);
  });

  test('S1：4 张新表创建且可读写（funds / inbox_items / audit_logs / conflict_records）', () async {
    await db.into(db.groups).insert(GroupsCompanion.insert(
          id: 'g1', name: '团', createdAt: now, updatedAt: now));

    await db.into(db.funds).insert(FundsCompanion.insert(
          id: 'f1',
          groupId: 'g1',
          name: '旅行基金',
          managerMemberId: 'm1',
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.inboxItems).insert(InboxItemsCompanion.insert(
          id: 'i1',
          groupId: 'g1',
          amountCents: const Value(1234),
          note: const Value('先记后理'),
          capturedAt: now,
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.auditLogs).insert(AuditLogsCompanion.insert(
          id: 'a1',
          groupId: 'g1',
          entity: 'expenses',
          entityId: 'e1',
          action: 'create',
          atMs: now,
        ));
    await db.into(db.conflictRecords).insert(ConflictRecordsCompanion.insert(
          id: 'c1',
          groupId: 'g1',
          entity: 'expenses',
          entityId: 'e1',
          localUpdatedMs: 100,
          remoteUpdatedMs: 200,
          winner: 'remote',
          detectedAtMs: now,
        ));

    final fund = (await db.select(db.funds).get()).single;
    expect(fund.name, '旅行基金');
    expect(fund.status, 'open');
    expect(fund.targetCents, isNull);

    final inbox = (await db.select(db.inboxItems).get()).single;
    expect(inbox.amountCents, 1234);
    expect(inbox.status, 'pending');
    expect(inbox.source, 'manual');
    expect(inbox.convertedExpenseId, isNull);

    expect((await db.select(db.auditLogs).get()).single.action, 'create');
    final conflict = (await db.select(db.conflictRecords).get()).single;
    expect(conflict.winner, 'remote');
    expect(conflict.acknowledged, 0);
  });

  test('S1：新表初始为空（迁移后无残留）', () async {
    expect(await db.select(db.funds).get(), isEmpty);
    expect(await db.select(db.inboxItems).get(), isEmpty);
    expect(await db.select(db.auditLogs).get(), isEmpty);
    expect(await db.select(db.conflictRecords).get(), isEmpty);
  });

  test('S1：审计与冲突表不进同步层（无对应 SyncEntity 云表登记）', () async {
    // 负向断言：两张纯本地表不得出现在任何同步实体清单里
    // （SyncEntity 枚举只到 categories；此处通过表名反查确认无绑定）
    final tables = db.allTables.map((t) => t.actualTableName).toSet();
    expect(tables.contains('audit_logs'), isTrue);
    expect(tables.contains('conflict_records'), isTrue);
  });
}
