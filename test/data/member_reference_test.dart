// V2.7.1 S2 · G1：成员引用治理（软删除 + 结构化引用检查，根除 LIKE 子串误报）。
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;
  late List<String> notified;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
    // 未挂载 SyncEngine 时 notifyWrite 是 no-op；测试注入 hook 捕获上行事件。
    notified = <String>[];
    SyncOutboxService.hook = (entity, rowId, op, updatedMs) {
      notified.add('$entity:$rowId:$op');
    };
  });
  tearDown(() async {
    SyncOutboxService.hook = null;
    await db.close();
  });

  final now = DateTime.now().millisecondsSinceEpoch;

  Future<void> seedGroup(String gid) =>
      db.into(db.groups).insert(GroupsCompanion.insert(
          id: gid, name: '团', createdAt: now, updatedAt: now));

  Future<String> seedMember(String mid, {String gid = 'g1'}) async {
    await db.into(db.members).insert(MembersCompanion.insert(
        id: mid, groupId: gid, name: '成员$mid', createdAt: now));
    return mid;
  }

  Future<void> seedExpense(String eid,
      {String? payersMember, String? sharesMember, String gid = 'g1'}) async {
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          id: eid,
          groupId: gid,
          title: Value('账单$eid'),
          amountCents: const Value(1000),
          payersJson: Value('[]'),
          sharesJson: Value(jsonEncode([
            if (sharesMember != null) {'memberId': sharesMember, 'cents': 1000},
          ])),
          createdAt: now,
        ));
  }

  group('G1 结构化引用判定', () {
    test('子串对抗：member_1 与 member_10 不误报', () async {
      await seedGroup('g1');
      await seedMember('member_1');
      await seedMember('member_10');
      await seedExpense('e1', sharesMember: 'member_10');

      expect(await repo.isMemberReferenced('member_10'), isTrue);
      expect(await repo.isMemberReferenced('member_1'), isFalse,
          reason: 'LIKE %member_1% 会命中 member_10 → 旧实现误报');
      expect(await repo.countMemberReferences('member_1'), 0);
      expect(await repo.countMemberReferences('member_10'), 1);
    });

    test('多笔引用计数正确', () async {
      await seedGroup('g1');
      await seedMember('m1');
      await seedExpense('e1', sharesMember: 'm1');
      await seedExpense('e2', sharesMember: 'm1');
      expect(await repo.countMemberReferences('m1'), 2);
    });

    test('JSON 损坏时保守拦截（宁可拦不可漏）', () async {
      await seedGroup('g1');
      await seedMember('m1');
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: 'bad',
            groupId: 'g1',
            title: const Value('脏数据'),
            payersJson: const Value('{不是数组'),
            createdAt: now,
          ));
      expect(await repo.isMemberReferenced('m1'), isTrue);
    });
  });

  group('G1 软删除与物理删除', () {
    test('无引用可物理删除并发行墓碑', () async {
      await seedGroup('g1');
      await seedMember('m1');
      await repo.deleteMember('m1');
      expect(await repo.getMembers('g1'), isEmpty);
      expect(notified.contains('members:m1:delete'), isTrue,
          reason: '物理删除必须发行墓碑');
    });

    test('有引用被拒绝且文案明确', () async {
      await seedGroup('g1');
      await seedMember('m1');
      await seedExpense('e1', sharesMember: 'm1');
      await expectLater(
        repo.deleteMember('m1'),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('移除成员（保留历史）'))),
      );
      expect(await repo.getMembers('g1'), hasLength(1), reason: '被拒绝后行仍在');
    });

    test('archiveMember 软删：行仍在、archived=true、发上行', () async {
      await seedGroup('g1');
      await seedMember('m1');
      await repo.archiveMember('m1');
      final m = (await repo.getMembers('g1')).single;
      expect(m.archived, isTrue);
      expect(notified.contains('members:m1:upsert'), isTrue,
          reason: '软删需上行整行');
    });

    test('软删成员仍参与历史净额（结算结果不变）', () async {
      await seedGroup('g1');
      await seedMember('a');
      await seedMember('b');
      // a 垫付 100，a/b 各摊 50 → b 欠 a 50
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: 'e1',
            groupId: 'g1',
            title: const Value('晚餐'),
            amountCents: const Value(10000),
            payersJson: const Value('[{"memberId":"a","cents":10000}]'),
            sharesJson:
                const Value('[{"memberId":"a","cents":5000},{"memberId":"b","cents":5000}]'),
            createdAt: now,
          ));
      await repo.archiveMember('b');
      // 归档后创建结算：b 仍应出现在方案里（其余额来自账单明细）
      final s = await repo.createSettlement('g1');
      expect(s, isNotNull);
      expect(s!.transfers, hasLength(1));
      expect(s.transfers.single.from, 'b');
      expect(s.transfers.single.to, 'a');
      expect(s.transfers.single.cents, 5000);
    });

    test('公款池管理人不可删除/归档（需先转移管理人）', () async {
      await seedGroup('g1');
      await seedMember('m1');
      await db.into(db.funds).insert(FundsCompanion.insert(
            id: 'f1',
            groupId: 'g1',
            name: '基金',
            managerMemberId: 'm1',
            createdAt: now,
            updatedAt: now,
          ));
      await expectLater(repo.deleteMember('m1'), throwsA(isA<StateError>()));
      await expectLater(repo.archiveMember('m1'), throwsA(isA<StateError>()));
    });
  });
}
