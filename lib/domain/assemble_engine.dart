/// 想去装配台引擎（V2.7.2 S7，纯 Dart，无 IO 无时钟）。
///
/// 落点推算 + 候选排序 + 容量计算。所有入参为不可变记录快照
/// （[TripItemRecord] 正式卡集合 / [WishlistRecord] 候选）；
/// 备胎（backupOf != null）由调用方过滤，本引擎不感知。
library;
import 'models.dart';
import 'records.dart';

/// 行程节奏三档（行程级 `Trips.pace` 列：relaxed/standard/tight）。
enum TripPace { relaxed, standard, tight }

TripPace parseTripPace(String? raw) => switch (raw) {
      'relaxed' => TripPace.relaxed,
      'tight' => TripPace.tight,
      _ => TripPace.standard,
    };

String tripPaceLabel(TripPace pace) => switch (pace) {
      TripPace.relaxed => '松弛',
      TripPace.standard => '标准',
      TripPace.tight => '紧凑',
    };

/// 容量档（分钟/天）。
const Map<TripPace, int> kDayCapacity = {
  TripPace.relaxed: 360,
  TripPace.standard: 480,
  TripPace.tight: 600,
};

/// 类型×时段窗（分钟制，闭开区间 [from, to)；仅约束自动落点，附录 T2）。
const Map<String, (int, int)> kTypeWindow = {
  'attraction': (420, 1140),
  'food': (390, 1290),
  'transport': (0, 1440),
  'stay': (840, 1440),
  'note': (0, 1440),
};

/// 落点扫描起点与步长（07:00 起、30 分钟粒度，收口 1440−d）。
const int kScanFromMin = 420;
const int kScanStepMin = 30;

/// 已排卡无 durationMin 时占用的默认区间长度。
const int kDefaultOccupancyMin = 60;

sealed class AssembleResult {
  const AssembleResult();
}

/// 找到落点：[startMin] 为当天分钟制时刻。
class Placed extends AssembleResult {
  const Placed(this.startMin);
  final int startMin;
}

/// 候选未估时 → 需补时长。
class NeedDuration extends AssembleResult {
  const NeedDuration();
}

/// 当天剩余容量不足：[rem] 为剩余分钟。
class CapacityFull extends AssembleResult {
  const CapacityFull(this.rem);
  final int rem;
}

/// 当天无空档：建议换天（由面板层调 [rankAlternativeDays] 填充）。
class NoSlot extends AssembleResult {
  const NoSlot({this.suggestedDays = const []});
  final List<int> suggestedDays;
}

/// 当天正式卡已占容量（分钟）。durationMin 为 null 的卡按 0 计。
int usedCapacityOf(List<TripItemRecord> dayItems) {
  var sum = 0;
  for (final it in dayItems) {
    final d = it.durationMin;
    if (d != null && d > 0) sum += d;
  }
  return sum;
}

/// 核心入口：为候选 [candidate] 在「当天正式卡集合 [dayItems]」中找落点。
///
/// 1. d == null → NeedDuration；
/// 2. rem = kDayCapacity[pace] − ΣdurationMin(D)；rem < d → CapacityFull(rem)；
/// 3. L = 已排卡 [start, start+duration) 区间集（null duration 占 60 分钟）；
/// 4. t 从 420 到 1440−d 步长 30：不与 L 相交且 t 落在类型窗内 → Placed(t)；
/// 5. 无命中 → NoSlot。
AssembleResult findSlot({
  required List<TripItemRecord> dayItems,
  required WishlistRecord candidate,
  required TripPace pace,
}) {
  final d = candidate.durationMin;
  if (d == null || d <= 0) return const NeedDuration();
  final rem = kDayCapacity[pace]! - usedCapacityOf(dayItems);
  if (rem < d) return CapacityFull(rem);

  // 已排卡占用区间（null duration 视为占 60 分钟默认区间）
  final occupied = <(int, int)>[
    for (final it in dayItems)
      if (it.startTimeMin != null)
        (
          it.startTimeMin!,
          it.startTimeMin! +
              ((it.durationMin == null || it.durationMin! <= 0)
                  ? kDefaultOccupancyMin
                  : it.durationMin!)
        ),
  ];

  final window = kTypeWindow[candidate.type] ?? (0, 1440);
  final lastStart = 1440 - d;
  for (var t = kScanFromMin; t <= lastStart; t += kScanStepMin) {
    // 条件 A：与所有已排区间不相交
    var clash = false;
    for (final (from, to) in occupied) {
      if (t < to && from < t + d) {
        clash = true;
        break;
      }
    }
    if (clash) continue;
    // 条件 B：起点落在类型窗内
    if (t >= window.$1 && t < window.$2) return Placed(t);
  }
  return const NoSlot();
}

/// 换天建议：对行程每天算剩余容量，rem' ≥ d 的天按 rem' 降序取前 3。
/// [daysByEpochDay] = 行程各天（epochDay → 该天正式卡）。
List<int> rankAlternativeDays({
  required Map<int, List<TripItemRecord>> daysByEpochDay,
  required WishlistRecord candidate,
  required TripPace pace,
}) {
  final d = candidate.durationMin;
  if (d == null || d <= 0) return const [];
  final scored = <(int, int)>[];
  daysByEpochDay.forEach((day, items) {
    final rem = kDayCapacity[pace]! - usedCapacityOf(items);
    if (rem >= d) scored.add((day, rem));
  });
  scored.sort((a, b) {
    final byRem = b.$2.compareTo(a.$2);
    if (byRem != 0) return byRem;
    return a.$1.compareTo(b.$1);
  });
  return [for (final s in scored.take(3)) s.$1];
}

/// 候选类型窗与当天可扫描范围是否有交集（无交集 → 置灰不可点）。
bool windowIntersectsDay(String type, int durationMin) {
  final window = kTypeWindow[type] ?? (0, 1440);
  final lastStart = 1440 - durationMin;
  return window.$1 <= lastStart && window.$2 > kScanFromMin;
}

/// tag 权重：必去 0 < 经典 1 < 小众/亲子 2 < 其他/null 3。
int rankTagWeight(String? tag) => switch (tag) {
      '必去' => 0,
      '经典' => 1,
      '小众' || '亲子' => 2,
      _ => 3,
    };

/// 候选排序（§10.2）：tag 权重升序 → 同分按 |durationMin − rem| 升序
/// （未估时排最后）→ 再按 sortOrder 升序。
int compareCandidates(
  WishlistRecord a,
  WishlistRecord b, {
  required int rem,
}) {
  final wa = rankTagWeight(a.tag);
  final wb = rankTagWeight(b.tag);
  if (wa != wb) return wa.compareTo(wb);
  final da = a.durationMin;
  final db = b.durationMin;
  final fa = da == null ? 1 : (da - rem).abs();
  final fb = db == null ? 1 : (db - rem).abs();
  if (da == null && db != null) return 1;
  if (da != null && db == null) return -1;
  if (fa != fb) return fa.compareTo(fb);
  return a.sortOrder.compareTo(b.sortOrder);
}
