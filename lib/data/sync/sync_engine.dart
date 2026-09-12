/// 同步引擎：触发器编排（debounce / 周期 / 手动 / 冷启动 / 前台恢复）+
/// 全局互斥锁 + 失败节流与退避 + 引导闸 + 状态机
/// （V2.6 §3.5.4 / §3.6 / §3.8 / §3.10 / §3.12）。
///
/// 触发语义（本版修订）：
/// - **三档频率**（prefs `sync.freq`，默认 realtime）：只影响「写后合并窗口 +
///   周期间隔 + 周期是否顺带上行」，锁/节流/引导闸三档一致；
/// - **即改即同步**：本地写事件 → `enqueue`（先落库，绝不丢）+ debounce 后 push；
///   若此刻被抑制（后台/节流/关自动/仅 Wi-Fi 且当前是蜂窝）→ 记 `_pushPending`，
///   恢复时补推；
/// - **先拉后推**：手动/引导/开关重开的同步一律先 pull 再 push，避免本地旧 pending
///   把受邀端直写到云端的新值覆盖回去（LWW 回退）；
/// - **锁忙排队**：并发请求不再被静默丢弃，改为在当前轮结束后自动重跑。
library;
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/network_probe.dart';
import '../db/database.dart';
import 'db_access.dart';
import 'sync_merger.dart';
import 'sync_meta_service.dart';
import 'sync_models.dart';
import 'sync_outbox_service.dart';
import 'sync_puller.dart';
import 'sync_pusher.dart';
import 'sync_transport.dart';

/// 同步频率档位（prefs `sync.freq`）：realtime 5s / standard 15s / economy 60s。
enum SyncFreq { realtime, standard, economy }

extension SyncFreqX on SyncFreq {
  /// 周期间隔（拉取节奏）。
  int get intervalSeconds => switch (this) {
        SyncFreq.realtime => 5,
        SyncFreq.standard => 15,
        SyncFreq.economy => 60,
      };

  /// 写事件合并窗口：本地写 → 上行 push 的延迟。
  Duration get pushDebounce => switch (this) {
        SyncFreq.realtime => const Duration(milliseconds: 300),
        SyncFreq.standard => const Duration(milliseconds: 1500),
        SyncFreq.economy => const Duration(seconds: 5),
      };

  /// 周期任务是否顺带上行（省流档只在写后 / 前台恢复 / 手动时推）。
  bool get periodicPush => this != SyncFreq.economy;

  String get key => name;

  /// 缺省 **实时**（即改即同步；此前缺省 standard，用户改完要等 1.5s+）。
  static SyncFreq fromKey(String? k) => SyncFreq.values
      .firstWhere((f) => f.name == k, orElse: () => SyncFreq.realtime);
}

/// 可注入的定时器抽象：单测注入假实现即可精确推进时间，无需真实等待。
abstract class SyncScheduler {
  /// 一次性任务，返回可取消句柄。
  Cancellable schedule(Duration delay, void Function() action);

  /// 周期任务。
  Cancellable periodic(Duration interval, void Function() action);
}

/// 可取消句柄。
abstract class Cancellable {
  void cancel();
}

class _TimerCancellable implements Cancellable {
  _TimerCancellable(this._timer);
  final Timer _timer;
  @override
  void cancel() => _timer.cancel();
}

/// 生产实现：包装 dart:async Timer。
class RealSyncScheduler implements SyncScheduler {
  const RealSyncScheduler();
  @override
  Cancellable schedule(Duration delay, void Function() action) =>
      _TimerCancellable(Timer(delay, action));
  @override
  Cancellable periodic(Duration interval, void Function() action) =>
      _TimerCancellable(Timer.periodic(interval, (_) => action()));
}

/// 被抑制/被互斥挡住时挂起的请求类型（sync 优先级高于 push）。
enum _SyncRequest { push, sync }

class SyncEngine {
  SyncEngine._(this.db, this.transport, this.prefs, this._sched);

  static SyncEngine? _instance;

  final AppDatabase db;
  final SyncTransport transport;
  final SharedPreferences prefs;
  final SyncScheduler _sched;

  /// 网络类型探测（默认平台实现；单测可注入固定值）。
  late final Future<NetKind> Function() _probe;

  late final SyncOutboxService outbox;
  late final SyncMetaService metaService;
  late final SyncMerger merger;
  late final SyncPusher pusher;
  late final SyncPuller puller;

  Cancellable? _debounce;
  Cancellable? _periodic;
  Cancellable? _throttleTimer;
  Cancellable? _backoffTimer;

  Future<void>? _lock;
  _SyncRequest? _deferred;
  bool _pushPending = false;
  bool _throttled = false;
  DateTime? _throttleUntil;
  int _consecutivePullFailures = 0;
  int _consecutivePushFailures = 0;
  bool _lastPushFailed = false;
  bool _background = false;
  bool _started = false;
  NetKind _netKind = NetKind.unknown;

  Set<String> _collabGroupIds = {};
  bool _collabContextKnown = false;
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

  /// 失败节流解除的预计时刻（未节流为 null）。同步中心据此显示「将于 xx:xx
  /// 自动恢复」，避免用户看到「离线」却不知道何时会好。
  DateTime? get throttleUntil => _throttleUntil;

  static SyncEngine? instance() => _instance;

  // ===== 用户偏好（自动同步总开关 / 仅 Wi-Fi / 频率档） =====

  static const String _kAutoEnabled = 'sync.auto.enabled';
  static const String _kWifiOnly = 'sync.wifiOnly';

  /// 自动同步总开关（缺省开）。关闭后：停周期、不排 debounce push，
  /// **手动「立即同步」「重试死信」不受影响**。
  bool get autoEnabled => prefs.getBool(_kAutoEnabled) ?? true;

  /// 仅 Wi-Fi 同步（缺省关）。
  bool get wifiOnly => prefs.getBool(_kWifiOnly) ?? false;

  /// 最近一次网络探测结果（UI 展示用；unknown 时门面 fail-open）。
  NetKind get netKind => _netKind;

  /// 此刻自动同步是否正被「仅 Wi-Fi」挡住（UI 提示用）。
  bool get wifiBlockedNow => _wifiBlocked;

  Future<void> setAutoEnabled(bool enabled) async {
    await prefs.setBool(_kAutoEnabled, enabled);
    if (enabled) {
      if (_pushPending) unawaited(_pushNow());
      _startPeriodic();
    } else {
      _stopPeriodic();
      _debounce?.cancel();
      _debounce = null;
      _pushPending = true; // 关闭期间的改动留着，重开时补推
    }
    _updateStatus();
  }

  Future<void> setWifiOnly(bool enabled) async {
    await prefs.setBool(_kWifiOnly, enabled);
    if (enabled) await _refreshNetKind();
    if (!enabled && _pushPending) unawaited(_pushNow());
    _updateStatus();
  }

  // ===== 组装 =====

  /// 初始化并挂载全局单例（配置有效且用户可能登录时才调）。
  ///
  /// [scheduler] 仅供单测注入假定时器；不传则用真实 Timer。
  /// [probe] 仅供单测注入网络类型探测；不传则用平台实现（Windows/Android
  /// 都靠网卡名猜，单测环境必然得到 unknown → 无法覆盖「仅 Wi-Fi 拦截」分支）。
  static SyncEngine init(AppDatabase db, SyncTransport transport,
      SharedPreferences prefs,
      {SyncScheduler? scheduler, Future<NetKind> Function()? probe}) {
    final engine = SyncEngine._(db, transport, prefs, scheduler ?? const RealSyncScheduler());
    engine._probe = probe ?? probeNetKind;
    engine.outbox = SyncOutboxService(db);
    engine.metaService = SyncMetaService(db, prefs: prefs);
    engine.merger = SyncMerger(db, engine.outbox);
    engine.pusher = SyncPusher(
      engine.outbox,
      transport,
      SyncDbAccessor(db),
      onFailure: (err) => engine._onPushFailure(err),
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
    // 归一历史遗留的实体键（`tripItems` → `trip_items`），必须在首次取件前完成，
    // 否则脏键行会被 assemble 当未知实体直接清掉（bug H10）。
    await outbox.normalizeEntityKeys();
    await metaService.normalizeEntityKeys();
    await _refreshNetKind();
    await _refreshCollabContext();
    _updateStatus();
    _startPeriodic();
    // 冷启动：登录态恢复后首帧一次 pull（自动同步关闭时不打扰用户）
    if (autoEnabled) unawaited(syncNow(push: false));
  }

  void stop() {
    _started = false;
    _stopPeriodic();
    _debounce?.cancel();
    _debounce = null;
  }

  /// 登出 / 换账号：清掉全部运行时状态（节流、失败计数、挂起请求、协作名单）。
  /// 否则新账号一登录就顶着上一账号残留的「离线 / 节流」（历史 bug M9）。
  void resetRuntimeState() {
    _stopPeriodic();
    _debounce?.cancel();
    _debounce = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _cancelThrottleTimer();
    _throttled = false;
    _throttleUntil = null;
    _lastPushFailed = false;
    _consecutivePushFailures = 0;
    _consecutivePullFailures = 0;
    _pushPending = false;
    _deferred = null;
    _background = false;
    _collabGroupIds = {};
    _collabContextKnown = false;
    _sharedOwners.clear();
    _userId = null;
    _updateStatus();
  }

  void setForeground(bool foreground) {
    _background = !foreground;
    if (foreground && _started && !_throttled && autoEnabled) {
      // 回前台：补推后台期间攒下的改动 + 一轮同步 + 恢复周期任务
      unawaited(syncNow(push: true));
      _startPeriodic();
    }
    if (!foreground) _stopPeriodic();
  }

  SyncFreq get freq => SyncFreqX.fromKey(prefs.getString('sync.freq'));

  Future<void> setFreq(SyncFreq f) async {
    await prefs.setString('sync.freq', f.key);
    _startPeriodic();
    // 换档后立刻按新节奏推一次（不必等下一个周期）
    if (_pushPending) unawaited(_pushNow());
  }

  // ===== 触发：写后即时推 =====

  /// 本地写事件到达：安排合并窗口后的 push。
  ///
  /// 被抑制（未开自动 / 后台 / 节流 / 仅 Wi-Fi 且当前走蜂窝）时**只记标志不丢**，
  /// 恢复路径（回前台、节流解除、切回 Wi-Fi、推送成功）负责补推。
  void _scheduleDebounce() {
    if (!autoEnabled || _background || _throttled || _wifiBlocked) {
      _pushPending = true;
      return;
    }
    // 新写事件取代尚未触发的退避重试（改动已在 outbox 里，不重复排队）
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _debounce?.cancel();
    _debounce = _sched.schedule(freq.pushDebounce, () => unawaited(_pushNow()));
  }

  /// 仅 Wi-Fi 且当前判定为蜂窝 → 阻断**自动**触发（手动同步不受限）。
  /// 探测 unknown / 异常一律 fail-open（见 network_probe 门面注释）。
  bool get _wifiBlocked => wifiOnly && _netKind == NetKind.mobile;

  Future<void> _refreshNetKind() async {
    if (!wifiOnly) return; // 未开启仅 Wi-Fi 时不必探测
    try {
      _netKind = await _probe();
    } catch (_) {
      _netKind = NetKind.unknown;
    }
  }

  void _startPeriodic() {
    _stopPeriodic();
    if (_background || !_started || !autoEnabled) return;
    _periodic = _sched.periodic(Duration(seconds: freq.intervalSeconds), () {
      if (!_throttled) unawaited(syncNow(push: freq.periodicPush));
    });
  }

  void _stopPeriodic() {
    _periodic?.cancel();
    _periodic = null;
  }

  // ===== 引导闸（§3.10）：未确认归属的账号禁止上行 =====

  bool _bootstrapGateOpen() {
    final uid = transport.currentUserId;
    if (uid == null) return false;
    return prefs.getBool('sync_bootstrapped_$uid') ?? false;
  }

  /// 登录成功/引导确认后调用：全量入队（开关关的实体由 per-id 闸门跳过）。
  Future<void> bootstrapUploadAll() async {
    final uid = transport.currentUserId;
    if (uid == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entity in const [
      'groups', 'members', 'expenses', 'settlements',
      'trips', 'trip_items', 'categories',
    ]) {
      if (!_entitySyncEnabled(entity)) continue;
      await outbox.enqueueEntityAll(entity, now, filter: _rowSyncEnabled(entity));
    }
    await prefs.setBool('sync_bootstrapped_$uid', true);
    await syncNow(manual: true);
  }

  /// 手动「开始上传本地数据」（同步中心）。
  Future<void> manualStartUpload() => bootstrapUploadAll();

  // ===== 上云开关（§3.9）：prefs sync_enabled_trip_<id> / sync_enabled_group_<id> =====

  bool _entitySyncEnabled(String entity) {
    // categories 无开关（随账号自动同步）；子实体随属主，逐行判定见 _rowSyncEnabled。
    return true;
  }

  /// 引导入队时的逐行开关预过滤（与 pusher.isEntityEnabled 同口径）。
  bool Function(String rowId)? _rowSyncEnabled(String entity) {
    switch (entity) {
      case 'trips':
        return tripSyncEnabled;
      case 'groups':
        return groupSyncEnabled;
      default:
        return null; // trip_items/members/expenses/settlements 需读行内归属，交给闸门
    }
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
        await syncNow(manual: true);
      } else {
        await outbox.enqueue('groups', id, 'upsert', now);
        for (final table in const ['members', 'expenses', 'settlements']) {
          final rows = await _rowsOfGroup(table, id);
          for (final r in rows) {
            await outbox.enqueue(table, r, 'upsert', now);
          }
        }
        await syncNow(manual: true);
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

  /// 一轮同步：**先 pull 后 push**。
  ///
  /// [manual] 手动触发（「立即同步」）：绕过自动同步开关与仅 Wi-Fi 限制。
  Future<void> syncNow({bool push = true, bool manual = false}) =>
      _run(_SyncRequest.sync,
          () => _syncBody(push: push, manual: manual));

  Future<void> _syncBody({required bool push, required bool manual}) async {
    if (transport.currentUserId == null) {
      _updateStatus(kind: SyncStatusKind.signedOut);
      return;
    }
    await _refreshCollabContext();
    if (!manual && _wifiBlocked) {
      // 自动同步被「仅 Wi-Fi」拦下：不动状态机 kind（这是策略生效，不是故障），
      // 只落一条说明性错误文案，并留着 pending 等切回 Wi-Fi 再补推。
      _pushPending = true;
      _setStatusError('已按「仅 Wi-Fi」暂停自动同步（当前为移动网络）');
      return;
    }
    // 1) 先拉：云端较新的值先落地，随后 push 不会用本地旧 pending 覆盖它
    final pr = await puller.pullAll();
    if (!pr.ok) {
      _consecutivePullFailures++;
      _onPullFailure(pr.error);
      // 拉取失败必须保持 offline + 最近错误：绝不能用 idle 覆盖（历史 bug H4：
      // 1~2 次拉取失败被显示成绿色「已同步」，实际什么都没拉到）
      _updateStatus(kind: SyncStatusKind.offline);
      return;
    }
    _consecutivePullFailures = 0;
    // 拉取成功即恢复周期任务（历史 bug：拉取成功但节流标志残留，周期停满 10 分钟）
    if (_throttled && !manual) {
      _throttled = false;
      _throttleUntil = null;
      _cancelThrottleTimer();
      _startPeriodic();
    }
    // 2) 后推
    var pushFailed = false;
    if (push && _bootstrapGateOpen() && (manual || autoEnabled)) {
      final r = await pusher.drain();
      if (r.ok) {
        _pushPending = false;
      } else {
        pushFailed = true;
      }
    }
    // 「刚刚同步」只在拉取确实成功时刷新——失败也刷时间会掩盖故障。
    _updateStatus(
      kind: pushFailed ? SyncStatusKind.offline : SyncStatusKind.idle,
      lastSynced: pushFailed ? null : DateTime.now(),
    );
  }

  /// 手动「立即同步」加强版：重置死信与节流后全量重试（同步中心按钮用）。
  Future<void> retryFailedNow() async {
    await outbox.resetDeadLetters();
    _throttled = false;
    _throttleUntil = null;
    _cancelThrottleTimer();
    _consecutivePushFailures = 0;
    _consecutivePullFailures = 0;
    _lastPushFailed = false;
    _pushPending = true;
    if (!_background) _startPeriodic();
    await syncNow(manual: true);
    if (_pushPending) await _pushNow(manual: true);
  }

  // ===== 上行 push（仅自动触发；退避/恢复补推都走这里） =====

  Future<void> _pushNow({bool manual = false}) async {
    if (!manual) {
      if (!autoEnabled) {
        _pushPending = true;
        return;
      }
      if (_wifiBlocked) {
        _pushPending = true;
        return;
      }
      // 节流期内不再自动重试：否则退避定时器会绕过 10 分钟节流窗口继续打网络
      // （退避上限 5min < 节流 600s，必然穿透）。节流解除后由定时器补推。
      if (_throttled) {
        _pushPending = true;
        return;
      }
    }
    if (!_bootstrapGateOpen()) {
      _pushPending = true;
      return;
    }
    await _run(_SyncRequest.push, () async {
      final r = await pusher.drain();
      if (r.ok) _pushPending = false;
    });
  }

  // ===== 并发互斥（drain 与 pull 互斥；锁忙排队而非丢弃） =====

  Future<void> _run(_SyncRequest kind, Future<void> Function() body) async {
    if (_lock != null) {
      // 锁忙：记下请求，当前轮结束后自动重跑（历史 bug：直接 return 导致
      // debounce 触发的 push 被周期 pull 静默吞掉，且不会重排）
      _defer(kind);
      return;
    }
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      await body();
    } catch (e) {
      _setStatusError(_sanitizeError(e));
    } finally {
      _lock = null;
      if (!completer.isCompleted) completer.complete();
      _updateStatus();
      final deferred = _deferred;
      _deferred = null;
      if (deferred == _SyncRequest.push) {
        unawaited(_pushNow());
      } else if (deferred == _SyncRequest.sync) {
        unawaited(syncNow());
      }
    }
  }

  void _defer(_SyncRequest kind) {
    if (kind == _SyncRequest.sync || _deferred == null) _deferred = kind;
  }

  // ===== 失败/恢复/节流（§3.12） =====

  void _onPushFailure(Object? error) {
    _consecutivePushFailures++;
    if (_consecutivePushFailures >= 3) {
      if (!_lastPushFailed) {
        _throttle();
      } else {
        _throttled = true;
      }
    }
    // 退避重试（1s/4s/16s…cap 5min）：此前 backoffFor 是死代码，失败后无退避，
    // 导致硬重试迅速堆到 8 次变死信。上限 5min 保证网络恢复后无需等满节流窗口。
    _scheduleBackoffRetry();
    if (!_lastPushFailed) {
      onSyncFailed?.call('云端失联：改动已妥善留在本机，网络恢复后自动续传');
    }
    _lastPushFailed = true;
    // 失败原因进状态（历史 bug：离线态不落 error，UI 只显示「离线」无原因）。
    _updateStatus(kind: SyncStatusKind.offline, error: _sanitizeError(error));
  }

  void _scheduleBackoffRetry() {
    _backoffTimer?.cancel();
    final d = pusher.backoffFor(_consecutivePushFailures);
    _backoffTimer = _sched.schedule(d, () {
      _pushPending = true;
      unawaited(_pushNow());
    });
  }

  void _onPushSuccess() {
    if (_lastPushFailed) {
      onSyncRecovered?.call();
      _lastPushFailed = false;
    }
    _consecutivePushFailures = 0;
    _backoffTimer?.cancel();
    _backoffTimer = null;
    if (_throttled) {
      // 历史 bug：推送恢复后不重启周期任务 → 只能等 600s 定时器才自愈
      _throttled = false;
      _throttleUntil = null;
      _cancelThrottleTimer();
      if (!_background) _startPeriodic();
    }
    _updateStatus(kind: SyncStatusKind.idle, lastSynced: DateTime.now());
  }

  void _onPullFailure(Object? e) {
    if (_consecutivePullFailures >= 3) _throttle();
    _updateStatus(kind: SyncStatusKind.offline, error: _sanitizeError(e));
  }

  void _throttle() {
    _throttled = true;
    _throttleUntil = DateTime.now().add(const Duration(seconds: 600));
    _cancelThrottleTimer();
    // 10min 后自动解除（手动“立即同步”不受限）；句柄留存，登出/停止时取消，
    // 否则换账号会叠加多个定时器（历史 bug M9）
    _throttleTimer = _sched.schedule(const Duration(seconds: 600), () {
      _throttled = false;
      _throttleUntil = null;
      if (_started && !_background && autoEnabled) _startPeriodic();
      if (_pushPending) unawaited(_pushNow());
    });
    _stopPeriodic();
  }

  void _cancelThrottleTimer() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }

  String _sanitizeError(Object? e) {
    var s = e.toString();
    s = s.replaceAll(RegExp(r'(key|token|password)[=:]\s*[^\s,;]+', caseSensitive: false), r'$1=***');
    return s.length > 160 ? s.substring(0, 160) : s;
  }

  void _setStatusError(String msg) {
    if (_statusCtl.isClosed) return; // dispose 后的在途写入丢弃
    _status = _status.copyWith(lastError: msg, lastErrorAt: DateTime.now());
    _emitStatus();
  }

  // ===== 协作上下文（§3.13.2） =====

  Future<void> _refreshCollabContext() async {
    final uid = transport.currentUserId;
    merger.refreshContext(userId: uid, collabGroups: _collabGroupIds);
    if (uid == null) {
      _collabContextKnown = false;
      merger.refreshContext(userId: null, collabGroups: const {}, known: false);
      return;
    }
    try {
      final res = await transport.rpc('list_my_collabs', {});
      if (res['ok'] == true && res['collabs'] is List) {
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
          for (final e in const ['groups', 'members', 'expenses', 'settlements']) {
            await metaService.reset(e);
          }
        }
        _collabGroupIds = next;
        _collabContextKnown = true;
      } else {
        // 返回体不合法：名单不可信，本轮禁止把「非本人」的行落本地业务表
        _collabContextKnown = false;
      }
    } catch (_) {
      // 名单查询失败：沿用旧集合，但标记为「未知」，避免他人数据串进本地账本
      _collabContextKnown = false;
    }
    merger.refreshContext(
        userId: uid, collabGroups: _collabGroupIds, known: _collabContextKnown);
  }

  /// 在线直写前确保协作上下文可用（受邀端写入需要团 owner id 兜底）。
  Future<void> ensureCollabContext() => _refreshCollabContext();

  // ===== 状态机（§3.8） =====

  void _updateStatus({SyncStatusKind? kind, DateTime? lastSynced, String? error}) async {
    if (_statusCtl.isClosed) return; // 已 dispose，状态流没人听了
    final configured = await _isConfigured();
    _userId = transport.currentUserId; // 缓存一份供状态/UI 读取（transport 仍是权威源）
    final uid = _userId;
    var k = kind;
    if (k == null) {
      if (!configured) {
        k = SyncStatusKind.unconfigured;
      } else if (uid == null) {
        k = SyncStatusKind.signedOut;
      } else if (_lock != null) {
        k = SyncStatusKind.syncing;
      } else if (_throttled || _lastPushFailed || _consecutivePullFailures > 0) {
        k = SyncStatusKind.offline;
      } else {
        k = SyncStatusKind.idle;
      }
    }
    int pending = 0;
    if (uid != null) {
      try {
        pending = await outbox.pendingCount();
      } catch (_) {
        pending = 0; // 库里已关（引擎 dispose）——待同步数已无意义
      }
    }
    // 切到 idle 且确无新错误时，清掉陈旧 lastError——
    // 避免「状态卡显示绿/已同步」与「最近错误红字」同时出现造成语义矛盾。
    final clearStaleError = k == SyncStatusKind.idle &&
        error == null &&
        !_lastPushFailed &&
        _consecutivePullFailures == 0;
    _status = SyncStatus(
      kind: k,
      lastSyncedAt: lastSynced ?? _status.lastSyncedAt,
      pendingCount: pending,
      lastError: clearStaleError ? null : (error ?? _status.lastError),
      lastErrorAt:
          clearStaleError ? null : (error != null ? DateTime.now() : _status.lastErrorAt),
    );
    _emitStatus();
  }

  /// 统一的状态广播出口。
  ///
  /// [_updateStatus] 是 async 的（中途有 `await outbox.pendingCount()`），在途调用
  /// 可能在 [dispose] 关闭 [_statusCtl] 之后才走到这里。往已关闭的
  /// StreamController 写会抛 `Bad state: Cannot add new events after calling close`
  /// ——故写入前必须复查一次（入口处的检查挡不住 await 期间的关闭）。
  void _emitStatus() {
    if (_statusCtl.isClosed) return;
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
    await syncNow(push: false, manual: true);
  }

  /// 退出/被移出共享团后：清镜像 + 刷新名单（通知由 UI 层触发文案）。
  Future<void> onLeftSharedGroup(String groupId) async {
    await merger.clearSharedGroup(groupId);
    await _refreshCollabContext();
  }

  /// 当前参与的共享团 id 集合（首页「共享账本」分组数据源判断用）。
  Set<String> get collabGroupIds => _collabGroupIds;

  /// 协作名单是否可信（同步中心/共享页提示用）。
  bool get collabContextKnown => _collabContextKnown;

  /// 共享团 owner 用户 id（在线直写时保 owner_user_id 不变；未知返回 null）。
  String? sharedOwnerUserIdOf(String groupId) => _sharedOwners[groupId];

  /// purge_my_data 后：本地 outbox 清空、各游标归零（引导标记保留防误引导空传）。
  Future<void> resetLocalSyncState() async {
    await outbox.clearAll();
    await metaService.resetAll();
  }

  void dispose() {
    stop();
    _cancelThrottleTimer();
    _backoffTimer?.cancel();
    _statusCtl.close();
  }
}
