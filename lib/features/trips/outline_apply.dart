/// 大纲导入执行器（V2.7.2 S3/S6 接线）：宿主侧把导入计划落到仓库层。
///
/// 事务口径：覆盖整程在**单事务**内删旧卡（逐行墓碑收集，提交后补发）+ 建新卡；
/// 无天头行入想去池（S6：wishlist_items，落池即同步）。notifyWrite 一律在
/// 事务提交成功之后（防 drain 读到未提交行）。
library;
import 'package:drift/drift.dart';

import '../../core/uid.dart';
import '../../data/db/database.dart';
import '../../data/repo/trips_repo.dart';
import '../../data/repo/wishlist_repo.dart';
import '../../data/sync/sync_outbox_service.dart';
import '../../domain/outline_parser.dart';
import 'widgets/outline_panel.dart';

Future<OutlineImportReportView> applyOutlineImport({
  required TripsRepository tripsRepo,
  required WishlistRepository wishlistRepo,
  required Trip trip,
  required List<TripItem> items,
  required String text,
  required bool overwrite,
}) async {
  final db = tripsRepo.db;
  final parsed = parseOutline(text);
  final existing = <int, Set<String>>{};
  for (final it in items) {
    final idx = it.dateEpochDay - trip.startEpochDay + 1;
    (existing[idx] ??= {}).add(it.name.trim());
  }
  final plan = planOutlineImport(parsed, existingNamesByDay: existing);

  final now = DateTime.now().millisecondsSinceEpoch;
  final n = trip.endEpochDay < trip.startEpochDay
      ? 0
      : trip.endEpochDay - trip.startEpochDay + 1;
  final removedIds = <String>[];
  final newCardIds = <String>[];
  final poolIds = <String>[];

  await db.transaction(() async {
    // 覆盖整程：删全部旧卡（含备胎卡），关联账单摘链
    if (overwrite) {
      for (final it in items) {
        await (db.update(db.expenses)..where((e) => e.tripItemId.equals(it.id)))
            .write(const ExpensesCompanion(tripItemId: Value(null)));
        await (db.delete(db.tripItems)..where((t) => t.id.equals(it.id))).go();
        removedIds.add(it.id);
      }
    }
    // 建新卡：每末尾追加（sortOrder = 当天最大 +10 步长）
    for (final day in plan.cards) {
      final idx = day.dayIndex.clamp(1, n).toInt();
      final dayEpoch = trip.startEpochDay + idx - 1;
      final existingRows = await (db.select(db.tripItems)
            ..where((t) => t.tripId.equals(trip.id) & t.dateEpochDay.equals(dayEpoch)))
          .get();
      var order = 0;
      for (final r in existingRows) {
        if (r.sortOrder > order) order = r.sortOrder;
      }
      for (final item in day.items) {
        order += 10;
        final id = newId('item');
        await db.into(db.tripItems).insert(TripItemsCompanion.insert(
              id: id,
              tripId: trip.id,
              dateEpochDay: Value(dayEpoch),
              name: Value(item.name),
              type: const Value('attraction'),
              startTimeMin: Value(item.startTimeMin),
              durationMin: Value(item.durationMin),
              sortOrder: Value(order),
              createdAt: now,
              updatedAt: now,
            ));
        newCardIds.add(id);
      }
    }
    // 无天头行 → 想去池（S6 接线；条目无日期）
    for (final p in plan.toPool) {
      final id = newId('wish');
      await db.into(db.wishlistItems).insert(WishlistItemsCompanion.insert(
            id: id,
            tripId: trip.id,
            name: Value(p.name),
            durationMin: Value(p.durationMin),
            createdAt: now,
            updatedAt: now,
          ));
      poolIds.add(id);
    }
  });

  // 提交成功后逐行补发（先删后建的顺序保持 outbox 时序）
  for (final id in removedIds) {
    SyncOutboxService.notifyWrite('trip_items', id, op: 'delete');
  }
  for (final id in newCardIds) {
    SyncOutboxService.notifyWrite('trip_items', id);
  }
  for (final id in poolIds) {
    SyncOutboxService.notifyWrite('wishlist_items', id);
  }

  return OutlineImportReportView(
    added: newCardIds.length,
    skipped: plan.skippedDuplicates.length,
    invalid: plan.invalidLines,
    pooled: poolIds.length,
    removed: removedIds.length,
  );
}
