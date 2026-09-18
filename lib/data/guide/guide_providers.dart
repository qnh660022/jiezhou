/// 攻略 Riverpod providers（§7.4）。
library;
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/guide_ref.dart';
import '../db/database.dart';
import '../providers.dart' show tripsRepoProvider, wishlistRepoProvider;
import 'guide_cache.dart';
import 'guide_crawler.dart';
import 'guide_http.dart';
import 'guide_service.dart';

/// 服务单例（攻略与同步层完全隔离，纯本地不云端）。
final guideServiceProvider = Provider<GuideService>((ref) => GuideService(
      cache: GuideCache(),
      http: GuideHttp.instance,
      crawlLayer: GuideCrawlLayer(GuideHttp.instance),
    ));

/// 行程攻略 future（extra 传 tripId+destination）。
final guideByTripProvider =
    FutureProvider.family<GuideResult, String>((ref, tripId) async {
  final trip = await ref.read(tripsRepoProvider).getById(tripId);
  final dest = trip?.destination ?? '';
  return ref.read(guideServiceProvider).getGuide(dest);
});

/// 当前正在生成的攻略草稿城市 key（AI 生成攻略用）。
///
/// 工具执行器每轮都会新建，草稿 key 必须落在 provider 里才能跨工具调用传递。
final guideDraftKeyProvider = StateProvider<String?>((ref) => null);

// ===== V2.7.2 S5：攻略×行程互链 =====

/// 行程互链快照：正式卡与想去池中带 guideRef 的行（只读视图）。
class GuideLinkSnapshot {
  const GuideLinkSnapshot({
    this.arrangedDaysByRef = const {},
    this.wishlistedRefs = const {},
  });

  /// guideRef → 已安排天序号列表（= dateEpochDay − startEpochDay + 1，升序）。
  /// 攻略页徽记「已安排 · 第 X 天」与顺延引擎天然联动（改天后日期随行更新）。
  final Map<String, List<int>> arrangedDaysByRef;

  /// 已在想去池的 guideRef 集合。
  final Set<String> wishlistedRefs;

  List<int> daysFor(String ref) => arrangedDaysByRef[ref] ?? const [];
  bool isWishlisted(String ref) => wishlistedRefs.contains(ref);
}

/// 种子该栏 name → 序号（guideRef 写入与徽记匹配共用；走既有取数优先级链，
/// 不建第二套缓存）。
final guideSeedNameIndexProvider =
    FutureProvider.family<Map<String, Map<String, int>>, String>(
        (ref, cityKey) async {
  final seed =
      await ref.watch(guideServiceProvider).seedSource.getSeed(cityKey);
  final sections = (seed?['sections'] as Map?) ?? const {};
  final out = <String, Map<String, int>>{};
  for (final sec in GuideRef.knownSections) {
    final rows = (sections[sec] as List?) ?? const [];
    final m = <String, int>{};
    for (var i = 0; i < rows.length; i++) {
      final n = ((rows[i] as Map)['name'] ?? '').toString();
      if (n.isNotEmpty && !m.containsKey(n)) m[n] = i;
    }
    out[sec] = m;
  }
  return out;
});

/// 行程互链流：trip + 正式卡 + 想去池三路 combine。
final guideLinkProvider =
    StreamProvider.family<GuideLinkSnapshot, String>((ref, tripId) {
  final repo = ref.watch(tripsRepoProvider);
  final wishRepo = ref.watch(wishlistRepoProvider);
  return _Latest3(repo.watchTrip(tripId), repo.watchItems(tripId),
          wishRepo.watchByTrip(tripId))
      .map<GuideLinkSnapshot>((trip, items, wishes) {
    final start = trip?.startEpochDay;
    final arranged = <String, List<int>>{};
    for (final it in items) {
      final r = it.guideRef;
      if (r == null || r.isEmpty) continue;
      final dayNo = start == null ? 0 : it.dateEpochDay - start + 1;
      arranged.putIfAbsent(r, () => []).add(dayNo);
    }
    for (final l in arranged.values) {
      l.sort();
    }
    return GuideLinkSnapshot(
      arrangedDaysByRef: arranged,
      wishlistedRefs: {
        for (final w in wishes)
          if (w.guideRef != null && w.guideRef!.isNotEmpty) w.guideRef!,
      },
    );
  });
});

/// 三路 latest-combine（drift watch 流监听即回放当前值，保序转发即可）。
class _Latest3<A, B, C> {
  _Latest3(this._sa, this._sb, this._sc);

  final Stream<A> _sa;
  final Stream<B> _sb;
  final Stream<C> _sc;

  Stream<T> map<T>(T Function(A a, B b, C c) fn) {
    late final StreamController<T> ctrl;
    StreamSubscription<void>? sa;
    StreamSubscription<void>? sb;
    StreamSubscription<void>? sc;
    var hasA = false, hasB = false, hasC = false;
    A? a;
    B? b;
    C? c;
    void emit() {
      if (hasA && hasB && hasC) ctrl.add(fn(a as A, b as B, c as C));
    }

    ctrl = StreamController<T>(
      onListen: () {
        sa = _sa.listen((v) {
          a = v;
          hasA = true;
          emit();
        });
        sb = _sb.listen((v) {
          b = v;
          hasB = true;
          emit();
        });
        sc = _sc.listen((v) {
          c = v;
          hasC = true;
          emit();
        });
      },
      onPause: () {
        sa?.pause();
        sb?.pause();
        sc?.pause();
      },
      onResume: () {
        sa?.resume();
        sb?.resume();
        sc?.resume();
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
        await sc?.cancel();
      },
    );
    return ctrl.stream;
  }
}

// ===== V2.7.2 S9：城市锦囊 =====

/// 目的地→城 key 匹配索引（种子 name → cityKey，含 AI 导入/官网覆盖层；
/// 进程内加载一次，matchCityKey 注入用）。
final guideCityKeyByNameProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final keyToName = await ref.watch(guideServiceProvider).seedSource.cityNameIndex();
  return {
    for (final e in keyToName.entries)
      if (e.value.isNotEmpty) e.value: e.key
  };
});

/// 锦囊种子快照（getSeed 既有优先级链：AI 导入 > 官网整包 > 内置种子；
/// 不建第二套缓存）。prep/tips/budget/calendar 四栏 + 城名/大区。
class KitSeed {
  const KitSeed({
    required this.cityKey,
    required this.cityName,
    required this.area,
    required this.prep,
    required this.tips,
    required this.budget,
    required this.calendar,
  });

  final String cityKey;
  final String cityName;
  final String area;
  final List<Map<String, dynamic>> prep;
  final List<Map<String, dynamic>> tips;
  final List<Map<String, dynamic>> budget;

  /// 季节日历（仅部分城市有；空列表 = 整组不渲染）。
  final List<Map<String, dynamic>> calendar;
}

final kitSeedProvider =
    FutureProvider.family<KitSeed?, String>((ref, cityKey) async {
  final seed =
      await ref.watch(guideServiceProvider).seedSource.getSeed(cityKey);
  if (seed == null) return null;
  List<Map<String, dynamic>> rows(String key) => [
        for (final r in ((seed['sections'] as Map?)?[key] as List?) ?? const [])
          if (r is Map) (r as Map).cast<String, dynamic>(),
      ];
  return KitSeed(
    cityKey: cityKey,
    cityName: (seed['name'] ?? '').toString(),
    area: (seed['area'] ?? '').toString(),
    prep: rows('prep'),
    tips: rows('tips'),
    budget: rows('budget'),
    calendar: rows('calendar'),
  );
});

/// guideRef → 种子行（V2.7.2 S10 精要随卡反查）。
/// 失效（非法串/城缺失/序号越界）返回 null → 消费端静默降级不渲染。
final guideRowByRefProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, raw) async {
  final parsed = GuideRef.tryParse(raw);
  if (parsed == null) return null;
  final seed =
      await ref.watch(guideServiceProvider).seedSource.getSeed(parsed.cityKey);
  final rows =
      ((seed?['sections'] as Map?)?[parsed.section] as List?) ?? const [];
  if (parsed.index >= rows.length) return null;
  return (rows[parsed.index] as Map).cast<String, dynamic>();
});

/// key → 城名（V2.7.2 S11 想去池分组头反查；含覆盖层）。
final guideCityNameByKeyProvider =
    FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(guideServiceProvider).seedSource.cityNameIndex();
});
