/// 同步引擎：触发器编排（debounce / 周期 / 手动 / 冷启动）+ 全局互斥锁 +
/// 失败节流 + 引导闸 + 状态机（V2.6 §3.5.4 / §3.6 / §3.8 / §3.10 / §3.12）。
library;
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import 'db_access.dart';
import 'sync_merger.dart';
import 'sync_meta_service.dart';
import 'sync_models.dart';
import 'sync_outbox_service.dart';
import 'sync_puller.dart';
import 'sync_pusher.dart';
import 'sync_transport.dart';

/// 同步频率档位（prefs `sync.freq`）：economy 60s / standard 15s（默认）/ realtime 5s。
enum SyncFreq { economy, standard, realtime }

extension SyncFreqX on SyncFreq {
  int get intervalSeconds => switch (this) {
        SyncFreq.economy => 60,
        SyncFreq.standard => 15,
        SyncFreq.realtime => 5,
      };
  String get key => name;
  static SyncFreq fromKey(String? k) => SyncFreq.values
      .firstWhere((f) => f.name == k, orElse: () => SyncFreq.standard);
}

class SyncEngine {
  SyncEngine._(this.db, this.transport, this.prefs);

  static SyncEngine? _instance;

  final AppDatabase db;
  final SyncTransport transport;
  final SharedPreferences prefs;

  late final SyncOutboxService outbox;
  late final SyncMetaService metaService;
  late final SyncMerger merger;
  late final SyncPusher pusher;
  late final SyncPuller puller;

  Timer? _debounce;
  Timer? _periodic;
  Future<void>? _lock;
  bool _throttled = false;
  DateTime? _throttleUntil;
  int _consecutivePullFailures = 0;
  int _consecutivePushFailures = 0;
  bool _lastPushFailed = false;
  bool _background = false;
  bool _started = false;

  Set<String> _collabGroupIds = {};
  final Map<String, String> _sharedOwners = {}; // groupId -> ownerUserId（在线直写保 owner 用）
  String? _userId;

  // ===== 通知/状态回调（由 UI 层挂接） =====
  void Function(String message)? onSyncFailed;
  void Function()? onSyncRecovered;
  final StreamController<SyncStatus> _statusCtl =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusCtl.stream;
  SyncStatus _status = const SyncStatus(kind: SyncStatusKind.signedOut);
  SyncStatus get status => _status;
  void Function(SyncStatus)? onStatusChanged;

  static SyncEngine? instance() => _instance;

  /// 初始化并挂载全局单例（配置有效且用户可能登录时才调）。
  static SyncEngine init(AppDatabase db, SyncTransport transport, SharedPreferences prefs) {
    final engine = SyncEngine._(db, transport, prefs);
    engine.outbox = SyncOutboxService(db);
    engine.metaService = SyncMetaService(db);
    engine.merger = SyncMerger(db, engine.outbox);
    engine.pusher = SyncPusher(
      engine.outbox,
      transport,
      SyncDbAccessor(db),
      onFailure: (_) => engine._onPushFailure(),
      onSuccess: () => engine._onPushSuccess(),
    );
    engine.puller = SyncPuller(db, transport, engine.metaService, engine.merger);
    // 上云开关闸门（§3.9）：行程/团关闭时其行不推云
    engine.pusher.isEntityEnabled = (entity, rowId, row) {
      switch (entity) {
        case 'trips':
          return engine.tripSyncEnabled(rowId);
        case 'trip_items':
          final tid = row['trip_id'];
          return tid is String ? engine.tripSyncEnabled(tid) : true;
        case 'groups':
          return engine.groupSyncEnabled(rowId);
        case 'members':
        case 'expenses':
        case 'settlements':
          final gid = row['group_id'];
          return gid is String ? engine.groupSyncEnabled(gid) : true;
        default:
          return true; // categories 随账号自动同步
      }
    };
    // 仓库层写路径 → outbox 入队 + debounce
    SyncOutboxService.hook = (entity, rowId, op, updatedMs) {
      engine.outbox.enqueue(entity, rowId, op, updatedMs);
      engine._scheduleDebounce();
    };
    _instance = engine;
    return engine;
  }

  static void detach() {
    SyncOutboxService.hook = null;
    _instance?._stopPeriodic();
    _instance = null;
  }

  // ===== 生命周期 =====

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _userId = transport.currentUserId;
    await _refreshCollabContext();
    _updateStatus();
    _startPeriodic();
    // 冷启动：登录态恢复后首帧一次 pull
    unawaited(syncNow(push: false));
  }

  void stop() {
    _started = false;
    _stopPeriodic();
    _debounce?.cancel();
  }

  void setForeground(bool foreground) {
    _background = !foreground;
    if (foreground && _started && !_throttled) {
      // 回前台立即补一轮 pull
      unawaited(syncNow(push: false));
      _startPeriodic();
    }
    if (!foreground) _stopPeriodic();
  }

  SyncFreq get freq => SyncFreqX.fromKey(prefs.getString('sync.freq'));

  Future<void> setFreq(SyncFreq f) async {
    await prefs.setString('sync.freq', f.key);
    _startPeriodic();
  }

  void _startPeriodic() {
    _stopPeriodic();
    if (_background || !_started) return;
    _periodic = Timer.periodic(Duration(seconds: freq.intervalSeconds), (_) {
      if (!_throttled) unawaited(syncNow(push: false));
    });
  }

  void _stopPeriodic() {
    _periodic?.cancel();
    _periodic = null;
  }

  void _scheduleDebounce() {
    if (_background || _throttled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      unawaited(_guarded(() async {
        if (!_bootstrapGateOpen()) return;
        await pusher.drain();
      }));
    });
  }

  // ===== 引导闸（§3.10）：未确认归属的账号禁止上行 =====

  bool _bootstrapGateOpen() {
    final uid = transport.currentUserId;
    if (uid == null) return false;
    return prefs.getBool('sync_bootstrapped_$uid') ?? false;
  }

  /// 登录成功/引导确认后调用：全量入队（所有实体，开关关的实体由 toggle 层跳过）。
  Future<void> bootstrapUploadAll() async {
    final uid = transport.currentUserId;
    if (uid == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entity in const [
      'groups', 'members', 'expenses', 'settlements',
      'trips', 'trip_items', 'categories',
    ]) {
      if (!_entitySyncEnabled(entity)) continue;
      await outbox.enqueueEntityAll(entity, now);
    }
    await prefs.setBool('sync_bootstrapped_$uid', true);
    await syncNow();
  }

  /// 手动「开始上传本地数据」（同步中心）。
  Future<void> manualStartUpload() => bootstrapUploadAll();

  // ===== 上云开关（§3.9）：prefs sync_enabled_trip_<id> / sync_enabled_group_<id> =====

  bool _entitySyncEnabled(String entity) {
    // categories 无开关（随账号自动同步）；trip_items 随属主行程；members/expenses/settlements 随团。
    return true;
  }

  bool tripSyncEnabled(String tripId) =>
      prefs.getBool('sync_enabled_trip_$tripId') ?? true;

  bool groupSyncEnabled(String groupId) =>
      prefs.getBool('sync_enabled_group_$groupId') ?? true;

  Future<void> setTripSyncEnabled(String tripId, bool enabled) async {
    await prefs.setBool('sync_enabled_trip_$tripId', enabled);
    await _applyToggle('trip', tripId, enabled);
  }

  Future<void> setGroupSyncEnabled(String groupId, bool enabled) async {
    await prefs.setBool('sync_enabled_group_$groupId', enabled);
    await _applyToggle('group', groupId, enabled);
  }

  Future<void> _applyToggle(String kind, String id, bool enabled) async {
    if (enabled) {
      // 重开：该实体全部本地行入队 upsert（全量幂等重传）
      final now = DateTime.now().millisecondsSinceEpoch;
      if (kind == 'trip') {
        await outbox.enqueue('trips', id, 'upsert', now);
        final items = await (db.select(db.tripItems)..where((t) => t.tripId.equals(id))).get();
        for (final i in items) {
          await outbox.enqueue('trip_items', i.id, 'upsert', now);
        }
        await syncNow();
      } else {
        await outbox.enqueue('groups', id, 'upsert', now);
        for (final table in const ['members', 'expenses', 'settlements']) {
          final rows = await _rowsOfGroup(table, id);
          for (final r in rows) {
            await outbox.enqueue(table, r, 'upsert', now);
          }
        }
        await syncNow();
      }
    }
    // 关闭由 UI 层先处理（暂停=仅置 false；删云端=调 purgeEntityCloudRows 后置 false）
  }

  Future<List<String>> _rowsOfGroup(String table, String groupId) async {
    switch (table) {
      case 'members':
        return (await (db.select(db.members)..where((m) => m.groupId.equals(groupId))).get())
            .map((m) => m.id).toList();
      case 'expenses':
        return (await (db.select(db.expenses)..where((e) => e.groupId.equals(groupId))).get())
            .map((e) => e.id).toList();
      case 'settlements':
        return (await (db.select(db.settlements)..where((s) => s.groupId.equals(groupId))).get())
            .map((s) => s.id).toList();
    }
    return const [];
  }

  /// 关闭开关-「同时删除云端数据」：删除该实体云端全部行（owner 行）+ 清 outbox 防残差。
  Future<void> purgeEntityCloudRows({required bool isTrip, required String id}) async {
    if (isTrip) {
      await transport.deleteWhere('trip_items_sync', {'trip_id': id});
      await transport.deleteWhere('trips_sync', {'id': id});
      await outbox.clearEntity('trips');
      await outbox.clearEntity('trip_items');
    } else {
      for (final table in const ['members_sync', 'expenses_sync', 'settlements_sync', 'groups_sync']) {
        await transport.deleteWhere(table, {'group_id': id});
      }
      await transport.deleteWhere('groups_sync', {'id': id});
      await outbox.clearEntity('groups');
      await outbox.clearEntity('members');
      await outbox.clearEntity('expenses');
      await outbox.clearEntity('settlements');
    }
  }

  // ===== 手动同步 =====

  Future<void> syncNow({bool push = true}) => _guarded(() async {
        if (transport.currentUserId == null) {
          _updateStatus(kind: SyncStatusKind.signedOut);
          return;
        }
        await _refreshCollabContext();
        if (_throttled && push) {
          // 节流期：手动按钮仍可用（被动周期已停）
        }
        if (push && _bootstrapGateOpen()) {
          final r = await pusher.drain();
          if (r.ok) _onPushSuccess();
        }
        final pr = await puller.pullAll();
        if (!pr.ok) {
          _consecutivePullFailures++;
          _onPullFailure(pr.error);
        } else {
          _consecutivePullFailures = 0;
        }
        _updateStatus(kind: SyncStatusKind.idle, lastSynced: DateTime.now());
      });

  // ===== 并发互斥（drain 与 pull 互斥；锁内操作 30s 超时强制释放） =====

  Future<void> _guarded(Future<void> Function() body) async {
    if (_lock != null) return; // lock busy
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      await body().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      // 锁内整体操作超时：视为异常强制释放（登记状态）
      _setStatusError('同步超时（30s），已自动恢复');
    } catch (e) {
      _setStatusError(_sanitizeError(e));
    } finally {
      _lock = null;
      if (!completer.isCompleted) completer.complete();
      _updateStatus();
    }
  }

  // ===== 失败/恢复/节流（§3.12） =====

  void _onPushFailure() {
    _consecutivePushFailures++;
    if (_consecutivePushFailures >= 3 && !_lastPushFailed) {
      _throttle();
    } else if (_consecutivePushFailures >= 3) {
      _throttled = true;
    }
    if (!_lastPushFailed) {
      onSyncFailed?.call('云端失联：改动已妥善留在本机，网络恢复后自动续传');
    }
    _lastPushFailed = true;
    _updateStatus(kind: SyncStatusKind.offline);
  }

  void _onPushSuccess() {
    if (_lastPushFailed) {
      onSyncRecovered?.call();
      _lastPushFailed = false;
    }
    _consecutivePushFailures = 0;
    _throttled = false;
    _throttleUntil = null;
    _updateStatus(kind: SyncStatusKind.idle, lastSynced: DateTime.now());
  }

  void _onPullFailure(Object? e) {
    if (_consecutivePullFailures >= 3) _throttle();
    _updateStatus(kind: SyncStatusKind.offline, error: _sanitizeError(e));
  }

  void _throttle() {
    _throttled = true;
    _throttleUntil = DateTime.now().add(const Duration(seconds: 600));
    // 10min 后自动解除（手动“立即同步”不受限）
    Timer(const Duration(seconds: 600), () {
      _throttled = false;
      _throttleUntil = null;
      if (_started) _startPeriodic();
    });
    _stopPeriodic();
  }

  String _sanitizeError(Object? e) {
    var s = e.toString();
    s = s.replaceAll(RegExp(r'(key|token|password)[=:]\s*[^\s,;]+', caseSensitive: false), r'$1=***');
    return s.length > 160 ? s.substring(0, 160) : s;
  }

  void _setStatusError(String msg) {
    _status = _status.copyWith(lastError: msg, lastErrorAt: DateTime.now());
    onStatusChanged?.call(_status);
    _statusCtl.add(_status);
  }

  // ===== 协作上下文（§3.13.2） =====

  Future<void> _refreshCollabContext() async {
    final uid = transport.currentUserId;
    merger.refreshContext(userId: uid, collabGroups: _collabGroupIds);
    if (uid == null) return;
    try {
      final res = await transport.rpc('list_my_collabs', {});
      if (res['ok'] == true) {
        final list = (res['collabs'] as List?) ?? const [];
        final next = list.map((e) => (e as Map)['groupId'] as String).toSet();
        _sharedOwners.clear();
        for (final e in list) {
          final m = e as Map;
          if (m['groupId'] != null && m['ownerUserId'] != null) {
            _sharedOwners[m['groupId'] as String] = m['ownerUserId'] as String;
          }
        }
        // 名单收缩（被移除/退出）→ 清除对应镜像
        for (final gone in _collabGroupIds.difference(next)) {
          await merger.clearSharedGroup(gone);
        }
        // 名单扩张（新加入）→ 重置账本域游标全量重拉（增量游标可能已越过旧数据）
        final added = next.difference(_collabGroupIds);
        if (added.isNotEmpty) {
          // 新加入协作：重置账本域游标全量重拉（增量游标可能已越过存量数据）
          for (final e in const ['groups', 'members', 'expenses', 'settlements']) {
            await metaService.reset(e);
          }
        }
        _collabGroupIds = next;
      }
    } catch (_) {
      // 名单查询失败：该轮跳过镜像路由（沿用旧集合），不影响本地实体拉取
    }
    merger.refreshContext(userId: uid, collabGroups: _collabGroupIds);
  }

  // ===== 状态机（§3.8） =====

  void _updateStatus({SyncStatusKind? kind, DateTime? lastSynced, String? error}) async {
    final configured = await _isConfigured();
    final uid = transport.currentUserId;
    var k = kind;
    if (k == null) {
      if (!configured) {
        k = SyncStatusKind.unconfigured;
      } else if (uid == null) {
        k = SyncStatusKind.signedOut;
      } else if (_lock != null) {
        k = SyncStatusKind.syncing;
      } else if (_throttled || _lastPushFailed || _consecutivePullFailures >= 3) {
        k = SyncStatusKind.offline;
      } else {
        k = SyncStatusKind.idle;
      }
    }
    final pending = uid == null ? 0 : await outbox.pendingCount();
    // 切到 idle 且确无新错误时，清掉陈旧 lastError——
    // 避免「状态卡显示绿/已同步」与「最近错误红字」同时出现造成语义矛盾。
    final clearStaleError = k == SyncStatusKind.idle &&
        error == null &&
        !_lastPushFailed &&
        _consecutivePullFailures < 3;
    _status = SyncStatus(
      kind: k,
      lastSyncedAt: lastSynced ?? _status.lastSyncedAt,
      pendingCount: pending,
      lastError: clearStaleError ? null : (error ?? _status.lastError),
      lastErrorAt:
          clearStaleError ? null : (error != null ? DateTime.now() : _status.lastErrorAt),
    );
    onStatusChanged?.call(_status);
    _statusCtl.add(_status);
  }

  Future<bool> _isConfigured() async {
    if (transport.currentUserId != null) return true;
    // 未登录时也报告端点是否已配置（unconfigured vs signedOut 区分）
    try {
      return await transport.ping();
    } catch (_) {
      return false;
    }
  }

  /// 加入共享团成功后：重置账本域游标 → 立即全量拉取该团镜像（§3.13.1）。
  Future<void> onJoinedSharedGroup(String groupId) async {
    for (final e in const ['groups', 'members', 'expenses', 'settlements']) {
      await metaService.reset(e);
    }
    await _refreshCollabContext();
    await syncNow(push: false);
  }

  /// 退出/被移出共享团后：清镜像 + 刷新名单（通知由 UI 层触发文案）。
  Future<void> onLeftSharedGroup(String groupId) async {
    await merger.clearSharedGroup(groupId);
    await _refreshCollabContext();
  }

  /// 当前参与的共享团 id 集合（首页「共享账本」分组数据源判断用）。
  Set<String> get collabGroupIds => _collabGroupIds;

  /// 共享团 owner 用户 id（在线直写时保 owner_user_id 不变；未知返回 null）。
  String? sharedOwnerUserIdOf(String groupId) => _sharedOwners[groupId];

  /// purge_my_data 后：本地 outbox 清空、各游标归零（引导标记保留防误引导空传）。
  Future<void> resetLocalSyncState() async {
    await outbox.clearAll();
    await metaService.resetAll();
  }

  void dispose() {
    stop();
    _statusCtl.close();
  }
}
