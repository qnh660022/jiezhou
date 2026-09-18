// V2.7.1 S8 · N1：公款池（入金 prepay + 出金 normal + 派生余额 + 结算自洽）。
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/domain/fund_calculator.dart';
import 'package:travel_assistant/domain/models.dart';
import 'package:travel_assistant/domain/settle_engine.dart';
import 'package:travel_assistant/domain/stats_calculator.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
  });
  tearDown(() async => db.close());

  Future<({String gid, List<String> members, String fundId})> seedPool() async {
    final g = await repo.addGroup('团', '📁');
    final ids = <String>[];
    for (var i = 0; i < 4; i++) {
      ids.add(await repo.addMember(g.id, '成员$i'));
    }
    final fund = await repo.addFund(
        gid: g.id, name: '旅行基金', managerMemberId: ids.first, targetCents: 400000);
    return (gid: g.id, members: ids, fundId: fund.id);
  }

  Future<List<ExpenseRecord>> recordsOf(String gid) async {
    final rows = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).get();
    return [
      for (final r in rows)
        ExpenseRecord(
          id: r.id,
          groupId: r.groupId,
          dateEpochDay: r.dateEpochDay,
          title: r.title,
          categoryKey: r.categoryKey,
          type: ExpenseType.values.firstWhere((t) => t.name == r.type,
              orElse: () => ExpenseType.normal),
          amountCents: r.amountCents,
          currency: r.currency,
          rate: r.rate,
          payers: [
            for (final p in (jsonDecode(r.payersJson) as List))
              ShareEntry(
                  memberId: p['memberId'] as String, cents: (p['cents'] as num).toInt()),
          ],
          shares: [
            for (final s in (jsonDecode(r.sharesJson) as List))
              ShareEntry(
                  memberId: s['memberId'] as String, cents: (s['cents'] as num).toInt()),
          ],
          fundId: r.fundId,
          settledRoundId: r.settledRoundId,
        ),
    ];
  }

  group('S8 建模红线', () {
    test('入金：payers=缴款人 / shares=管理人（总额）', () async {
      final s = await seedPool();
      final eid = await repo.addFundContribution(
          fundId: s.fundId, contributions: {for (final m in s.members) m: 100000});
      final row =
          (await (db.select(db.expenses)..where((e) => e.id.equals(eid))).get()).single;
      expect(row.type, 'prepay');
      expect(row.fundId, s.fundId);
      final payers = (jsonDecode(row.payersJson) as List).cast<Map>();
      final shares = (jsonDecode(row.sharesJson) as List).cast<Map>();
      expect(payers.map((p) => p['memberId']).toSet(), s.members.toSet());
      expect(shares, hasLength(1));
      expect(shares.single['memberId'], s.members.first);
      expect(shares.single['cents'], 400000);
    });

    test('出金：payer=管理人 / shares 按分摊模式', () async {
      final s = await seedPool();
      final eid = await repo.addFundExpense(
        fundId: s.fundId,
        title: '晚餐',
        categoryKey: 'food',
        amountCents: 30000,
        shareMemberIds: s.members,
      );
      final row =
          (await (db.select(db.expenses)..where((e) => e.id.equals(eid))).get()).single;
      expect(row.type, 'normal');
      final payers = (jsonDecode(row.payersJson) as List).cast<Map>();
      expect(payers.single['memberId'], s.members.first);
      expect(payers.single['cents'], 30000);
    });

    test('对抗：管理人也在缴款名单时 shares 仍只归管理人（净额自洽）', () async {
      final s = await seedPool();
      await repo.addFundContribution(
          fundId: s.fundId, contributions: {for (final m in s.members) m: 100000});
      final recs = await recordsOf(s.gid);
      final balances = computeNetBalances(
        [for (final m in s.members) MemberRecord(id: m, name: m)],
        recs,
      );
      expect(balances[s.members.first], -300000);
      expect(validatePlan(minTransferPlan(balances), balances), isTrue);
    });
  });

  group('S8 池余额与结算', () {
    test('4 人各入金 1000、支出 300 → 余额 3700；方案「管理人退每人 925」', () async {
      final s = await seedPool();
      await repo.addFundContribution(
          fundId: s.fundId, contributions: {for (final m in s.members) m: 100000});
      await repo.addFundExpense(
        fundId: s.fundId,
        title: '晚餐',
        categoryKey: 'food',
        amountCents: 30000,
        shareMemberIds: s.members,
      );

      final recs = await recordsOf(s.gid);
      expect(fundBalanceCents(s.fundId, recs), 370000);
      expect(fundContributedTotal(s.fundId, recs), 400000);
      expect(fundSpentTotal(s.fundId, recs), 30000);

      final settlement = await repo.createSettlement(s.gid);
      expect(settlement, isNotNull);
      final transfers = settlement!.transfers;
      expect(transfers, hasLength(3));
      // 管理人（收款总额 − 缴款）为净欠款方 → 由管理人退给其余 3 人各 925。
      for (final t in transfers) {
        expect(t.from, s.members.first);
        expect(s.members.skip(1), contains(t.to));
        expect(t.cents, 92500);
      }
      final balances = computeNetBalances(
          [for (final m in s.members) MemberRecord(id: m, name: m)], recs);
      expect(
          validatePlan([
            for (final t in transfers)
              TransferPlan(from: t.from, to: t.to, cents: t.cents)
          ], balances),
          isTrue);
    });

    test('入金不计入总支出统计；出金计入', () async {
      final s = await seedPool();
      await repo.addFundContribution(
          fundId: s.fundId, contributions: {s.members.first: 100000});
      await repo.addFundExpense(
        fundId: s.fundId,
        title: '门票',
        categoryKey: 'ticket',
        amountCents: 12000,
        shareMemberIds: s.members,
      );
      final recs = await recordsOf(s.gid);
      expect(totalCents(recs), 12000);
      expect(prepayTotalCents(recs), 100000);
    });

    test('结算完成后余额只按未入账账单派生（趋近 0）', () async {
      final s = await seedPool();
      await repo.addFundContribution(
          fundId: s.fundId, contributions: {for (final m in s.members) m: 100000});
      expect(fundBalanceCents(s.fundId, await recordsOf(s.gid)), 400000);

      final settlement = await repo.createSettlement(s.gid);
      await repo.completeSettlement(settlement!.id);
      final after = await recordsOf(s.gid);
      expect(after.every((e) => e.settledRoundId != null), isTrue);
      expect(fundBalanceCents(s.fundId, after), 0);
    });

    test('fund_id 非空账单随备份带出并可还原', () async {
      final s = await seedPool();
      await repo.addFundContribution(
          fundId: s.fundId, contributions: {s.members.first: 50000});
      final bytes = await repo.exportGroupBackupBytes(s.gid);
      await repo.importGroupBackupBytes(bytes);
      final all = await db.select(db.expenses).get();
      // 原账单 + 导入副本；副本也必须带 fund_id
      expect(all.where((e) => e.fundId != null).length, greaterThanOrEqualTo(2));
    });
  });

  group('S8 池生命周期约束', () {
    test('转移管理人：历史账单不变，后续指向新管理人', () async {
      final s = await seedPool();
      final eid = await repo.addFundExpense(
        fundId: s.fundId,
        title: '午餐',
        categoryKey: 'food',
        amountCents: 8000,
        shareMemberIds: s.members,
      );
      await repo.updateFund(s.fundId, managerMemberId: s.members[1]);
      final row =
          (await (db.select(db.expenses)..where((e) => e.id.equals(eid))).get()).single;
      expect((jsonDecode(row.payersJson) as List).cast<Map>().single['memberId'],
          s.members.first);
      expect((await repo.getFund(s.fundId))!.managerMemberId, s.members[1]);

      final eid2 = await repo.addFundExpense(
        fundId: s.fundId,
        title: '晚餐',
        categoryKey: 'food',
        amountCents: 9000,
        shareMemberIds: s.members,
      );
      final row2 =
          (await (db.select(db.expenses)..where((e) => e.id.equals(eid2))).get()).single;
      expect((jsonDecode(row2.payersJson) as List).first['memberId'], s.members[1]);
    });

    test('池关闭后新增出入金被拒绝', () async {
      final s = await seedPool();
      await repo.closeFund(s.fundId);
      await expectLater(
        repo.addFundContribution(
            fundId: s.fundId, contributions: {s.members.first: 1000}),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repo.addFundExpense(
          fundId: s.fundId,
          title: 'x',
          categoryKey: 'food',
          amountCents: 100,
          shareMemberIds: s.members,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('归档管理人被拒绝且提示先转移', () async {
      final s = await seedPool();
      await expectLater(
        repo.archiveMember(s.members.first),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('转移管理人'))),
      );
    });

    test('管理人为已移除成员时出入金被拒绝（脏数据防御）', () async {
      final s = await seedPool();
      await repo.archiveMember(s.members[1]);
      await (db.update(db.funds)..where((f) => f.id.equals(s.fundId)))
          .write(FundsCompanion(managerMemberId: Value(s.members[1])));
      await expectLater(
        repo.addFundExpense(
          fundId: s.fundId,
          title: 'x',
          categoryKey: 'food',
          amountCents: 100,
          shareMemberIds: s.members,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('S8 池创建校验', () {
    test('管理人必须是本团未移除成员', () async {
      final s = await seedPool();
      await repo.archiveMember(s.members[1]);
      await expectLater(
        repo.addFund(
            gid: s.gid, name: 'x', managerMemberId: s.members[1], targetCents: null),
        throwsA(isA<StateError>()),
      );
      final other = await repo.addGroup('别的团', '📁');
      await expectLater(
        repo.addFund(
            gid: other.id, name: 'x', managerMemberId: s.members[0], targetCents: null),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repo.addFund(gid: s.gid, name: 'x', managerMemberId: '不存在', targetCents: null),
        throwsA(isA<StateError>()),
      );
    });

    test('getOpenFund / fundExpenses 行为', () async {
      final s = await seedPool();
      expect((await repo.getOpenFund(s.gid))?.id, s.fundId);
      await repo.addFundContribution(
          fundId: s.fundId, contributions: {s.members.first: 1000});
      expect(await repo.fundExpenses(s.fundId), hasLength(1));
      await repo.closeFund(s.fundId);
      expect(await repo.getOpenFund(s.gid), isNull);
    });

    test('池名空串回退默认名；计划金额可空', () async {
      final s = await seedPool();
      final f = await repo.addFund(
          gid: s.gid, name: '  ', managerMemberId: s.members.first, targetCents: null);
      expect(f.name, '旅行基金');
      expect(f.targetCents, isNull);
      expect(f.status, 'open');
    });

    test('入金全 0 / 出金金额非法被拒绝', () async {
      final s = await seedPool();
      await expectLater(
        repo.addFundContribution(fundId: s.fundId, contributions: {s.members.first: 0}),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repo.addFundExpense(
          fundId: s.fundId,
          title: 'x',
          categoryKey: 'food',
          amountCents: 0,
          shareMemberIds: s.members,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repo.addFundExpense(
          fundId: s.fundId,
          title: 'x',
          categoryKey: 'food',
          amountCents: 100,
          shareMemberIds: const [],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('S8 派生纯函数', () {
    test('分类聚合 / 缴款人聚合 / 阈值', () async {
      final s = await seedPool();
      await repo.addFundContribution(
          fundId: s.fundId,
          contributions: {s.members[0]: 30000, s.members[1]: 20000});
      await repo.addFundExpense(
        fundId: s.fundId,
        title: '晚餐',
        categoryKey: 'food',
        amountCents: 10000,
        shareMemberIds: s.members,
      );
      final recs = await recordsOf(s.gid);
      expect(fundSpentByCategory(s.fundId, recs), {'food': 10000});
      expect(fundContributionByMember(s.fundId, recs),
          {s.members[0]: 30000, s.members[1]: 20000});
      expect(fundContributorCount(s.fundId, recs), 2);
      expect(fundBelowThreshold(1000, 100000), isTrue);
      expect(fundBelowThreshold(50000, 100000), isFalse);
      expect(fundBelowThreshold(1, null), isFalse);
    });
  });
}
