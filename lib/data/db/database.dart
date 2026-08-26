/// AppDatabase：Drift 单例，schemaVersion=1。
library;

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'daos/trips_dao.dart';
import 'daos/groups_dao.dart';
import 'daos/expenses_dao.dart';
import 'daos/checklist_dao.dart';
import 'daos/album_dao.dart';
import 'daos/categories_dao.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Groups, Members, Trips, TripItems, AlbumPhotos,
  ChecklistItems, Expenses, Settlements, Categories,
], daos: [
  TripsDao, GroupsDao, ExpensesDao,
  ChecklistDao, AlbumDao, CategoriesDao,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // 分类是账单/统计的基础字典；历史库可能没有触发过种子，
          // 每次打开库时幂等补齐内置 7 类。
          await categoriesDao.initBuiltin();
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'travel_v2.sqlite'));
    return NativeDatabase(file);
  });
}
