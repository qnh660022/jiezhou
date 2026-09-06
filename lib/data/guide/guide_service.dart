/// 攻略主入口（§7.4）：分层调度 + 缓存读写 + 更新包拉取。
/// 任何路径都不抛（失败=降级结果）；多源合并规则：种子优先、在线补空（§7.16）。
library;
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
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
    this.cached = false,
    this.failed,
  });

  final GuideLocation? location;

  /// 六栏（可能为空栏，UI 呈现"暂无"）。
  final Map<String, List<Map<String, dynamic>>> sections;
  final List<Map<String, dynamic>> articles;

  /// 实际参与层（seed/open/crawl/aggregate/cache）。
  final List<String> layersUsed;
  final bool cached;

  /// 整页级失败文案（如"无法识别目的地"）。
  final String? failed;

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
  })  : cache = cache ?? GuideCache(),
        http = http ?? GuideHttp.instance,
        seedSource = seedSource ?? GuideSeedSource(cache ?? GuideCache()),
        crawlLayer = crawlLayer ?? GuideCrawlLayer(GuideHttp.instance),
        aggregator = aggregator ?? const GuideAggregator();

  final GuideCache cache;
  final GuideHttp http;
  final GuideSeedSource seedSource;
  final GuideCrawlLayer crawlLayer;
  final GuideAggregator aggregator;
  final GuideOpenSourceLayer openSource = const GuideOpenSourceLayer();

  static const _checkAtPref = 'guide.seed.checkAt';

  /// 主入口：getGuide(destination)。同城未过 TTL 直接返回缓存（幂等，§7.16）。
  Future<GuideResult> getGuide(String destination,
      {bool forceRefresh = false}) async {
    final loc = normalizeGuideDestination(destination,
        seedNames: await seedSource.cityNameIndex());
    if (loc == null) {
      return GuideResult(location: null, sections: const {}, articles: const [],
          layersUsed: const [], failed: copy('guide.badDestination'));
    }
    // 1) 缓存命中
    if (!forceRefresh) {
      final cached = await cache.readCity(loc.key);
      if (cached != null) {
        return _fromCached(cached, loc);
      }
    }
    // 2) 种子层
    final layers = <String>[];
    final sections = <String, List<Map<String, dynamic>>>{};
    final seed = await seedSource.getSeed(loc.key);
    List<Map<String, dynamic>> articles = [];
    if (seed != null) {
      final rawSections = (seed['sections'] as Map?) ?? {};
      for (final k in GuideCity.sectionKeys) {
        sections[k] = ((rawSections[k] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
      layers.add('seed');
    }
    // 3) 开源增强（可空实现）
    final enhanced = await openSource.enhance(loc.key);
    if (enhanced != null) {
      layers.add('open');
      for (final e in enhanced.entries) {
        if ((sections[e.key] ?? const []).length < 3) {
          sections[e.key] = [...(sections[e.key] ?? const []), ...e.value];
        }
      }
    }
    // 4) 白名单精爬（仅补种子 <3 的栏；仅 Android）
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final needsCrawl =
          GuideCity.sectionKeys.any((k) => (sections[k] ?? const []).length < 3);
      if (needsCrawl) {
        try {
          final links = await crawlLayer.discoverArticleLinks(loc.name);
          final crawled = await crawlLayer.crawl(loc.key, links.take(3).toList());
          if (crawled.isNotEmpty) {
            layers.add('crawl');
            crawled.forEach((k, v) {
              if ((sections[k] ?? const []).length < 3) {
                // 在线补仅填空，不改写种子条目文本（§7.16）
                sections[k] = [...(sections[k] ?? const []), ...v];
              }
            });
          }
        } catch (_) {
          // 该层失败只影响该层
        }
      }
      // 文章流聚合
      try {
        final raw = <Map<String, dynamic>>[];
        for (final link in (await crawlLayer.discoverArticleLinks(loc.name)).take(10)) {
          final res = await http.fetchText(link);
          if (res.cls == GuideFetchClass.ok) {
            raw.add({
              'title': _titleOf(res.body) ?? link,
              'url': link,
              'summary': aggregator.summarize(res.body),
            });
          }
        }
        final qc = aggregator.filterAndScore(raw);
        if (qc.isNotEmpty) {
          articles = qc;
          layers.add('aggregate');
        }
      } catch (_) {}
    }
    // 5) 写缓存（失败不影响结果呈现；"任何路径都不抛"契约）
    try {
      final data = GuideCity(loc.key, loc.name, sections, articles: articles)
          .toJson(layersUsed: layers);
      await cache.writeCity(loc.key, data);
    } catch (_) {}
    return GuideResult(
        location: loc, sections: sections, articles: articles, layersUsed: layers);
  }

  GuideResult _fromCached(Map<String, dynamic> cached, GuideLocation loc) {
    final sections = <String, List<Map<String, dynamic>>>{};
    final rawSections = (cached['sections'] as Map?) ?? {};
    for (final k in GuideCity.sectionKeys) {
      sections[k] = ((rawSections[k] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
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
      cached: true,
    );
  }

  String? _titleOf(String html) {
    final m = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1)?.trim();
  }

  /// 预取（§7.12）：进入行程详情时后台静默刷新；同城 30 分钟内不重复触发。
  Future<void> prefetch(String destination) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final lastKey = 'guide.prefetch.${destination.hashCode}';
      final last = sp.getInt(lastKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < 30 * 60 * 1000) return;
      await sp.setInt(lastKey, now);
      await getGuide(destination);
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
}

/// JSON 辅助。
Map<String, dynamic> guideDecodeJson(String s) =>
    (jsonDecode(s) as Map).cast<String, dynamic>();
