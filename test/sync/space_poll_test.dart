// V2.6.6.2 §10.4：页面可见期 30s 短轮询、不可见停止、写后立即 pull
// （复用 test/sync/sync_engine_schedule_test.dart 的 FakeScheduler 范式）。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/sync/sync_engine.dart';
import 'package:travel_assistant/data/sync/sync_transport_fake.dart';
import 'package:travel_assistant/data/sync/sync_visibility_poller.dart';
import 'package:travel_assistant/platform/network_probe.dart';

class FakeTimer implements Cancellable {
  FakeTimer(this.action);
  final void Function() action;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  void fire() {
    if (!cancelled) action();
  }
}

class FakeScheduler implements SyncScheduler {
  final List<FakeTimer> oneShot = [];
  final List<FakeTimer> periodicTimers = [];

  @override
  Cancellable schedule(Duration delay, void Function() action) {
    final t = FakeTimer(action);
    oneShot.add(t);
    return t;
  }

  @override
  Cancellable periodic(Duration interval, void Function() action) {
    final t = FakeTimer(action);
    periodicTimers.add(t);
    return t;
  }

  List<FakeTimer> get livePeriodic =>
      periodicTimers.where((t) => !t.cancelled).toList();

  void firePeriodic() {
    for (final t in [...periodicTimers]) {
      t.fire();
    }
  }

  void fireOneShot() {
    for (final t in [...oneShot]) {
      t.fire();
    }
  }
}

void main() {
  late AppDatabase db;
  late SyncTransportFake transport;
  late SharedPreferences prefs;
  late FakeScheduler sched;
  late SyncEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'sync_bootstrapped_u1': true});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase();
    transport = SyncTransportFake()..user = 'u1';
    sched = FakeScheduler();
    engine = SyncEngine.init(db, transport, prefs,
        scheduler: sched, probe: () async => NetKind.wifi);
  });

  tearDown(() async {
    engine.dispose();
    SyncEngine.detach();
    await db.close();
  });

  group('短轮询契约（§4.2）', () {
    test('默认间隔 30s，且 3600/30 = 120 次/小时（对齐 §9 预算）', () {
      expect(kCollabPollInterval, const Duration(seconds: 30));
      expect(kCollabPollInterval.inSeconds, 30);
      expect(3600 ~/ kCollabPollInterval.inSeconds, 120);
    });

    test('可见期：进入立即拉一次 + 每 30s 一次', () {
      var ticks = 0;
      final poller = SyncVisibilityPoller(
        scheduler: sched,
        onTick: () => ticks++,
      );

      poller.start();
      expect(ticks, 1, reason: '进入可见态应立即拉一次，不必等满 30s');
      expect(poller.running, isTrue);
      expect(sched.livePeriodic, hasLength(1), reason: '只应挂一个周期任务');

      sched.firePeriodic();
      sched.firePeriodic();
      expect(ticks, 3);
      expect(poller.ticks, 2, reason: 'ticks 只统计周期触发（进入那次不计）');
    });

    test('页面不可见 / 退后台 → 立即停（周期任务被取消，不再发请求）', () {
      var ticks = 0;
      final poller = SyncVisibilityPoller(scheduler: sched, onTick: () => ticks++);
      poller.start();
      expect(ticks, 1);

      poller.stop();
      expect(poller.running, isFalse);
      expect(sched.livePeriodic, isEmpty, reason: '停止必须取消定时器，不能空转');

      sched.firePeriodic();
      expect(ticks, 1, reason: '停止后触发遗留定时器也不应再发请求');
    });

    test('start 幂等：重复 start 不会叠加定时器（请求量不会翻倍）', () {
      var ticks = 0;
      final poller = SyncVisibilityPoller(scheduler: sched, onTick: () => ticks++);
      poller.start();
      poller.start();
      poller.start();
      expect(sched.periodicTimers, hasLength(1));
      sched.firePeriodic();
      expect(ticks, 2);
    });

    test('生命周期翻译：resumed 才可见，其余一律停', () {
      var ticks = 0;
      final poller = SyncVisibilityPoller(scheduler: sched, onTick: () => ticks++);
      poller.onLifecycleChanged(true);
      expect(poller.running, isTrue);
      poller.onLifecycleChanged(false); // paused / inactive / hidden / detached
      expect(poller.running, isFalse);
      sched.firePeriodic();
      expect(ticks, 1);
    });

    test('细粒度可见性闸门：定时器到点但页面已被别的 Tab 盖住 → 不发请求', () {
      var ticks = 0;
      var onTop = false;
      final poller = SyncVisibilityPoller(
        scheduler: sched,
        onTick: () => ticks++,
        isActive: () => onTop,
      );
      poller.start();
      expect(ticks, 1, reason: '进入时的首拉不受闸门约束');

      sched.firePeriodic();
      expect(ticks, 1, reason: '不可见 → 不计 tick 也不发请求');
      expect(poller.ticks, 0);

      onTop = true;
      sched.firePeriodic();
      expect(ticks, 2);
      expect(poller.ticks, 1);
    });

    test('dispose 等价于 stop（页面卸载不留定时器）', () {
      final poller = SyncVisibilityPoller(scheduler: sched, onTick: () {});
      poller.start();
      poller.dispose();
      expect(sched.livePeriodic, isEmpty);
    });

    test('用量预算口径：可见 1 小时的实测请求数 ≤ 120', () {
      var now = DateTime(2026, 9, 15, 12, 0, 0);
      final poller = SyncVisibilityPoller(
        scheduler: sched,
        onTick: () {},
        clock: () => now,
      );
      poller.start();
      // 模拟可见期整整 1 小时、每 30s 触发一次
      for (var i = 0; i < 120; i++) {
        now = now.add(const Duration(seconds: 30));
        sched.firePeriodic();
      }
      expect(poller.ticks, 120);
      poller.stop();
      expect(poller.visibleElapsed.inMinutes, 60);
      // 实测换算：120 次 / 1 小时 = 120 次/小时，正好等于预算上限
      expect(poller.requestsPerHour, lessThanOrEqualTo(120.5));
    });
  });

  group('写后读（§4.2：任何协作写 RPC 成功后立即 drain + pull）', () {
    test('afterCollabWrite 立刻触发一轮 pull（不等周期）', () async {
      expect(transport.fetchCalls, 0);
      await engine.afterCollabWrite();
      await pumpEventQueue();
      expect(transport.fetchCalls, greaterThan(0),
          reason: '写后必须立刻拉一次增量，保证自己看到合流结果');
    });

    test('写后读走「先拉后推」：本地 pending 在同轮里补齐上行', () async {
      await db.into(db.travelSpaces).insert(TravelSpacesCompanion.insert(
            id: 's1',
            name: '空间',
            createdBy: 'u1',
            createdMs: 1000,
            updatedMs: 1000,
          ));
      await engine.outbox.enqueue('travel_spaces', 's1', 'upsert', 5000);

      await engine.afterCollabWrite();
      await pumpEventQueue();
      expect(transport.tables['spaces_sync']?['s1']?['name'], '空间');
      expect(await engine.outbox.pendingEntry('travel_spaces', 's1'), isNull);
    });
  });
}
