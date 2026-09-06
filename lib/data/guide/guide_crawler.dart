/// 白名单精爬层（§7.6）：正文要点/清单。仅 Android；非 Android 返回"不支持"空层。
library;
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'guide_crawler_rules.dart';
import 'guide_http.dart';
import 'guide_models.dart';
import 'guide_raw_html.dart';

class GuideCrawlLayer {
  GuideCrawlLayer(this._http);

  final GuideHttp _http;

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 抓取与城市相关的白名单正文，抽取条目（按栏粗分：段落含关键词归栏）。
  /// [urls] 由上层（service）基于城市搜索词构造或由文章流候选提供。
  Future<Map<String, List<Map<String, dynamic>>>> crawl(
      String cityKey, List<String> urls) async {
    if (!_supported) return {}; // 非平台：空层
    final out = <String, List<Map<String, dynamic>>>{};
    for (final url in urls) {
      final rule = matchGuideRule(url);
      if (rule == null) continue; // 白名单外一律不抓
      if (_http.isSourceCool(rule.host)) continue;
      final res = await _http.fetchText(url);
      if (res.cls != GuideFetchClass.ok) continue;
      final paragraphs = extractParagraphs(res.body);
      if (paragraphs.isEmpty) continue; // 解析类失败：按空结果降级，不重试
      await _http.persistRobots(rule.host);
      final classified = _classify(paragraphs);
      classified.forEach((section, items) {
        final stamped = [
          for (final it in items)
            {
              ...it,
              'source': rule.name,
              'sourceUrl': url,
            }
        ];
        out.putIfAbsent(section, () => []).addAll(stamped);
      });
      // 单城爬取上限：避免整页请求过多（纪律：只抓白名单显式页面）
      if (out.values.fold<int>(0, (n, l) => n + l.length) >= 12) break;
    }
    return out;
  }

  /// 段落粗分类：关键词路由到六栏（不足不硬凑）。
  Map<String, List<Map<String, dynamic>>> _classify(List<String> paragraphs) {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final p in paragraphs) {
      final target = _sectionOf(p);
      if (target == null) continue;
      final title = p.length > 24 ? p.substring(0, 24) : p;
      out.putIfAbsent(target, () => []).add({'title': title, 'detail': p});
      if ((out[target]!.length) >= 6) continue;
    }
    return out;
  }

  String? _sectionOf(String p) {
    if (RegExp(r'门票|预约|证件|防晒|保暖|装备|办理').hasMatch(p)) return 'prep';
    if (RegExp(r'景区|公园|博物馆|古镇|寺|山|湖|岛|长城|故居').hasMatch(p)) return 'spots';
    if (RegExp(r'美食|小吃|店|面|鸭|鱼|粉|火锅|茶').hasMatch(p)) return 'food';
    if (RegExp(r'地铁|公交|机场|高铁|打车|机场大巴').hasMatch(p)) return 'transport';
    if (RegExp(r'避坑|谨防|小心|勿|不要|投诉|陷阱').hasMatch(p)) return 'tips';
    if (RegExp(r'人均|预算|价格|元/|花费').hasMatch(p)) return 'budget';
    return null;
  }

  /// 文章列表页抓取（源无 RSS 时；同限速纪律）。返回候选文章链接。
  Future<List<String>> discoverArticleLinks(String cityCn) async {
    if (!_supported) return const [];
    final out = <String>[];
    for (final rule in kGuideArticleRules) {
      if (_http.isSourceCool(rule.host)) continue;
      // 只抓白名单配置里显式列出的搜索/列表形态页
      final url = switch (rule.host) {
        'www.mafengwo.cn' => 'https://www.mafengwo.cn/search/q.php?q=$cityCn',
        'bbs.qyer.com' => 'https://bbs.qyer.com/search.php?keyword=$cityCn',
        _ => 'https://zhuanlan.zhihu.com/$cityCn',
      };
      final res = await _http.fetchText(url);
      if (res.cls != GuideFetchClass.ok) continue;
      // 从列表页 HTML 抽取命中 pathPattern 的链接
      for (final m in RegExp(r'href="(https?://[^"]+)"')
          .allMatches(res.body)) {
        final link = m.group(1)!;
        if (matchGuideRule(link, articles: true) != null &&
            !out.contains(link)) {
          out.add(link);
        }
        if (out.length >= 12) break;
      }
    }
    return out;
  }
}

/// JSON 辅助（测试用）。
Map<String, dynamic> decodeJsonMap(String s) =>
    (jsonDecode(s) as Map).cast<String, dynamic>();
