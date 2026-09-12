/// 攻略主入口（§7.4）：分层调度 + 缓存读写 + 更新包拉取。
/// 任何路径都不抛（失败=降级结果）；多源合并规则：种子优先、在线补空（§7.16）。
///
/// 2026-09 换源重构：
/// - 在线正文层由「必应检索 + 四家白名单」换成「去哪儿攻略城市页一城一 URL」
///   （实测唯一 robots 放行 + 服务端直出中文正文的国内源，详见 crawler_rules）；
/// - open 层收窄为「只补事实」（天气 + 国内中文 POI），不再当攻略主体；
/// - 种子层新增最高优先级：App 内 AI 生成并导入的单城覆盖包（`layersUsed` 记 `ai`）；
/// - `getGuideMultiByKeys` / `getGuideMultiOfflineByKeys`：按城市 key 直接取，
///   支撑「按城市切换攻略」入口。
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

  /// 实际参与层（seed / ai / open / crawl / aggregate / cache）。
  final List<String> layersUsed;

  /// 本次是否尝试过在线层（全败时 UI 提示「在线内容暂时不可用」）。
  final bool onlineAttempted;

  final bool cached;

  /// 整页级失败文案（如"无法识别目的地"）。
  final String? failed;

  bool get hasOnline =>
      layersUsed.any((l) => l == 'open' || l == 'crawl' || l == 'aggregate');

  /// 正文来自 App 内 AI 生成并导入的内容（优先级最高的种子层）。
  bool get isAiImported => layersUsed.contains('ai');

  /// 正文来自去哪儿的国内攻略页（在线抓取）。
  bool get hasCrawledGuide => layersUsed.contains('crawl');

  /// 正文汉字总数（阅读时长估算用）。
  int get textChars => GuideCity.textCharCount(null, sections);

  /// 预计阅读分钟数（350 汉字/分钟）。
  int get readingMinutes => GuideCity.readingMinutes(textChars);

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
        seedSource = seedSource ??
            GuideSeedSource(cache ?? GuideCache()),
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
    return _buildAll(locs, forceRefresh);
  }

  /// 直接按城市 key 取攻略（不经过 destination 归一化）。
  ///
  /// 供「按城市切换」入口使用：用户在精品城市选择器点了「杭州」，传的就是 key。
  /// 未知 key 也能走（会命中 `city_coords` 之外的通用路径 → 无种子 → 空态），
  /// 由调用方决定是否提示。
  Future<List<GuideResult>> getGuideMultiByKeys(List<String> keys,
      {bool forceRefresh = false}) async {
    final names = await seedSource.cityNameIndex();
    final locs = <GuideLocation>[];
    final seen = <String>{};
    for (final raw in keys) {
      final key = raw.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      locs.add(GuideLocation(key, names[key] ?? key));
    }
    if (locs.isEmpty) return const [];
    return _buildAll(locs, forceRefresh);
  }

  /// 纯离线首屏：缓存（7 天内）或种子，零网络请求。多目的地逐城返回。
  Future<List<GuideResult>> getGuideMultiOffline(String destination) async {
    final locs = await _normalize(destination);
    if (locs.isEmpty) return const [];
    return _buildOffline(locs);
  }

  /// 纯离线首屏（按 key）。
  Future<List<GuideResult>> getGuideMultiOfflineByKeys(List<String> keys) async {
    final names = await seedSource.cityNameIndex();
    final locs = <GuideLocation>[];
    final seen = <String>{};
    for (final raw in keys) {
      final key = raw.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      locs.add(GuideLocation(key, names[key] ?? key));
    }
    if (locs.isEmpty) return const [];
    return _buildOffline(locs);
  }

  /// 精品/内置城市清单（换城市选择器 + 行程页入口共用）。
  Future<List<({String key, String name, String area})>> allCities() =>
      seedSource.allCities();

  Future<List<GuideResult>> _buildOffline(List<GuideLocation> locs) async {
    final out = <GuideResult>[];
    for (final loc in locs) {
      final cached = await cache.readCity(loc.key);
      if (cached != null) {
        out.add(_fromCached(cached, loc, onlineAttempted: false));
        continue;
      }
      final seed = await seedSource.getSeed(loc.key);
      if (seed != null) {
        out.add(_fromSeed(seed, loc,
            isAi: await _isAiImported(loc.key)));
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

  Future<List<GuideResult>> _buildAll(
      List<GuideLocation> locs, bool force) async {
    final out = <GuideResult>[];
    for (final loc in locs) {
      out.add(await _buildFull(loc, force));
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
    // 2) 种子层（瞬时、离线打底）——可能是 AI 导入内容，按 ai 记层
    final layers = <String>[];
    final seed = await seedSource.getSeed(loc.key);
    final isAiSeed = await _isAiImported(loc.key);
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
      layers.add(isAiSeed ? 'ai' : 'seed');
      _log(
          loc,
          '${isAiSeed ? 'ai' : 'seed'}'
          '(${sections.values.fold<int>(0, (n, l) => n + l.length)}条)');
    }
    // 3) 在线层：open（天气/国内 POI，全平台可用）→ crawl（去哪儿城市页）
    final onlineSections = <String, List<Map<String, dynamic>>>{};
    // 该栏种子已有几条：够了就不再让在线层往这栏塞东西。
    // 否则 Open-Meteo 的「未来3天天气」会被怼进种子已经写得很足的「行前准备」里，
    // 让精品内容被网络条目挤下去（用户明确反馈过「获取的只是地点，不是攻略」）。
    final seedEnough = <String, bool>{
      for (final k in GuideCity.sectionKeys)
        k: (sections[k] ?? const []).length >= 3,
    };
    List<Map<String, dynamic>> articles = [];
    var onlineAttempted = false;
    if (_onlinePossible) {
      onlineAttempted = true;
      // 3a) open 层：只补事实（天气 + 国内中文 POI），不承担攻略主体
      try {
        final enhanced = await openSource.enhance(loc);
        if (enhanced != null) {
          var used = false;
          enhanced.forEach((k, v) {
            if (seedEnough[k] == true) return; // 种子已够，不补
            onlineSections[k] = [
              ...(onlineSections[k] ?? const []),
              ...v,
            ];
            used = true;
          });
          if (used) {
            layers.add('open');
            _log(loc, 'open(${enhanced.keys.join("/")})');
          }
        }
      } catch (_) {}
      // 3b) 白名单城市页：一次请求 = 一城的国内中文攻略正文
      try {
        final crawled = await crawlLayer.crawlCity(loc.key);
        if (crawled != null && !crawled.isEmpty) {
          var used = false;
          crawled.sections.forEach((k, v) {
            if (seedEnough[k] == true) return;
            onlineSections[k] = [
              ...(onlineSections[k] ?? const []),
              ...v,
            ];
            used = true;
          });
          // 文章流独立于六栏：无论种子怎么填都要（游记列表是种子里没有的）
          final qc = aggregator.filterAndScore(crawled.articles);
          articles = qc.isEmpty ? crawled.articles : qc;
          if (used || articles.isNotEmpty) layers.add('crawl');
          _log(loc,
              'crawl(${crawled.sections.keys.join("/")}${articles.isEmpty ? '' : ' +${articles.length}篇'})');
        }
      } catch (_) {}
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

  /// 该城当前种子是否来自「App 内 AI 生成并导入」（优先级最高那一层）。
  Future<bool> _isAiImported(String key) async {
    try {
      return await cache.readCityOverride(key) != null;
    } catch (_) {
      return false;
    }
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

  GuideResult _fromSeed(Map<String, dynamic> seed, GuideLocation loc,
      {bool isAi = false}) {
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
        layersUsed: [if (isAi) 'ai' else 'seed']);
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

  // ============ App 内 AI 生成攻略：导入 / 删除 ============

  /// 该城是否已有 AI 导入内容（攻略页显示「我的 AI」徽章 + 删除入口）。
  Future<bool> hasCityOverride(String key) async {
    try {
      return await cache.readCityOverride(key) != null;
    } catch (_) {
      return false;
    }
  }

  /// 导入一份 AI 生成的攻略（确认卡点「导入」后调用）。
  ///
  /// 校验不过一律拒绝并返回错误文案；通过则落盘为最高优先级种子层。
  /// 返回 null = 成功。
  Future<String?> importCityGuide(Map<String, dynamic> city) async {
    final err = GuideCity.validate(city);
    if (err != null) return '内容结构不完整（$err），未导入';
    final key = city['key'] as String;
    final chars = GuideCity.textCharCount(city);
    if (chars < 800) return '正文仅 $chars 字，太短了，未导入';
    final ok = await cache.writeCityOverride(key, city);
    if (!ok) return '写入失败（可能是存储空间或权限问题）';
    seedSource.invalidateCityOverride(key);
    // 已有缓存带着旧的 seed 文本，必须失效，否则 30 分钟新鲜窗会继续返回旧内容
    try {
      await cache.deleteCity(key);
    } catch (_) {}
    return null;
  }

  /// 删除该城的 AI 内容，回落到内置种子。
  Future<void> clearCityOverride(String key) async {
    await cache.clearCityOverride(key);
    seedSource.invalidateCityOverride(key);
    try {
      await cache.deleteCity(key);
    } catch (_) {}
  }
}

/// JSON 辅助。
Map<String, dynamic> guideDecodeJson(String s) =>
    (jsonDecode(s) as Map).cast<String, dynamic>();
