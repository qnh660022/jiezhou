// 调度层回归用例（bug H2/H3/H5/M9 + 三档频率 + 自动同步开关）。
//
// 用可注入的假 Scheduler 精确推进时间/触发任务，不依赖真实 Timer；
// 用可注入的 netProbe 固定网络类型，避免「仅 Wi-Fi」用例受跑测机器网卡影响。
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/sync_engine.dart';
import 'package:travel_assistant/data/sync/sync_outbox_service.dart';
import 'package:travel_assistant/data/sync/sync_transport_fake.dart';
import 'package:travel_assistant/platform/network_probe.dart';

class _FakeTimer implements Cancellable {
  _FakeTimer(this.action);
  final void Function() action;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  void fire() {
    if (!cancelled) action();
  }
}

class FakeScheduler implements SyncScheduler {
  final List<_FakeTimer> oneShot = [];
  final List<_FakeTimer> periodicTimers = [];

  @override
  Cancellable schedule(Duration delay, void Function() action) {
    final t = _FakeTimer(action);
    oneShot.add(t);
    return t;
  }

  @override
  Cancellable periodic(Duration interval, void Function() action) {
    final t = _FakeTimer(action);
    periodicTimers.add(t);
    return t;
  }

  /// 触发全部未取消的一次性任务（debounce / 退避 / 节流解除）。
  void fireOneShot() {
    for (final t in [...oneShot]) {
      t.fire();
    }
  }

  /// 触发全部未取消的周期任务。
  void firePeriodic() {
    for (final t in [...periodicTimers]) {
      t.fire();
    }
  }

  /// 是否有挂起且未取消的一次性任务（debounce 是否被排上的判据）。
  bool get hasPendingOneShot => oneShot.any((t) => !t.cancelled);
}

/// fetch 可被闸门阻塞的 transport（验证「锁忙排队」）。
class GatedTransport extends SyncTransportFake {
  Completer<void>? gate;

  @override
  Future<List<Map<String, dynamic>>> fetch(String entity,
      {required int updatedMsAfter,
      required String idAfter,
      required int limit}) async {
    final g = gate;
    if (g != null) await g.future;
    return super.fetch(entity,
        updatedMsAfter: updatedMsAfter, idAfter: idAfter, limit: limit);
  }
}

void main() {
  late AppDatabase db;
  late GatedTransport transport;
  late SharedPreferences prefs;
  late FakeScheduler sched;
  late SyncEngine engine;
  NetKind net = NetKind.wifi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'sync_bootstrapped_u1': true});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase();
    transport = GatedTransport()..user = 'u1';
    sched = FakeScheduler();
    net = NetKind.wifi;
    engine = SyncEngine.init(db, transport, prefs,
        scheduler: sched, probe: () async => net);
  });

  tearDown(() async {
    engine.dispose();
    SyncEngine.detach();
    await db.close();
  });

  Future<void> seedTrip(String id, {String name = '北京行'}) =>
      db.into(db.trips).insert(TripsCompanion(
            id: Value(id),
            name: Value(name),
            destination: const Value(''),
            emoji: const Value('✈️'),
            cover: const Value('ocean'),
            startEpochDay: const Value(0),
            endEpochDay: const Value(1),
            note: const Value(''),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ));

  void gateClose() => transport.gate = Completer<void>();
  void gateOpen() {
    final g = transport.gate;
    transport.gate = null;
    if (g != null && !g.isCompleted) g.complete();
  }

  test('即改即同步：本地写事件 → 合并窗口后立即上行（不走周期）', () async {
    await seedTrip('t1');
    await engine.start();
    await pumpEventQueue();

    // 走仓储层的统一入口（引擎已在 init 时挂 hook）
    SyncOutboxService.notifyWrite('trips', 't1');
    expect(await engine.outbox.pendingEntry('trips', 't1'), isNotNull);
    expect(sched.hasPendingOneShot, isTrue, reason: '应排上 debounce');

    sched.fireOneShot();
    await pumpEventQueue();

    expect(transport.tables['trips_sync']?['t1']?['name'], '北京行');
    expect(await engine.outbox.pendingEntry('trips', 't1'), isNull);
  });

  test('仅 Wi-Fi + 蜂窝：自动同步被拦，切回 Wi-Fi 后补推（不丢改动）', () async {
    await seedTrip('t1');
    net = NetKind.mobile;
    await engine.setWifiOnly(true);
    await engine.start();
    await pumpEventQueue();

    expect(engine.wifiBlockedNow, isTrue);
    SyncOutboxService.notifyWrite('trips', 't1');
    sched.fireOneShot();
    await pumpEventQueue();
    expect(transport.upsertCalls, 0, reason: '蜂窝下不应自动上行');
    expect(await engine.outbox.pendingEntry('trips', 't1'), isNotNull,
        reason: '改动必须留在 outbox');

    // 用户切回 Wi-Fi（手动关闭仅 Wi-Fi 或网络变化）→ 立刻补推
    net = NetKind.wifi;
    await engine.setWifiOnly(false);
    await pumpEventQueue();
    expect(transport.tables['trips_sync']?['t1'], isNotNull);
    expect(await engine.outbox.pendingEntry('trips', 't1'), isNull);
  });

  test('自动同步总开关：关掉不自动推但一条不丢，重开即补推', () async {
    await seedTrip('t1');
    await engine.start();
    await pumpEventQueue();

    await engine.setAutoEnabled(false);
    expect(engine.autoEnabled, isFalse);
    SyncOutboxService.notifyWrite('trips', 't1');
    expect(sched.hasPendingOneShot, isFalse, reason: '关自动时不应排 debounce');
    sched.fireOneShot();
    sched.firePeriodic();
    await pumpEventQueue();
    expect(transport.upsertCalls, 0);
    expect(await engine.outbox.pendingEntry('trips', 't1'), isNotNull);

    await engine.setAutoEnabled(true);
    await pumpEventQueue();
    expect(transport.tables['trips_sync']?['t1'], isNotNull);
  });

  test('H2 锁忙排队：pull 占锁期间的写事件不丢，本轮结束后自动补推', () async {
    await seedTrip('t1');
    gateClose();
    final running = engine.syncNow(push: false, manual: true); // 占住锁
    await Future<void>.delayed(Duration.zero);

    SyncOutboxService.notifyWrite('trips', 't1'); // 排 debounce
    sched.fireOneShot(); // push 撞锁 → 应排队而非丢弃
    await Future<void>.delayed(Duration.zero);
    expect(transport.upsertCalls, 0, reason: '锁忙时不应并发上行');

    gateOpen();
    await running;
    await pumpEventQueue();
    expect(transport.tables['trips_sync']?['t1'], isNotNull,
        reason: '被延后的 push 必须在当前轮结束后补上');
  });

  test('三档频率：默认实时；周期任务顺带上行（经济档除外）', () async {
    expect(engine.freq, SyncFreq.realtime, reason: '默认实时 = 即改即同步');

    await engine.setFreq(SyncFreq.economy);
    expect(prefs.getString('sync.freq'), 'economy');
    expect(SyncFreq.economy.intervalSeconds, 60);
    expect(SyncFreq.realtime.intervalSeconds, 5);
    expect(SyncFreq.standard.intervalSeconds, 15);
    expect(SyncFreq.economy.periodicPush, isFalse);
    expect(SyncFreq.realtime.periodicPush, isTrue);
  });

  test('M9 登出：运行时状态清干净，新账号不顶着上一账号的节流/挂起请求', () async {
    await engine.start();
    await pumpEventQueue();
    expect(engine.outbox, isNotNull);
    engine.resetRuntimeState();
    expect(engine.throttleUntil, isNull);
    expect(engine.wifiBlockedNow, isFalse);
    expect(engine.collabContextKnown, isFalse);
  });
}
