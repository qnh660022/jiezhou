/// 攻略主入口（§7.4）：分层调度 + 缓存读写 + 更新包拉取。
/// 任何路径都不抛（失败=降级结果）；多源合并规则：种子优先、在线补空（§7.16）。
///
/// 2026-09-06 重构（用户变更「离线+在线结合做实、在线优先」）：
/// - getGuideMultiOffline：纯离线阶段（缓存/种子），零网络，供首屏立即渲染；
/// - getGuideMulti：完整阶段（种子→open→crawl→aggregate），30 分钟内直接回缓存，
///   过期自动重跑在线层——进入页面默认在线优先，离线内容始终同屏可读；
/// - open 层真实现（Open-Meteo 天气 + OSM 景点 POI）；
/// - 文章发现多链路（必应检索 → 站内搜索兜底），与正文爬取共享一次发现；
/// - 各层参与打 debugPrint 日志，供真机验收断言。
library;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/copy_tokens.dart';
import 'guide_aggregator.dart';
import 'guide_cache.dart';
import 'guide_crawler.dart';
import 'guide_http.dart';
import 'guide_models.dart';
import 'guide_normalize.dart';
import 'guide_open_source.dart';
import 'guide_seed_source.dart';

class GuideResult {
  GuideResult({
    required this.location,
    required this.sections,
    required this.articles,
    required this.layersUsed,
    this.onlineSections = const {},
    this.onlineAttempted = false,
    this.cached = false,
    this.failed,
  });

  final GuideLocation? location;

  /// 六栏（含在线补充条目，可能为空栏，UI 呈现"暂无"）。
  final Map<String, List<Map<String, dynamic>>> sections;
  final List<Map<String, dynamic>> articles;

  /// 在线补充条目（按栏；条目带 source 标注）——UI「网络补充」区块置顶展示。
  final Map<String, List<Map<String, dynamic>>> onlineSections;

  /// 实际参与层（seed/open/crawl/aggregate/cache）。
  final List<String> layersUsed;

  /// 本次是否尝试过在线层（全败时 UI 提示「在线内容暂时不可用」）。
  final bool onlineAttempted;

  final bool cached;

  /// 整页级失败文案（如"无法识别目的地"）。
  final String? failed;

  bool get hasOnline =>
      layersUsed.any((l) => l == 'open' || l == 'crawl' || l == 'aggregate');

  String? sectionMiss(String key) =>
      (sections[key] ?? const []).isEmpty ? copy('guide.missSection') : null;
}

class GuideService {
  GuideService({
    GuideCache? cache,
    GuideHttp? http,
    GuideSeedSource? seedSource,
    GuideCrawlLayer? crawlLayer,
    GuideAggregator? aggregator,
    GuideOpenSourceLayer? openSource,
    this.enableOnline = true,
  })  : cache = cache ?? GuideCache(),
        http = http ?? GuideHttp.instance,
        seedSource = seedSource ?? GuideSeedSource(cache ?? GuideCache()),
        crawlLayer = crawlLayer ?? GuideCrawlLayer(GuideHttp.instance),
        aggregator = aggregator ?? const GuideAggregator(),
        openSource = openSource ?? GuideOpenSourceLayer(http: GuideHttp.instance);

  final GuideCache cache;
  final GuideHttp http;
  final GuideSeedSource seedSource;
  final GuideCrawlLayer crawlLayer;
  final GuideAggregator aggregator;
  final GuideOpenSourceLayer openSource;

  /// 离线/单测关闭在线层（不发起任何网络请求）。
  final bool enableOnline;

  static const _checkAtPref = 'guide.seed.checkAt';

  /// 在线刷新节流窗：窗口内直接回缓存，过期自动重跑在线层（在线优先）。
  static const freshWindowMs = 30 * 60 * 1000;

  bool get _onlinePossible => enableOnline && !kIsWeb;

  // ============ 对外入口 ============

  /// 单目的地完整结果（兼容旧调用与测试）。
  Future<GuideResult> getGuide(String destination,
      {bool forceRefresh = false}) async {
    final results =
        await getGuideMulti(destination, forceRefresh: forceRefresh);
    if (results.isEmpty) return _badDestination();
    return results.first;
  }

  /// 多目的地完整结果：「成都-稻城」逐城走分层管线（在线优先）。
  Future<List<GuideResult>> getGuideMulti(String destination,
      {bool forceRefresh = false}) async {
    final locs = await _normalize(destination);
    if (locs.isEmpty) return const [];
    final out = <GuideResult>[];
    for (final loc in locs) {
      out.add(await _buildFull(loc, forceRefresh));
    }
    return out;
  }

  /// 纯离线首屏：缓存（7 天内）或种子，零网络请求。多目的地逐城返回。
  Future<List<GuideResult>> getGuideMultiOffline(String destination) async {
    final locs = await _normalize(destination);
    if (locs.isEmpty) return const [];
    final out = <GuideResult>[];
    for (final loc in locs) {
      final cached = await cache.readCity(loc.key);
      if (cached != null) {
        out.add(_fromCached(cached, loc, onlineAttempted: false));
        continue;
      }
      final seed = await seedSource.getSeed(loc.key);
      if (seed != null) {
        out.add(_fromSeed(seed, loc));
      } else {
        out.add(GuideResult(
          location: loc,
          sections: _emptySections(),
          articles: const [],
          layersUsed: const [],
        ));
      }
    }
    return out;
  }

  // ============ 完整管线 ============

  Future<GuideResult> _buildFull(GuideLocation loc, bool force) async {
    // 1) 30 分钟新鲜窗口内的缓存直接命中（幂等 §7.16）
    if (!force) {
      final savedAt = await cache.savedAtMs(loc.key);
      if (savedAt != null &&
          DateTime.now().millisecondsSinceEpoch - savedAt < freshWindowMs) {
        final cached = await cache.readCity(loc.key);
        if (cached != null) {
          _log(loc, 'cache(fresh)');
          return _fromCached(cached, loc, onlineAttempted: false, cachedFlag: true);
        }
      }
    }
    // 2) 种子层（瞬时、离线打底）
    final layers = <String>[];
    final seed = await seedSource.getSeed(loc.key);
    final sections = <String, List<Map<String, dynamic>>>{};
    final seedNames = <String, Set<String>>{};
    if (seed != null) {
      final rawSections = (seed['sections'] as Map?) ?? {};
      for (final k in GuideCity.sectionKeys) {
        sections[k] = ((rawSections[k] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        seedNames[k] = sections[k]!
            .map((e) => (e['name'] ?? e['title'] ?? '').toString())
            .toSet();
      }
      layers.add('seed');
      _log(loc, 'seed(${sections.values.fold<int>(0, (n, l) => n + l.length)}条)');
    }
    // 3) 在线层：open（天气+POI，全平台可用）→ crawl/aggregate（白名单文章流）
    final onlineSections = <String, List<Map<String, dynamic>>>{};
    List<Map<String, dynamic>> articles = [];
    var onlineAttempted = false;
    if (_onlinePossible) {
      onlineAttempted = true;
      // 3a) open 层
      try {
        final enhanced = await openSource.enhance(loc);
        if (enhanced != null) {
          layers.add('open');
          _log(loc, 'open(${enhanced.keys.join("/")})');
          enhanced.forEach((k, v) {
            onlineSections[k] = [
              ...(onlineSections[k] ?? const []),
              ...v,
            ];
          });
        }
      } catch (_) {}
      // 3b) 白名单文章流：一次发现，正文爬取与文章聚合共享链接
      List<String> links = [];
      try {
        links = await crawlLayer.discoverArticleLinks(loc.name);
        if (links.isNotEmpty) _log(loc, 'discovered(${links.length})');
      } catch (_) {}
      if (links.isNotEmpty) {
        try {
          final crawled =
              await crawlLayer.crawl(loc.key, links.take(3).toList());
          if (crawled.isNotEmpty) {
            layers.add('crawl');
            _log(loc, 'crawl(${crawled.keys.join("/")})');
            crawled.forEach((k, v) {
              onlineSections[k] = [
                ...(onlineSections[k] ?? const []),
                ...v,
              ];
            });
          }
        } catch (_) {}
        try {
          final raw = <Map<String, dynamic>>[];
          for (final link in links.take(10)) {
            final res = await http.fetchText(link);
            if (res.cls == GuideFetchClass.ok) {
              raw.add({
                'title': _titleOf(res.body) ?? link,
                'url': link,
                'sourceUrl': link,
                'summary': aggregator.summarize(res.body),
              });
            }
          }
          final qc = aggregator.filterAndScore(raw);
          if (qc.isNotEmpty) {
            articles = qc;
            layers.add('aggregate');
            _log(loc, 'aggregate(${qc.length}篇)');
          }
        } catch (_) {}
      }
    }
    // 4) 合并：种子文本优先，在线条目去重后追加（§7.16 不改写种子）
    final merged = _mergeSections(sections, seedNames, onlineSections);
    // 5) 写缓存（失败不影响结果呈现）
    try {
      final data = GuideCity(loc.key, loc.name, merged, articles: articles)
          .toJson(layersUsed: layers);
      await cache.writeCity(loc.key, data);
    } catch (_) {}
    return GuideResult(
      location: loc,
      sections: merged,
      articles: articles,
      layersUsed: layers,
      onlineSections: onlineSections,
      onlineAttempted: onlineAttempted,
    );
  }

  /// 在线条目去重（与种子同名/同栏已存在则丢弃）后并入 sections。
  Map<String, List<Map<String, dynamic>>> _mergeSections(
    Map<String, List<Map<String, dynamic>>> sections,
    Map<String, Set<String>> seedNames,
    Map<String, List<Map<String, dynamic>>> onlineSections,
  ) {
    final merged = <String, List<Map<String, dynamic>>>{
      for (final k in GuideCity.sectionKeys)
        k: List<Map<String, dynamic>>.from(sections[k] ?? const []),
    };
    onlineSections.forEach((k, items) {
      final names = seedNames[k] ?? {};
      for (final it in items) {
        final name = (it['name'] ?? it['title'] ?? '').toString();
        if (name.isEmpty || names.contains(name)) continue;
        names.add(name);
        merged[k] = [...(merged[k] ?? const <Map<String, dynamic>>[]), it];
      }
    });
    return merged;
  }

  // ============ 构造辅助 ============

  GuideResult _fromSeed(Map<String, dynamic> seed, GuideLocation loc) {
    final rawSections = (seed['sections'] as Map?) ?? {};
    final sections = <String, List<Map<String, dynamic>>>{};
    for (final k in GuideCity.sectionKeys) {
      sections[k] = ((rawSections[k] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }
    return GuideResult(
        location: loc,
        sections: sections,
        articles: const [],
        layersUsed: const ['seed']);
  }

  GuideResult _fromCached(Map<String, dynamic> cached, GuideLocation loc,
      {required bool onlineAttempted, bool cachedFlag = false}) {
    final sections = <String, List<Map<String, dynamic>>>{};
    final rawSections = (cached['sections'] as Map?) ?? {};
    final online = <String, List<Map<String, dynamic>>>{};
    for (final k in GuideCity.sectionKeys) {
      final items = ((rawSections[k] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      sections[k] = items;
      // 缓存结果里带 source 标注的条目即在线补充（UI 同样按此过滤）
      final withSource = items.where((e) => e['source'] != null).toList();
      if (withSource.isNotEmpty) online[k] = withSource;
    }
    return GuideResult(
      location: loc,
      sections: sections,
      articles: ((cached['articles'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      layersUsed: ((cached['layersUsed'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      onlineSections: online,
      onlineAttempted: onlineAttempted,
      cached: cachedFlag,
    );
  }

  Map<String, List<Map<String, dynamic>>> _emptySections() => {
        for (final k in GuideCity.sectionKeys) k: const [],
      };

  GuideResult _badDestination() => GuideResult(
      location: null,
      sections: _emptySections(),
      articles: const [],
      layersUsed: const [],
      failed: copy('guide.badDestination'));

  void _log(GuideLocation loc, String msg) {
    if (kDebugMode) debugPrint('[guide] ${loc.key}: $msg');
  }

  // ============ 后台任务 ============

  /// 预取（§7.12）：进入行程详情时后台静默刷新（多目的地逐城）；30 分钟内不重复。
  Future<void> prefetch(String destination) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final lastKey = 'guide.prefetch.${destination.hashCode}';
      final last = sp.getInt(lastKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < 30 * 60 * 1000) return;
      await sp.setInt(lastKey, now);
      await getGuideMulti(destination);
    } catch (_) {}
  }

  /// 冷启动静默检查官网更新包（24h 冷却，§7.18；失败静默）。
  Future<void> checkSeedUpdate() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final last = sp.getInt(_checkAtPref) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < 24 * 3600 * 1000) return;
      final ok = await seedSource.tryUpdateFromOfficial(
        fetchText: (url) async {
          final res = await http.fetchText(url, checkRobots: false);
          return res.cls == GuideFetchClass.ok ? res.body : null;
        },
        lastCheck: last <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(last),
      );
      await sp.setInt(_checkAtPref, now);
      if (ok) {
        // 更新包落盘成功（本轮官网未部署，正常路径为 404 静默）
      }
    } catch (_) {}
  }

  Future<List<GuideLocation>> _normalize(String destination) async {
    final names = await seedSource.cityNameIndex();
    return normalizeGuideDestinations(destination, seedNames: names);
  }

  String? _titleOf(String html) {
    final m = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1)?.trim();
  }
}

/// JSON 辅助。
Map<String, dynamic> guideDecodeJson(String s) =>
    (jsonDecode(s) as Map).cast<String, dynamic>();
