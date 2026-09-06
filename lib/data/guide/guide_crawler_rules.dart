/// 白名单配置（§7.6）：3~5 个中文站；每源带域名/路径模式/来源信誉分。
/// 硬性纪律：robots 前置、限速 ≥2s/域名、不对抗反爬、只取正文文本、
/// 内容必须带 sourceUrl+来源名。
library;

class GuideSourceRule {
  const GuideSourceRule({
    required this.name,
    required this.host,
    required this.pathPattern,
    required this.trust,
  });

  final String name; // 来源展示名
  final String host; // 域名
  final RegExp pathPattern; // 允许抓取的路径模式（只抓显式列出的页面类型）
  final double trust; // 源信誉分 0.4~1.0
}

/// 结构化正文爬取白名单（§7.6 最终清单，验收报告同步）。
final List<GuideSourceRule> kGuideCrawlerRules = [
  GuideSourceRule(
    name: '马蜂窝',
    host: 'www.mafengwo.cn',
    pathPattern: RegExp(r'^/yj/\d+'), // 游记正文页
    trust: 0.9,
  ),
  GuideSourceRule(
    name: '穷游网',
    host: 'bbs.qyer.com',
    pathPattern: RegExp(r'^/thread-\d+'), // 攻略帖
    trust: 0.85,
  ),
  GuideSourceRule(
    name: '知乎',
    host: 'zhuanlan.zhihu.com',
    pathPattern: RegExp(r'^/p/\d+'), // 专栏文章
    trust: 0.8,
  ),
];

/// 文章流 RSS/公开接口白名单（§7.7；无 RSS 的源由爬虫层抓列表页，同限速纪律）。
final List<GuideSourceRule> kGuideArticleRules = [
  GuideSourceRule(
      name: '马蜂窝',
      host: 'www.mafengwo.cn',
      pathPattern: RegExp(r'^/yj/'),
      trust: 0.9),
  GuideSourceRule(
      name: '穷游网',
      host: 'bbs.qyer.com',
      pathPattern: RegExp(r'^/thread-'),
      trust: 0.85),
  GuideSourceRule(
      name: '知乎',
      host: 'zhuanlan.zhihu.com',
      pathPattern: RegExp(r'^/p/'),
      trust: 0.8),
];

/// URL 是否命中白名单。
GuideSourceRule? matchGuideRule(String url, {bool articles = false}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final rules = articles ? kGuideArticleRules : kGuideCrawlerRules;
  for (final r in rules) {
    if (uri.host == r.host && r.pathPattern.hasMatch(uri.path)) return r;
  }
  return null;
}
