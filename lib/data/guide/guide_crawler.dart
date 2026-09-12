/// 白名单精爬层（§7.6，2026-09 换源重构）。
///
/// ## 为什么重写
/// 旧实现是「必应检索 → 白名单过滤 → 关键词把段落硬分到六栏」，实测：
/// - 白名单里的马蜂窝/穷游/知乎/搜狐全部不可抓（robots 禁区或反爬壳，见 rules 文件）；
/// - 真正抓回来的只有 OpenStreetMap 的**外文 POI 地点**（用户原话：「获取的只是
///   地点，不是攻略，而且全是外国的」）。
///
/// 新实现：**一个城市 = 一个确定的国内城市页**（去哪儿攻略，robots 放行 +
/// 服务端直出中文正文），按页面的 H1/H2 结构分块抽取，直接落到六栏：
/// - 城市概述/最佳季节/建议天数 → `prep`
/// - 推荐线路（名称 + 简介 + 途经点）→ 纳入 `prep` 的行程节奏
/// - 热门景点卡片（名称 + 简介）→ `spots`
/// - 不可错过（美食/购物/玩乐图墙）→ `food`
/// - 热门攻略（游记标题/日期/天数/途经）→ `articles`（真·攻略流）
/// - 门票价格表 → `budget`
///
/// 只 Android 生效：Web 端受 CORS 限制无法直连（§7.8）。
library;
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;

import 'guide_city_sources.dart';
import 'guide_content_filter.dart';
import 'guide_crawler_rules.dart';
import 'guide_http.dart';
import 'guide_raw_html.dart';

class GuideCrawlLayer {
  /// [http] 与 [fetchOverride] 至少给一个：给了 [fetchOverride] 时（测试注入）
  /// 可以不传 [http]，此时不会有任何真实网络请求。
  GuideCrawlLayer(this._http, {this.fetchOverride}) {
    if (_http == null && fetchOverride == null) {
      throw ArgumentError('必须提供 GuideHttp 或 fetchOverride');
    }
  }

  final GuideHttp? _http;

  /// 测试注入：给定 url 直接返回结果（绕过真实网络）。
  final GuideFetchResult Function(String url)? fetchOverride;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<GuideFetchResult> _fetch(String url) => fetchOverride != null
      ? Future.value(fetchOverride!(url))
      : _http!.fetchText(url);

  /// 单次抓取的城市页结果：六栏条目 + 文章候选 + 实际使用的 URL。
  static String? urlForCity(String cityKey) {
    final id = kQunarCityIds[cityKey];
    if (id == null) return null; // 无映射 → 不猜 URL，上层只走种子
    return 'https://travel.qunar.com/p-cs$id-$cityKey';
  }

  /// 抓一座城市的在线补充内容。
  ///
  /// 返回 `null` = 该层无数据（无映射/未启用/抓取失败/城市名对不上），
  /// 上层静默降级到内置种子；**任何情况都不抛**。
  Future<GuideCrawlResult?> crawlCity(String cityKey) async {
    if (!_supported) return null;
    final url = urlForCity(cityKey);
    if (url == null) {
      debugPrint('[guide] $cityKey: 无去哪儿城市 ID，跳过在线层');
      return null;
    }
    if (isKnownBlockedHost(Uri.parse(url).host)) return null;
    if (matchGuideRule(url) == null) return null; // 白名单外一律不抓
    final res = await _fetch(url);
    if (res.cls != GuideFetchClass.ok) {
      debugPrint('[guide] $cityKey: 抓取失败(${res.cls.name}/${res.body})');
      return null;
    }
    // 关键复核：去哪儿 URL 里 ID 才是权威，ID/slug 错配会静默返回别的城市。
    final got = pageCityName(res.body);
    final want = kQunarCityNames[cityKey];
    if (want != null && got != null && got != want) {
      debugPrint('[guide] $cityKey: 页面城市名「$got」与期望「$want」不符，丢弃');
      return null;
    }
    final parsed = _parseCityPage(res.body, cityKey);
    if (parsed.isEmpty) {
      debugPrint('[guide] $cityKey: 服务端可读，但解析为空（页面结构可能已改版）');
      return null;
    }
    parsed.layers.add('crawl');
    return parsed;
  }

  /// 兼容旧调用：按白名单链接抓正文（现主要用于文章流摘要，不做六栏抽取）。
  Future<Map<String, List<Map<String, dynamic>>>> crawl(
      String cityKey, List<String> urls) async {
    if (!_supported) return const {};
    final out = <String, List<Map<String, dynamic>>>{};
    for (final url in urls) {
      if (matchGuideRule(url, articles: true) == null) continue;
      if (isKnownBlockedHost(Uri.parse(url).host)) continue;
      final res = await _fetch(url);
      if (res.cls != GuideFetchClass.ok) continue;
      final title = _titleOf(res.body);
      if (title == null || !hasCjk(title, min: 2)) continue;
      out.putIfAbsent('spots', () => []).add({
        'name': title,
        'addr': '',
        'tag': '攻略',
        'timeText': '',
        'note': '',
        'source': '去哪儿攻略',
        'sourceUrl': url,
      });
      if (out['spots']!.length >= 5) break;
    }
    return out;
  }

  // ============ 城市页解析 ============

  GuideCrawlResult _parseCityPage(String html, String cityKey) {
    final out = GuideCrawlResult();
    final sections = extractSections(html);
    final sourceUrl = urlForCity(cityKey) ?? '';

    // ---- prep：城市概述 + 最佳季节 + 建议游玩天数 + 推荐线路节奏 ----
    final prep = <Map<String, dynamic>>[];
    final citySec = sectionByTitle(html, '旅游攻略', level: 1) ??
        (sections.isEmpty ? null : sections.first);
    if (citySec != null) {
      // 概述段：块首的长句（站点把「城市一句话定位 + 最佳季节 + 建议天数」连排）
      final lines = bulletLines(
        citySec.body,
        minLen: 12,
        maxLen: 320,
        keep: (l) => hasCjk(l) && !isGuideNoise(l),
        max: 4,
      );
      if (lines.isNotEmpty) {
        prep.add({
          'title': '城市概述',
          'detail': lines.first,
          'source': '去哪儿攻略',
          'sourceUrl': sourceUrl,
        });
      }
      final season = lines.firstWhere(
        (l) => l.contains('最佳') || l.contains('季度') || l.contains('气候'),
        orElse: () => '',
      );
      if (season.isNotEmpty && season != lines.first) {
        prep.add({
          'title': '季节与最佳时间',
          'detail': season,
          'source': '去哪儿攻略',
          'sourceUrl': sourceUrl,
        });
      }
      final days = lines.firstWhere((l) => l.contains('建议游玩'), orElse: () => '');
      if (days.isNotEmpty) {
        prep.add({
          'title': '建议天数',
          'detail': days,
          'source': '去哪儿攻略',
          'sourceUrl': sourceUrl,
        });
      }
    }
    // 推荐线路：名称 + 简介 + 途经点 → 行程节奏
    final routeSec = sectionByTitle(html, '推荐线路', level: 2);
    if (routeSec != null) {
      final routes = _routes(routeSec.body);
      if (routes.isNotEmpty) {
        prep.add({
          'title': '推荐线路',
          'detail': routes.join('；'),
          'source': '去哪儿攻略',
          'sourceUrl': sourceUrl,
        });
      }
    }
    if (prep.isNotEmpty) out.sections['prep'] = prep;

    // ---- spots：H3「热门景点」图墙卡片（名称 + 一句简介） ----
    final spots = <Map<String, dynamic>>[];
    final spotSec = extractBetween(
      html,
      '目的地分类导航',
      endMarker: '热门城市',
    );
    if (spotSec != null) {
      for (final pair in extractLinkPairs(spotSec, max: 24)) {
        if (!hasCjk(pair.text, min: 2)) continue;
        if (isGuideNoise(pair.text)) continue;
        if (pair.text.contains('旅游攻略')) continue;
        if (!hasCjk(pair.tail, min: 6)) continue;
        spots.add({
          'name': pair.text,
          'addr': '',
          'tag': '经典',
          'timeText': '',
          'note': pair.tail,
          'source': '去哪儿攻略',
          'sourceUrl': sourceUrl,
        });
        if (spots.length >= 12) break;
      }
    }
    if (spots.isNotEmpty) out.sections['spots'] = spots;

    // ---- food：H2「不可错过」图墙（站点按 美食/购物/玩乐 三组平铺） ----
    // 注意：必须用**原始 HTML 片段**做链接配对，不能用 cleanGuideHtml 压平后的
    // 文本（`extractLinkPairs` 要的 `</a>` 结构会被压平丢掉）。
    final food = <Map<String, dynamic>>[];
    final mustSec = _rawSection('不可错过', html, endMarker: '热门攻略') ??
        _rawSection('不可错过', html, endMarker: '## ');
    if (mustSec != null) {
      for (final pair in extractLinkPairs(mustSec, max: 30)) {
        if (!hasCjk(pair.text, min: 2)) continue;
        if (isGuideNoise(pair.text)) continue;
        final clean = pair.text.replaceAll(RegExp(r'^\d+'), '');
        if (!hasCjk(clean, min: 2)) continue;
        food.add({
          'name': clean,
          'area': '',
          'note': hasCjk(pair.tail, min: 4) ? pair.tail : '',
          'source': '去哪儿攻略',
          'sourceUrl': sourceUrl,
        });
        if (food.length >= 12) break;
      }
    }
    if (food.isNotEmpty) out.sections['food'] = food;

    // ---- budget：热销门票价格表 ----
    final prices = _ticketPrices(html);
    if (prices.isNotEmpty) {
      out.sections['budget'] = [
        {
          'item': '门票（网络参考）',
          'rangeText': prices.join('；'),
          'source': '去哪儿攻略',
          'sourceUrl': sourceUrl,
        }
      ];
    }

    // ---- articles：热门攻略（游记）候选 ----
    out.articles = _articles(html);
    return out;
  }

  /// 推荐线路块 → 「名称：简介（途经 N 个点）」条目。
  List<String> _routes(String body) {
    final lines = bulletLines(
      body.replaceAll(RegExp(r'\n+'), '\n'),
      minLen: 6,
      maxLen: 420,
      keep: (l) => hasCjk(l, min: 4) && !isGuideNoise(l),
      max: 24,
    );
    final out = <String>[];
    final names = <String>[];
    final descs = <String>[];
    for (final l in lines) {
      if (RegExp(r'\d+日线路').hasMatch(l) || l.endsWith('线路')) {
        names.add(l.replaceAll(RegExp(r'^\d+'), '').trim());
      } else if (l.contains('适合人群') || l.length > 20) {
        descs.add(l);
      }
    }
    for (var i = 0; i < names.length; i++) {
      final d = i < descs.length ? descs[i] : '';
      out.add(d.isEmpty ? names[i] : '${names[i]}：$d');
      if (out.length >= 3) break;
    }
    return out;
  }

  /// 门票表：`>景点名</a> | ¥ 60起` 形态。
  List<String> _ticketPrices(String html) {
    final out = <String>[];
    final re = RegExp(
        r'>([^<]{2,24})</a>\s*</td>\s*<td[^>]*>\s*[¥￥]\s*([0-9.]+)',
        dotAll: true);
    for (final m in re.allMatches(html)) {
      final name = m.group(1)!.trim();
      final price = m.group(2)!.trim();
      if (!hasCjk(name, min: 2) || isGuideNoise(name)) continue;
      out.add('$name ¥$price 起');
      if (out.length >= 6) break;
    }
    return out;
  }

  /// 热门攻略区块 → 文章候选（标题 + 链接 + 日期/天数/途经）。
  ///
  /// 三种起点形态都实测出现过，按可靠性排序试：
  /// ① 「热门攻略」标题处（最常见）；② 锚文本含「旅行攻略」的链接（站点统计行
  /// 「共有 1004 篇杭州旅行攻略」）；③ 退化到「热门攻略」到文末。
  List<Map<String, dynamic>> _articles(String html) {
    final block = _rawSection('热门攻略', html, endMarker: '还没去过') ??
        _rawSection('旅行攻略</a>', html, endMarker: '还没去过') ??
        _rawSection('热门攻略', html, endMarker: '去了') ??
        _rawSection('热门攻略', html, endMarker: '\u0000');
    if (block == null) return const [];
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    final re = RegExp(
        r'<h3[^>]*>[\s\S]{0,80}?<a[^>]*href="([^"]+)"[^>]*>([^<]{4,60})</a>',
        caseSensitive: false);
    for (final m in re.allMatches(block)) {
      final url = m.group(1)!;
      final title = m.group(2)!.trim();
      if (!url.contains('/youji/')) continue;
      if (!hasCjk(title, min: 4) || isGuideNoise(title)) continue;
      if (!seen.add(url)) continue;
      out.add({
        'title': title,
        'source': '去哪儿攻略',
        'sourceUrl': url,
        'summary': '',
      });
      if (out.length >= 10) break;
    }
    return out;
  }

  /// 图墙区块里被 `cleanGuideHtml` 压平后的文本无法再配对链接，
  /// 这里保留原始片段用于 `extractLinkPairs`。
  String _unescape(String body) => body;

  /// 图墙区块的**原始 HTML 片段**：从标题文字开始，到下一个区块标记结束。
  ///
  /// `extractSections` 已经把正文压平过了，而图墙卡片需要 `</a>` 结构做链接配对，
  /// 所以这里重新按标记取原始片段。找不到标记返回 null（调用方按空结果降级）。
  String? _rawSection(String title, String html, {required String endMarker}) {
    final i = html.indexOf(title);
    if (i < 0) return null;
    final from = i + title.length;
    final j = html.indexOf(endMarker, from);
    return html.substring(from, j < 0 ? html.length : j);
  }

  String? _titleOf(String html) {
    final m = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1)?.trim();
  }
}

/// 一次城市页抓取的产出。
class GuideCrawlResult {
  GuideCrawlResult({
    Map<String, List<Map<String, dynamic>>>? sections,
    List<Map<String, dynamic>>? articles,
    List<String>? layers,
  })  : sections = sections ?? {},
        articles = articles ?? [],
        layers = layers ?? [];

  final Map<String, List<Map<String, dynamic>>> sections;
  List<Map<String, dynamic>> articles;
  final List<String> layers;

  bool get isEmpty => sections.isEmpty && articles.isEmpty;
}

/// JSON 辅助（测试用）。
Map<String, dynamic> decodeJsonMap(String s) =>
    (jsonDecode(s) as Map).cast<String, dynamic>();
