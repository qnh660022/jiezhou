/// AppDatabase：Drift 单例，schemaVersion=7（V2.8.1 分类子预算表；V2.7.2 想去池 2 表 + TripItems
/// guideRef/backupOf + Trips.pace）。
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
import 'daos/wishlist_dao.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Groups, Members, Trips, TripItems, AlbumPhotos,
  ChecklistItems, Expenses, Settlements, Categories,
  // V2.6 同步层：上行 outbox + 拉取游标 + 受邀端共享镜像（groups/members/expenses/settlements）
  SyncOutbox, SyncMeta,
  SharedGroups, SharedMembers, SharedExpenses, SharedSettlements,
  // V2.6.6.2 旅伴空间：空间/成员/动态 + 受邀协作行程镜像
  TravelSpaces, SpaceMembers, SpaceEvents, SharedTrips, SharedTripItems,
  // V2.7.1：公款池 / 记账收件箱 / 审计轨迹（仅本地）/ 冲突回执（仅本地）
  Funds, InboxItems, AuditLogs, ConflictRecords,
  // V2.7.2：想去池（行程内候选区）+ 受邀端镜像
  WishlistItems, SharedWishlistItems,
  // V2.8.1：分类子预算（团级，用户自选分类，上限 5）
  SubBudgets,
], daos: [
  TripsDao, GroupsDao, ExpensesDao,
  ChecklistDao, AlbumDao, CategoriesDao,
  WishlistDao,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openDbConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2：Groups 增加团归档字段（结束团软标记）
          if (from < 2) {
            await m.addColumn(groups, groups.archived);
            await m.addColumn(groups, groups.archivedAtMs);
          }
          // v2 -> v3：同步层 6 张表（outbox/meta + 共享镜像 4 件套）
          if (from < 3) {
            await m.createTable(syncOutbox);
            await m.createTable(syncMeta);
            await m.createTable(sharedGroups);
            await m.createTable(sharedMembers);
            await m.createTable(sharedExpenses);
            await m.createTable(sharedSettlements);
          }
          // v3 -> v4：V2.6.6.2 旅伴空间 5 表
          // （travel_spaces / space_members / space_events / shared_trips / shared_trip_items）
          if (from < 4) {
            await m.createTable(travelSpaces);
            await m.createTable(spaceMembers);
            await m.createTable(spaceEvents);
            await m.createTable(sharedTrips);
            await m.createTable(sharedTripItems);
          }
          // v4 -> v5：V2.7.1 一次到位（5 新列 + 4 新表），幂等可重复执行。
          // 老数据默认：kind='travel'、archived=false、fund_id/pay_method=NULL、
          // strategy='minTransfers'。
          if (from < 5) {
            await m.addColumn(groups, groups.kind);
            await m.addColumn(members, members.archived);
            await m.addColumn(expenses, expenses.fundId);
            await m.addColumn(expenses, expenses.payMethod);
            await m.addColumn(settlements, settlements.strategy);
            await m.createTable(funds);
            await m.createTable(inboxItems);
            await m.createTable(auditLogs);
            await m.createTable(conflictRecords);
          }
          // v5 -> v6：V2.7.2 一次到位（2 新表 + 5 新列），幂等可重复执行。
          // 老数据默认：pace='standard'、guide_ref/backup_of=NULL。
          if (from < 6) {
            await m.createTable(wishlistItems);
            await m.createTable(sharedWishlistItems);
            await m.addColumn(tripItems, tripItems.guideRef);
            await m.addColumn(tripItems, tripItems.backupOf);
            await m.addColumn(sharedTripItems, sharedTripItems.guideRef);
            await m.addColumn(sharedTripItems, sharedTripItems.backupOf);
            await m.addColumn(trips, trips.pace);
            // 镜像表与业务表列同构：pace 需一并补齐（否则受邀端下行构造缺列）。
            await m.addColumn(sharedTrips, sharedTrips.pace);
          }
          // v6 -> v7：V2.8.1 分类子预算表（幂等可重复执行）。
          if (from < 7) {
            await m.createTable(subBudgets);
          }
        },
        beforeOpen: (details) async {
          // 分类是账单/统计的基础字典；历史库可能没有触发过种子，
          // 每次打开库时幂等补齐内置 7 类。
          await categoriesDao.initBuiltin();
        },
      );
}
