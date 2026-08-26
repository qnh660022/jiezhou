/// 账单 DAO。
library;
import 'package:drift/drift.dart';
import '../tables.dart';
import '../database.dart';
part 'expenses_dao.g.dart';
@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase> with _$ExpensesDaoMixin {
  ExpensesDao(AppDatabase db) : super(db);
  Stream<List<Expense>> watchByGroup(String gid) => (select(expenses)..where((e)=>e.groupId.equals(gid))..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay),(e)=>OrderingTerm.desc(e.createdAt)])).watch();
  Stream<List<Expense>> watchOutstanding(String gid) => (select(expenses)..where((e)=>e.groupId.equals(gid)&e.settledRoundId.isNull())..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay)])).watch();
  Stream<List<Expense>> watchByTrip(String tid) => (select(expenses)..where((e)=>e.tripId.equals(tid))..orderBy([(e)=>OrderingTerm.desc(e.dateEpochDay)])).watch();
  Future<Expense?> getById(String id) => (select(expenses)..where((e)=>e.id.equals(id))).getSingleOrNull();
  Future<void> insertExp(ExpensesCompanion e) => into(expenses).insert(e);
  Future<void> updateExp(ExpensesCompanion e) => update(expenses).replace(e);
  Future<void> deleteExp(String id) async { await (delete(expenses)..where((e)=>e.id.equals(id))).go(); }
  Future<List<Expense>> getAllByGroup(String gid) => (select(expenses)..where((e)=>e.groupId.equals(gid))).get();
}
