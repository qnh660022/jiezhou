// V2.7.1 S4 · B2：个人账本（kind=personal）语义分流。
// 覆盖：owner 即唯一成员 / 结算短路 / kind 保真与降级 / 未知 kind 不崩溃。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/ledger_repo.dart';
import 'package:travel_assistant/data/repo/prefs_repo.dart';
import 'package:travel_assistant/domain/group_backup.dart';
import 'package:travel_assistant/features/ledger/ledger_models.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase();
    repo = LedgerRepository(db, PrefsRepository());
    LedgerRepository.onUnknownKind = null;
  });
  tearDown(() async {
    LedgerRepository.onUnknownKind = null;
    await db.close();
  });

  group('S4 领域与视图分流', () {
    test('kind 未知值按 travel 处理（isPersonal=false，不崩溃）', () {
      const view = LedgerGroupView(
          id: 'g', name: 'n', icon: '📁', budgetEnabled: false, kind: 'xxx');
      expect(view.isPersonal, isFalse);
      expect(
        const LedgerGroupView(
                id: 'g', name: 'n', icon: '📁', budgetEnabled: false, kind: 'personal')
            .isPersonal,
        isTrue,
      );
    });
  });

  group('S4 新建账本分流', () {
    test('个人账本 owner 即唯一成员（名为「我」）', () async {
      final g = await repo.addGroup('我的日常', '📁', kind: 'personal');
      expect(g.kind, 'personal');
      final members = await repo.getMembers(g.id);
      expect(members, hasLength(1));
      expect(members.single.name, '我');
      expect(members.single.archived, isFalse);
    });

    test('旅行账本不自动建成员，kind 默认 travel', () async {
      final g = await repo.addGroup('大理四人组', '🏝️');
      expect(g.kind, 'travel');
      expect(await repo.getMembers(g.id), isEmpty);
    });

    test('loan 保留（解析层预留），未知值降级 travel 并回调日志', () async {
      final loan = await repo.addGroup('借贷预留', '📁', kind: 'loan');
      expect(loan.kind, 'loan', reason: 'loan 仅解析层预留，写入不被篡改');

      final logged = <String>[];
      LedgerRepository.onUnknownKind = logged.add;
      final weird = await repo.addGroup('怪类型', '📁', kind: 'weird');
      expect(weird.kind, 'travel');
      expect(logged, isNotEmpty);
    });

    test('重命名/换图标不改变 kind（个人账本仍为 personal）', () async {
      final g = await repo.addGroup('我的日常', '📁', kind: 'personal');
      await repo.updateGroup(g.id, '新名字', '🎒');
      final after = (await repo.getGroup(g.id))!;
      expect(after.name, '新名字');
      expect(after.kind, 'personal');
    });
  });

  group('S4 结算短路', () {
    test('createSettlement 在 personal 下返回 null 且不产生结算轮', () async {
      final g = await repo.addGroup('个人', '📁', kind: 'personal');
      final member = (await repo.getMembers(g.id)).single;
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: 'e1',
            groupId: g.id,
            title: const Value('早餐'),
            amountCents: const Value(1000),
            payersJson: Value('[{"memberId":"${member.id}","cents":1000}]'),
            sharesJson: Value('[{"memberId":"${member.id}","cents":1000}]'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));
      expect(await repo.createSettlement(g.id), isNull);
      expect(await db.select(db.settlements).get(), isEmpty);
    });

    test('travel 账本仍可正常结算（回归）', () async {
      final g = await repo.addGroup('团', '📁');
      final a = await repo.addMember(g.id, 'A');
      final b = await repo.addMember(g.id, 'B');
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: 'e1',
            groupId: g.id,
            title: const Value('晚餐'),
            amountCents: const Value(10000),
            payersJson: Value('[{"memberId":"$a","cents":10000}]'),
            sharesJson:
                Value('[{"memberId":"$a","cents":5000},{"memberId":"$b","cents":5000}]'),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));
      final s = await repo.createSettlement(g.id);
      expect(s, isNotNull);
      expect(s!.transfers.single.from, b);
      expect(s.strategy, 'minTransfers');
    });
  });

  group('S4 备份/快照 kind 保真', () {
    test('老备份（无 kind）解析后默认 travel，不报错', () {
      final backup = parseGroupBackupMap(<String, dynamic>{
        'app': kBackupApp,
        'version': 1,
        'group': {'id': 'g1', 'name': '老团'},
        'members': const [],
        'expenses': const [],
        'settlements': const [],
        'trips': const [],
        'customCategories': const [],
      });
      expect(backup.group['kind'], 'travel');
    });

    test('个人账本 .tav 导出再导入：kind 保真', () async {
      final g = await repo.addGroup('我的日常', '📁', kind: 'personal');
      final bytes = await repo.exportGroupBackupBytes(g.id);
      final report = await repo.importGroupBackupBytes(bytes);
      expect(report.groups, 1);
      final imported = (await db.select(db.groups).get())
          .where((x) => x.id != g.id)
          .toList();
      expect(imported, hasLength(1));
      expect(imported.single.kind, 'personal');
    });

    test('旧 JSON 导入（无 kind）落库为 travel', () async {
      final json = '{"group":{"name":"老团","icon":"📁"},"members":[],"expenses":[]}';
      await repo.importGroupJson(json);
      final imported = (await db.select(db.groups).get()).single;
      expect(imported.kind, 'travel');
    });
  });
}
