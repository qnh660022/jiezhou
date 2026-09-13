/// 今日口径纯逻辑（V2.6.6.2 §8.2 / D1）。
///
/// 全部为纯函数 + 不可变数据：不碰数据库、不读全局时钟（`now` 可注入），
/// 因此时区回退、多行程取最近、日期边界都能被单测穷举
/// （test/features/today/today_scope_test.dart）。
///
/// 口径（SPEC，不得更改）：
/// * 「进行中行程」判定用**设备今日** ∈ [startEpochDay, endEpochDay]；多行程同时
///   进行 → 取开始日期最近的一个，其余数量用于副标题「另有 N 个行程进行中」；
/// * 「今日」（驾驶舱内容）用**目的地当地日期**：行程目的地有时区数据时按当地算，
///   否则回退设备本地时区；
/// * 「今日花销」= 关联账本中 `date == 行程今日` 的支出合计（退款负数自然冲减）。
library;
import '../../core/date_utils.dart';
import '../../data/seed/city_timezones.dart';

/// 行程的"跨度"视图（只取判定所需字段，避免依赖 drift 行）。
class TripSpan {
  const TripSpan({
    required this.id,
    required this.startEpochDay,
    required this.endEpochDay,
    this.name = '',
    this.destination = '',
    this.archived = false,
  });

  final String id;
  final String name;
  final int startEpochDay;
  final int endEpochDay;
  final String destination;
  final bool archived;

  int get days => tripDays(startEpochDay, endEpochDay);

  /// 设备今日是否落在行程区间内（进行中判定；§8.1）。
  bool containsDeviceDay(int deviceToday) =>
      !archived && startEpochDay > 0 && endEpochDay >= startEpochDay &&
      deviceToday >= startEpochDay && deviceToday <= endEpochDay;
}

/// 目的地"今日"完整口径。
class TodayScope {
  const TodayScope({
    required this.tripId,
    required this.tripTodayEpochDay,
    required this.deviceTodayEpochDay,
    required this.destinationOffsetMinutes,
    required this.usesDestinationTimezone,
    required this.localNow,
    required this.startEpochDay,
    required this.endEpochDay,
  });

  final String tripId;

  /// 行程"今日"（目的地当地日期；无时区数据时为设备今日）。
  final int tripTodayEpochDay;

  /// 设备当地日期。
  final int deviceTodayEpochDay;

  /// 目的地 UTC 偏移（分钟）；无时区数据时为设备当前偏移。
  final int destinationOffsetMinutes;

  /// 是否用到了目的地时区数据（false = 回退设备时区）。
  final bool usesDestinationTimezone;

  /// 目的地当地时刻（用于 AppBar 展示）。
  final DateTime localNow;

  final int startEpochDay;
  final int endEpochDay;

  /// 行程总天数。
  int get totalDays => tripDays(startEpochDay, endEpochDay);

  /// 第几天（1 起，越界夹紧）。
  int get dayIndex => dayIndexOf(startEpochDay, endEpochDay, tripTodayEpochDay);

  /// 行程时间进度 0..1（用于页顶进度带；单日行程恒 1.0）。
  double get progress {
    final total = totalDays;
    if (total <= 1) return 1;
    final passed = tripTodayEpochDay - startEpochDay;
    final v = (passed + 1) / total;
    return v.clamp(0.0, 1.0);
  }

  /// 时差角标（`UTC+8`）。
  String get offsetLabel => utcOffsetLabel(destinationOffsetMinutes);

  /// 当地与设备的相对时差文案（`比设备快 1 小时` / `与设备同时`）。
  String get deltaLabel {
    final delta = destinationOffsetMinutes - deviceOffsetMinutes;
    if (delta == 0) return '与设备同时';
    final abs = delta.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    final amount = m == 0 ? '$h 小时' : (h == 0 ? '$m 分钟' : '$h 小时 $m 分');
    return delta > 0 ? '比设备快 $amount' : '比设备慢 $amount';
  }

  /// 设备当前 UTC 偏移（由 [localNow] 推算，避免再读一次时钟）。
  int get deviceOffsetMinutes => localNow.timeZoneOffset.inMinutes;
}

/// 设备时间换算到指定偏移下的 epochDay。
///
/// epochDay 的定义（core/date_utils）是"本地日期距 1970-01-01 的天数"，
/// 因此这里先按偏移平移时刻，再取其 UTC 日期分量，得到同一口径的天数。
int epochDayAtOffset(DateTime now, int offsetMinutes) {
  final shifted = now.toUtc().add(Duration(minutes: offsetMinutes));
  return DateTime.utc(shifted.year, shifted.month, shifted.day)
          .millisecondsSinceEpoch ~/
      86400000;
}

/// 解析某行程的"今日"口径（§8.2）。
TodayScope resolveTodayScope({
  required TripSpan trip,
  DateTime? now,
}) {
  final deviceNow = now ?? DateTime.now();
  final deviceOffset = deviceNow.timeZoneOffset.inMinutes;
  final destOffset = destinationOffsetMinutes(trip.destination);
  final useDest = destOffset != null;
  final offset = destOffset ?? deviceOffset;
  final deviceToday = dateToEpochDay(deviceNow);
  final tripToday = useDest
      ? epochDayAtOffset(deviceNow, offset)
      : deviceToday;
  return TodayScope(
    tripId: trip.id,
    tripTodayEpochDay: tripToday,
    deviceTodayEpochDay: deviceToday,
    destinationOffsetMinutes: offset,
    usesDestinationTimezone: useDest,
    localNow: deviceNow.toUtc().add(Duration(minutes: offset)),
    startEpochDay: trip.startEpochDay,
    endEpochDay: trip.endEpochDay,
  );
}

/// 进行中行程的挑选结果。
class ActiveTripPick {
  const ActiveTripPick({
    required this.trip,
    required this.othersCount,
    required this.deviceTodayEpochDay,
  });

  final TripSpan trip;

  /// 同时进行的其他行程数量（副标题「另有 N 个行程进行中」）。
  final int othersCount;

  final int deviceTodayEpochDay;
}

/// 挑选"进行中行程"：设备今日落在区间内，取**开始日期最近**的一个。
///
/// 并列（同一天开始）时取结束日期较晚的（旅程更长，对用户更有意义），
/// 仍并列则按 id 稳定排序，保证同一份输入永远得到同一个结果（可测）。
ActiveTripPick? pickActiveTrip(
  List<TripSpan> trips, {
  DateTime? now,
  int? deviceTodayOverride,
}) {
  final today = deviceTodayOverride ?? dateToEpochDay(now ?? DateTime.now());
  final active = trips.where((t) => t.containsDeviceDay(today)).toList();
  if (active.isEmpty) return null;
  active.sort((a, b) {
    final byStart = b.startEpochDay.compareTo(a.startEpochDay);
    if (byStart != 0) return byStart;
    final byEnd = b.endEpochDay.compareTo(a.endEpochDay);
    if (byEnd != 0) return byEnd;
    return a.id.compareTo(b.id);
  });
  return ActiveTripPick(
    trip: active.first,
    othersCount: active.length - 1,
    deviceTodayEpochDay: today,
  );
}

/// 「进行中行程」列表（含全部同时进行的行程，按开始日期降序）。
List<TripSpan> activeTrips(List<TripSpan> trips, {int? deviceToday}) {
  final today = deviceToday ?? todayEpochDay();
  final active = trips.where((t) => t.containsDeviceDay(today)).toList()
    ..sort((a, b) => b.startEpochDay.compareTo(a.startEpochDay));
  return active;
}

/// 今日花销合计（退款为负，自然冲减；预付不计入日常合计，与账本统计口径一致）。
///
/// 入参是最小化的事件元组，避免依赖 domain 层枚举：
/// (dateEpochDay, amountCents, type)。
int todaySpendCents(
  Iterable<({int dateEpochDay, int amountCents, String type})> expenses,
  int todayEpochDay,
) {
  var total = 0;
  for (final e in expenses) {
    if (e.dateEpochDay != todayEpochDay) continue;
    if (e.type == 'prepay') continue; // 预付款单列口径，不进日常合计
    total += e.amountCents;
  }
  return total;
}

/// 今日安排（当天行程项），有时间的按时间升序、无时间的排末尾。
List<T> todayItemsByDay<T>(
  Iterable<T> items,
  int todayEpochDay,
  int Function(T) dayOf,
  int? Function(T) startTimeMinOf, {
  int? Function(T)? sortOrderOf,
}) {
  final picked = items.where((i) => dayOf(i) == todayEpochDay).toList();
  picked.sort((a, b) {
    final at = startTimeMinOf(a);
    final bt = startTimeMinOf(b);
    // 有时间的排前面
    if ((at == null) != (bt == null)) return at == null ? 1 : -1;
    if (at != null && bt != null && at != bt) return at.compareTo(bt);
    final as = sortOrderOf?.call(a) ?? 0;
    final bs = sortOrderOf?.call(b) ?? 0;
    return as.compareTo(bs);
  });
  return picked;
}
