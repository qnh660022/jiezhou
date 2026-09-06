/// 文章流聚合 + 品控（§7.7）：白名单源 + 每目的地 ≤8 篇 + 过滤 + 评分排序。
library;
import 'guide_crawler_rules.dart';
import 'guide_raw_html.dart';

class GuideAggregator {
  const GuideAggregator();

  /// 品控：标题 8~40 字、URL 去重、>180 天降权（仍保留但排尾）。
  List<Map<String, dynamic>> filterAndScore(
      List<Map<String, dynamic>> rawArticles, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final seen = <String>{};
    final scored = <(double, Map<String, dynamic>)>[];
    for (final a in rawArticles) {
      final title = (a['title'] as String?) ?? '';
      final url = (a['sourceUrl'] as String?) ?? (a['url'] as String?) ?? '';
      if (title.length < 8 || title.length > 40) continue; // 标题长度过滤
      if (url.isEmpty || seen.contains(url)) continue; // URL 去重
      seen.add(url);
      final rule = matchGuideRule(url, articles: true);
      final trust = rule?.trust ?? 0.4; // 白名单外按最低信誉
      final publishedAt = (a['publishedAt'] as num?)?.toInt() ?? 0;
      final fresh = freshnessScore(publishedAt, n);
      final score = trust * 0.6 + fresh * 0.4; // §7.7 评分公式
      final demote = publishedAt > 0 &&
          n.difference(DateTime.fromMillisecondsSinceEpoch(publishedAt)) >
              const Duration(days: 180);
      scored.add((demote ? score - 10 : score, {...a, 'score': score}));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.take(8).map((e) => e.$2).toList(); // 上限 8 篇
  }

  /// 新鲜度分：≤30 天=1.0，指数衰减至 180 天≈0.2。
  double freshnessScore(int publishedAtMs, DateTime now) {
    if (publishedAtMs <= 0) return 0.2;
    final days = now
        .difference(DateTime.fromMillisecondsSinceEpoch(publishedAtMs))
        .inDays
        .clamp(0, 365);
    if (days <= 30) return 1.0;
    if (days >= 180) return 0.2;
    // 指数衰减：30 天 1.0 → 180 天 0.2
    final t = (days - 30) / 150.0;
    return 1.0 - 0.8 * t;
  }

  /// 从文章正文 HTML 取首段摘要（不额外请求）。
  String? summarize(String html) {
    final ps = extractParagraphs(html, minLen: 12, max: 1);
    if (ps.isEmpty) return null;
    final s = ps.first;
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}
