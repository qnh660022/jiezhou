/// 下行增量拉取 + 合流落库（V2.6 §3.7 SPEC）。
///
/// 复合游标：`(updated_ms,id) > (:last,:lastId)` 字典序严格单调，杜绝同毫秒
/// 超 200 行时单列 `>` 漏行；每页成功即推进 sync_meta（断点续传），
/// 中途失败本页不入库、游标不推进。
library;
import '../db/database.dart';
import 'sync_meta_service.dart';
import 'sync_merger.dart';
import 'sync_models.dart';
import 'sync_transport.dart';

class PullResult {
  PullResult({required this.pulled, this.error});
  final int pulled;
  final Object? error;
  bool get ok => error == null;
}

class SyncPuller {
  SyncPuller(this.db, this.transport, this.meta, this.merger,
      {this.pageLimit = 200});

  final AppDatabase db;
  final SyncTransport transport;
  final SyncMetaService meta;
  final SyncMerger merger;
  final int pageLimit;

  /// 单实体增量拉取直至追平。
  Future<PullResult> pull(SyncEntity entity) async {
    var last = await meta.lastPulledMs(entity.name);
    var lastId = '';
    var total = 0;
    try {
      while (true) {
        final rows = await transport.fetch(entity.cloudTable,
            updatedMsAfter: last, idAfter: lastId, limit: pageLimit);
        if (rows.isEmpty) break;
        // 本页事务：中途失败整页回滚、游标不推进，下轮断点续传
        await db.transaction(() async {
          for (final row in rows) {
            await merger.mergeRow(entity, row);
          }
        });
        total += rows.length;
        final lastRow = rows.last;
        last = (lastRow['updated_ms'] as num?)?.toInt() ?? last;
        lastId = (lastRow[entity.idColumn] as String?) ?? lastId;
        await meta.advance(entity.name, last); // 每页成功即推进
        if (rows.length < pageLimit) break;
      }
      return PullResult(pulled: total);
    } catch (err) {
      return PullResult(pulled: total, error: err);
    }
  }

  /// 一轮完整拉取（固定顺序：groups→members→expenses→settlements→trips→tripItems→categories）。
  Future<PullResult> pullAll({List<SyncEntity>? entities}) async {
    var total = 0;
    for (final entity in entities ?? SyncEntity.pullOrder) {
      final r = await pull(entity);
      if (!r.ok) return PullResult(pulled: total, error: r.error);
      total += r.pulled;
    }
    return PullResult(pulled: total);
  }
}
