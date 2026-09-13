// V2.6.6.2 §10.6：今日口径纯逻辑单测（时区回退、多行程取最近、日期边界）。
//
// 口径来源 §8.1 / §8.2：
//   * 「进行中行程」用**设备今日**判定，多行程同时进行取开始日期最近的一个；
//   * 「今日」用**目的地当地日期**（无时区数据回退设备时区）；
//   * 今日花销 = 当日支出合计（退款负数冲减、预付不入日常合计）。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/data/seed/city_timezones.dart';
import 'package:travel_assistant/features/today/today_scope.dart';

void main() {
  // 固定一个 UTC 时刻做基准：2026-09-15 20:00 UTC
  final baseUtc = DateTime.utc(2026, 9, 15, 20, 0);

  group('目的地时区表', () {
    test('国内城市一律 UTC+8，识别不到返回 null（回退设备时区）', () {
      expect(destinationOffsetMinutes('北京'), 480);
      expect(destinationOffsetMinutes('成都-稻城'), 480);
      expect(destinationOffsetMinutes('乌鲁木齐'), 480);
      expect(destinationOffsetMinutes('亚特兰蒂斯'), isNull);
      expect(destinationOffsetMinutes(''), isNull);
    });

    test('海外城市/国家解析（精确 → 包含 → 国家兜底）', () {
      expect(destinationOffsetMinutes('东京'), 540);
      expect(destinationOffsetMinutes('东京-大阪'), 540);
      expect(destinationOffsetMinutes('Tokyo Narita'), 540);
      expect(destinationOffsetMinutes('纽约'), -300);
      expect(destinationOffsetMinutes('London'), 0);
      expect(destinationOffsetMinutes('澳大利亚'), 600);
      expect(destinationOffsetMinutes('新西兰南岛'), 720);
    });

    test('多城串取第一个命中的城市', () {
      expect(destinationOffsetMinutes('上海-东京'), 480);
      expect(destinationOffsetMinutes('东京-上海'), 540);
    });

    test('时差角标格式（含半小时/45 分钟偏移）', () {
      expect(utcOffsetLabel(480), 'UTC+8');
      expect(utcOffsetLabel(0), 'UTC+0');
      expect(utcOffsetLabel(-300), 'UTC-5');
      expect(utcOffsetLabel(330), 'UTC+5:30');
      expect(utcOffsetLabel(345), 'UTC+5:45');
    });
  });

  group('今日口径（时区换算与回退）', () {
    test('无时区数据 → 回退设备时区，行程今日 == 设备今日', () {
      final scope = resolveTodayScope(
        trip: const TripSpan(
            id: 't1', startEpochDay: 20000, endEpochDay: 20010, destination: '未知地'),
        now: baseUtc,
      );
      expect(scope.usesDestinationTimezone, isFalse);
      expect(scope.destinationOffsetMinutes, baseUtc.timeZoneOffset.inMinutes);
      expect(scope.tripTodayEpochDay, scope.deviceTodayEpochDay);
    });

    test('有时区数据 → 按目的地当地日期（跨日边界）', () {
      // 2026-09-15 20:00 UTC：东京当地已是 9/16，北京当地 9/16 05:00
      final tokyo = resolveTodayScope(
        trip: const TripSpan(
            id: 't1', startEpochDay: 20000, endEpochDay: 20010, destination: '东京'),
        now: baseUtc,
      );
      expect(tokyo.usesDestinationTimezone, isTrue);
      expect(tokyo.destinationOffsetMinutes, 540);
      expect(tokyo.tripTodayEpochDay, epochDayAtOffset(baseUtc, 540));
      expect(tokyo.localNow.hour, 5);
      expect(tokyo.localNow.day, 16);
    });

    test('西半球负偏移：洛杉矶当地仍在前一天', () {
      final la = resolveTodayScope(
        trip: const TripSpan(
            id: 't1', startEpochDay: 20000, endEpochDay: 20010, destination: '洛杉矶'),
        now: baseUtc,
      );
      expect(la.destinationOffsetMinutes, -480);
      expect(la.localNow.day, 15);
      expect(la.localNow.hour, 12);
      expect(la.tripTodayEpochDay, epochDayAtOffset(baseUtc, -480));
    });

    test('第 N 天 / 总天数 / 进度', () {
      final start = dateToEpochDay(DateTime.utc(2026, 9, 13));
      final scope = resolveTodayScope(
        trip: TripSpan(
            id: 't1',
            startEpochDay: start,
            endEpochDay: start + 6,
            destination: '东京'),
        now: baseUtc,
      );
      // 东京当地 9/16 → 第 4 天 / 共 7 天
      expect(scope.totalDays, 7);
      expect(scope.dayIndex, 4);
      expect(scope.progress, closeTo(4 / 7, 1e-9));
    });

    test('单日行程进度为 1.0（不会出现 1/1 之外的边界）', () {
      final day = dateToEpochDay(DateTime.utc(2026, 9, 15));
      final scope = resolveTodayScope(
        trip: TripSpan(id: 't1', startEpochDay: day, endEpochDay: day, destination: ''),
        now: baseUtc,
      );
      expect(scope.totalDays, 1);
      expect(scope.progress, 1.0);
      expect(scope.dayIndex, 1);
    });

    test('时差文案', () {
      final tokyo = resolveTodayScope(
        trip: const TripSpan(
            id: 't1', startEpochDay: 1, endEpochDay: 9, destination: '东京'),
        now: DateTime.utc(2026, 9, 15, 4, 0), // 设备 UTC → 东京快 9 小时
      );
      expect(tokyo.deltaLabel, '比设备快 9 小时');
    });
  });

  group('进行中行程判定（§8.1）', () {
    int day(int y, int m, int d) => dateToEpochDay(DateTime.utc(y, m, d));
    final today = day(2026, 9, 15);

    test('边界：开始日与结束日都算进行中', () {
      expect(
          const TripSpan(id: 'a', startEpochDay: 0, endEpochDay: 0)
              .containsDeviceDay(0),
          isFalse,
          reason: 'startEpochDay <= 0 视为未设置日期，不算进行中');
      final t = TripSpan(
          id: 'a', startEpochDay: today, endEpochDay: today + 3);
      expect(t.containsDeviceDay(today), isTrue);
      expect(t.containsDeviceDay(today + 3), isTrue);
      expect(t.containsDeviceDay(today - 1), isFalse);
      expect(t.containsDeviceDay(today + 4), isFalse);
    });

    test('归档行程不算进行中', () {
      final t = TripSpan(
          id: 'a', startEpochDay: today, endEpochDay: today + 3, archived: true);
      expect(t.containsDeviceDay(today), isFalse);
    });

    test('无进行中行程 → null（卡片不渲染，不是置灰）', () {
      final trips = [
        TripSpan(id: 'a', startEpochDay: today - 30, endEpochDay: today - 20),
        TripSpan(id: 'b', startEpochDay: today + 5, endEpochDay: today + 9),
      ];
      expect(pickActiveTrip(trips, deviceTodayOverride: today), isNull);
    });

    test('多行程同时进行 → 取开始日期最近的一个，并统计其余数量', () {
      final trips = [
        TripSpan(id: 'old', startEpochDay: today - 5, endEpochDay: today + 5),
        TripSpan(id: 'new', startEpochDay: today - 1, endEpochDay: today + 2),
        TripSpan(id: 'mid', startEpochDay: today - 3, endEpochDay: today + 3),
      ];
      final pick = pickActiveTrip(trips, deviceTodayOverride: today);
      expect(pick, isNotNull);
      expect(pick!.trip.id, 'new');
      expect(pick.othersCount, 2);
      expect(pick.deviceTodayEpochDay, today);
    });

    test('同一天开始 → 取结束较晚者；完全并列时结果稳定（按 id）', () {
      final a = TripSpan(id: 'b', startEpochDay: today, endEpochDay: today + 2);
      final b = TripSpan(id: 'a', startEpochDay: today, endEpochDay: today + 5);
      expect(pickActiveTrip([a, b], deviceTodayOverride: today)!.trip.id, 'a');
      final c = TripSpan(id: 'z', startEpochDay: today, endEpochDay: today + 5);
      final d = TripSpan(id: 'y', startEpochDay: today, endEpochDay: today + 5);
      expect(pickActiveTrip([c, d], deviceTodayOverride: today)!.trip.id, 'y');
    });

    test('activeTrips 返回全部进行中行程（开始日期降序）', () {
      final trips = [
        TripSpan(id: 'old', startEpochDay: today - 5, endEpochDay: today + 5),
        TripSpan(id: 'new', startEpochDay: today - 1, endEpochDay: today + 2),
        TripSpan(id: 'past', startEpochDay: today - 30, endEpochDay: today - 20),
      ];
      expect(activeTrips(trips, deviceToday: today).map((e) => e.id).toList(),
          ['new', 'old']);
    });
  });

  group('今日花销口径', () {
    final today = 20000;

    test('只统计当日；退款负数冲减', () {
      final total = todaySpendCents([
        (dateEpochDay: today, amountCents: 3800, type: 'normal'),
        (dateEpochDay: today, amountCents: -500, type: 'refund'),
        (dateEpochDay: today - 1, amountCents: 9999, type: 'normal'),
      ], today);
      expect(total, 3300);
    });

    test('预付不计入日常合计（与账本统计同口径）', () {
      final total = todaySpendCents([
        (dateEpochDay: today, amountCents: 5000, type: 'prepay'),
        (dateEpochDay: today, amountCents: 1200, type: 'normal'),
      ], today);
      expect(total, 1200);
    });

    test('无当日账单 → 0（UI 显示"今天还没记账"）', () {
      expect(
          todaySpendCents(
              [(dateEpochDay: today - 2, amountCents: 800, type: 'normal')], today),
          0);
    });
  });

  group('今日安排排序', () {
    test('有时间的按时间升序、无时间的排末尾', () {
      final items = [
        (name: 'c', day: 5, time: null, order: 1),
        (name: 'a', day: 5, time: 540, order: 3),
        (name: 'b', day: 5, time: 480, order: 2),
        (name: 'x', day: 6, time: 400, order: 0),
      ];
      final picked = todayItemsByDay(
        items,
        5,
        (e) => e.day,
        (e) => e.time,
        sortOrderOf: (e) => e.order,
      );
      expect(picked.map((e) => e.name).toList(), ['b', 'a', 'c']);
    });

    test('同时间按 sortOrder', () {
      final items = [
        (name: 'second', day: 5, time: 540, order: 9),
        (name: 'first', day: 5, time: 540, order: 1),
      ];
      final picked =
          todayItemsByDay(items, 5, (e) => e.day, (e) => e.time, sortOrderOf: (e) => e.order);
      expect(picked.map((e) => e.name).toList(), ['first', 'second']);
    });
  });

  group('epochDayAtOffset 本身', () {
    test('整点边界：偏移后跨日', () {
      final t = DateTime.utc(2026, 9, 15, 23, 30);
      expect(epochDayAtOffset(t, 0), dateToEpochDay(DateTime.utc(2026, 9, 15)));
      expect(epochDayAtOffset(t, 60), dateToEpochDay(DateTime.utc(2026, 9, 16)));
      expect(epochDayAtOffset(DateTime.utc(2026, 9, 15, 1, 0), -300),
          dateToEpochDay(DateTime.utc(2026, 9, 14)));
    });
  });
}
