/// AppDatabase：Drift 单例，schemaVersion=2。
library;

import 'package:drift/drift.dart';

import '../../platform/db_connection.dart';

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
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openDbConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2：Groups 增加团归档字段（结束团软标记）
          if (from < 2) {
            await m.addColumn(groups, groups.archived);
            await m.addColumn(groups, groups.archivedAtMs);
          }
        },
        beforeOpen: (details) async {
          // 分类是账单/统计的基础字典；历史库可能没有触发过种子，
          // 每次打开库时幂等补齐内置 7 类。
          await categoriesDao.initBuiltin();
        },
      );
}
