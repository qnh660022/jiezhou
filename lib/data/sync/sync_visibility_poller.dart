/// 页面可见期短轮询（V2.6.6.2 §4.2 / D6）。
///
/// 契约（SPEC，不得更改）：
/// * 空间详情页、旅伴中心、驾驶舱三类页面**可见期间**启用短轮询：每 30s 拉一次
///   增量（复用 sync 引擎 pull）；
/// * 页面不可见 / 退后台 → **立即停**（`stop()` 取消周期任务，不是空转）；
/// * 任何协作写 RPC 成功返回后：立即触发一次 `drain + pull`（写后读），
///   保证自己立刻看到合流结果（由 `SyncEngine.afterCollabWrite()` 提供）；
/// * **不建立任何 websocket 长连接**（§0.3.12 红线）。
///
/// 为什么不让引擎的周期任务包办：引擎周期是「全局账号级」节奏（5s/15s/60s 三档，
/// 前台常驻）；本类表达的是「页面级」节奏，页面关掉就停，能明确回答
/// 「这次轮询是谁发起的、有没有在不可见时偷偷发请求」——用量预算表要的就是这个数字。
library;
import 'sync_engine.dart';

/// 协作页面短轮询间隔（§4.2 固定 30s；3600/30 = 120 次/小时，对齐 §9 预算）。
const Duration kCollabPollInterval = Duration(seconds: 30);

class SyncVisibilityPoller {
  SyncVisibilityPoller({
    required SyncScheduler scheduler,
    required this.onTick,
    this.interval = kCollabPollInterval,
    DateTime Function()? clock,
    this.isActive,
  })  : _sched = scheduler,
        _clock = clock ?? DateTime.now;

  final SyncScheduler _sched;

  /// 每次轮询触发时调用（通常 = 引擎的一轮增量 pull）。
  final void Function() onTick;

  final Duration interval;
  final DateTime Function() _clock;

  /// 细粒度可见性判定：定时器到点时再确认一次（例如底部导航切到别的 Tab 时，
  /// 页面在 IndexedStack 里仍然 mounted，但已经不可见 → 本次不发请求）。
  /// 返回 false 的那一次**不计入 [ticks]**，用量预算因此反映真实网络次数。
  final bool Function()? isActive;

  Cancellable? _timer;
  bool _visible = false;
  int _ticks = 0;
  DateTime? _visibleSince;
  Duration _visibleElapsed = Duration.zero;

  /// 是否正在轮询（页面可见且已 start）。
  bool get running => _timer != null;

  /// 页面是否处于可见态。
  bool get visible => _visible;

  /// 累计触发次数（用量预算表实测用）。
  int get ticks => _ticks;

  /// 累计可见时长（不含当前这段未结束的可见期）。
  Duration get visibleElapsed => _visibleElapsed;

  /// 按当前实测数据推算的「每小时请求数」（预算口径，§9）。
  ///
  /// 可见时长为 0（还没跑完一整段）时用间隔反推理论值：3600s / interval。
  double get requestsPerHour {
    final seconds = _visibleElapsed.inMilliseconds / 1000.0;
    if (seconds <= 0 || _ticks == 0) {
      return 3600.0 / (interval.inMilliseconds / 1000.0);
    }
    return _ticks * 3600.0 / seconds;
  }

  /// 页面变为可见（进入页面 / 回前台 / 切回该 Tab）。
  ///
  /// 幂等：重复调用不会叠加定时器（历史踩坑：每次 build 都 start 会堆出 N 个
  /// 定时器，请求量翻 N 倍）。
  void start() {
    if (_visible) return;
    _visible = true;
    _visibleSince = _clock();
    // 进入可见态立刻拉一次：用户看到的应该是最新状态，不必等满 30s
    onTick();
    _timer = _sched.periodic(interval, _fire);
  }

  /// 页面不可见（离开页面 / 退后台）：立即停止轮询并累计可见时长。
  void stop() {
    if (!_visible) return;
    _visible = false;
    final since = _visibleSince;
    if (since != null) {
      _visibleElapsed += _clock().difference(since);
      _visibleSince = null;
    }
    _timer?.cancel();
    _timer = null;
  }

  /// 页面生命周期变化（`AppLifecycleState`）。
  ///
  /// 只有 `resumed` 才算可见；`inactive/paused/hidden/detached` 一律停。
  void onLifecycleChanged(bool resumed) => resumed ? start() : stop();

  void _fire() {
    if (!_visible) return; // 防御：定时器已被取消但仍被触发
    final active = isActive;
    if (active != null && !active()) return; // 页面已不可见：本次不发请求
    _ticks++;
    onTick();
  }

  /// 释放（页面 dispose 时调用）。
  void dispose() => stop();
}
