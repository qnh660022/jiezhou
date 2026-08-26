/// 团+成员 DAO。
library;
import 'package:drift/drift.dart';
import '../tables.dart';
import '../database.dart';
part 'groups_dao.g.dart';
@DriftAccessor(tables: [Groups, Members])
class GroupsDao extends DatabaseAccessor<AppDatabase> with _$GroupsDaoMixin {
  GroupsDao(AppDatabase db) : super(db);
  Stream<List<Group>> watchAll() => (select(groups)..orderBy([(g)=>OrderingTerm.desc(g.createdAt)])).watch();
  Future<Group?> getById(String id) => (select(groups)..where((g)=>g.id.equals(id))).getSingleOrNull();
  Future<void> insertGroup(GroupsCompanion g) => into(groups).insert(g);
  Future<void> updateGroup(GroupsCompanion g) => update(groups).replace(g);
  Future<void> deleteGroup(String id) async {
    await (delete(members)..where((m)=>m.groupId.equals(id))).go();
    await (delete(groups)..where((g)=>g.id.equals(id))).go();
  }
  Stream<List<Member>> watchMembers(String gid) => (select(members)..where((m)=>m.groupId.equals(gid))..orderBy([(m)=>OrderingTerm.asc(m.createdAt)])).watch();
  Future<List<Member>> getMembers(String gid) => (select(members)..where((m)=>m.groupId.equals(gid))).get();
  Future<Member?> getMember(String id) => (select(members)..where((m)=>m.id.equals(id))).getSingleOrNull();
  Future<void> insertMember(MembersCompanion m) async {
    final count = await (selectOnly(members)..where(members.groupId.equals(m.groupId.value))..addColumns([members.id.count()])).getSingle();
    final idx = (count.read<int>(members.id.count()) ?? 0) % 8;
    await into(members).insert(m.copyWith(colorIndex: Value(idx)));
  }
  Future<void> updateMember(MembersCompanion m) => update(members).replace(m);
  Future<void> deleteMember(String id) async { await (delete(members)..where((m)=>m.id.equals(id))).go(); }
}
