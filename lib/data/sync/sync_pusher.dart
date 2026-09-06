/// 上行 drain 主体（V2.6 §3.6 SPEC）。
///
/// 慢批量控制：单次 drain 最多 10 轮，每轮取 outbox 50 行（updatedMs 升序），
/// 按 entity 聚合后逐实体 upsert；成功删行、失败 attemptCount+1 并退避
/// （1s/4s/16s/…cap 5min）结束本次 drain。死信（attemptCount ≥ 8）不自动重试。
library;
import 'dart:async';

import 'db_access.dart';
import 'sync_codec.dart';
import 'sync_models.dart';
import 'sync_outbox_service.dart';
import 'sync_transport.dart';

class PushResult {
  PushResult({required this.pushed, required this.failed, this.error});
  final int pushed;
  final int failed;
  final Object? error;
  bool get ok => failed == 0;
}

class SyncPusher {
  SyncPusher(this.outbox, this.transport, this.accessor,
      {this.onFailure, this.onSuccess, this.isEntityEnabled});

  final SyncOutboxService outbox;
  final SyncTransport transport;
  final SyncDbAccessor accessor;

  /// 上云开关（§3.9）：行程/团关闭时其行不推云（从 outbox 移除，重开时全量重传）。
  /// 入参 (entity, rowId, 行数据)；返回 false = 跳过并丢弃该 outbox 行。
  bool Function(String entity, String rowId, Map<String, dynamic> row)? isEntityEnabled;

  /// 连续失败回调（引擎统计触发节流/通知）。
  final void Function(Object error)? onFailure;

  /// 从失败态首次成功回调（恢复通知）。
  final void Function()? onSuccess;

  static const int maxRounds = 10;
  static const int batchSize = 50;
  static const int deadLetterThreshold = 8;

  Duration _backoffFor(int attempts) {
    var seconds = 1;
    for (var i = 1; i < attempts; i++) {
      seconds *= 4;
      if (seconds >= 300) {
        seconds = 300;
        break;
      }
    }
    return Duration(seconds: seconds);
  }

  /// 装配一批：读本地最新值 → SyncEnvelope；本地行已删 → op=delete。
  Future<List<SyncEnvelope>> assemble(List<OutboxEntry> batch) async {
    final out = <SyncEnvelope>[];
    for (final e in batch) {
      final entity = SyncEntity.values.firstWhere((s) => s.name == e.entity);
      final row = await accessor.readBusinessRow(e.entity, e.rowId);
      out.add(SyncEnvelope(
        entity: entity,
        rowId: e.rowId,
        op: row == null ? SyncOutboxOp.delete : SyncOutboxOp.upsert,
        updatedMs: e.updatedMs, // 事件时点，不重读时钟
        row: row ?? const {},
      ));
    }
    return out;
  }

  Future<PushResult> drain() async {
    var pushed = 0;
    for (var round = 0; round < maxRounds; round++) {
      final batch = await outbox.selectBatch(limit: batchSize * 4);
      final retryable = batch.where((e) => e.attemptCount < deadLetterThreshold).toList();
      if (retryable.isEmpty) {
        return PushResult(pushed: pushed, failed: 0);
      }
      // 事件时点升序、批上限 50
      retryable.sort((a, b) => a.updatedMs.compareTo(b.updatedMs));
      var work = retryable.take(batchSize).toList();

      final envelopes = await assemble(work);
      // 开关关闸：被关实体行移出 outbox（重开时 toggle 路径全量重传），不入网
      final kept = <OutboxEntry>[];
      final keptEnvelopes = <SyncEnvelope>[];
      for (var i = 0; i < work.length; i++) {
        final env = envelopes[i];
        final enabled = isEntityEnabled?.call(work[i].entity, work[i].rowId, env.row) ?? true;
        if (enabled) {
          kept.add(work[i]);
          keptEnvelopes.add(env);
        } else {
          await outbox.delete([work[i]]);
        }
      }
      if (kept.isEmpty) continue; // 本批全被关闸，继续下一轮取件
      work = kept;
      // 按实体聚合多调（批内单实体 ≤50）
      final byEntity = <SyncEntity, List<SyncEnvelope>>{};
      for (final e in keptEnvelopes) {
        byEntity.putIfAbsent(e.entity, () => []).add(e);
      }
      try {
        for (final entry in byEntity.entries) {
          if (entry.value.isEmpty) continue;
          await transport.upsert(
            entry.key.cloudTable,
            entry.value.map((e) => e.toCloudJson()).toList(),
          );
        }
        await outbox.delete(work);
        pushed += work.length;
        onSuccess?.call();
      } catch (err) {
        await outbox.markAttempt(work);
        onFailure?.call(err);
        return PushResult(pushed: pushed, failed: work.length, error: err);
      }
    }
    return PushResult(pushed: pushed, failed: 0);
  }

  /// 退避等待（drain 失败后由引擎调度；期间 debounce/周期暂停）。
  Future<void> backoff(int attempts) => Future<void>.delayed(_backoffFor(attempts));
}
