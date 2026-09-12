/// 爬虫白名单（§7.6，2026-09 换源）。
///
/// ## 2026-09 实测结论（决定了下面这份清单）
/// | 站点 | robots | 实测 |
/// |---|---|---|
/// | `www.mafengwo.cn` | `User-agent: *` → `Disallow: /`（全站禁抓） | 返回 202 空壳 |
/// | `bbs.qyer.com` | 重定向到 search.qyer.com | 命中「完成安全验证」JS 壳 |
/// | `zhuanlan.zhihu.com` | `*` → `Allow:/tardis/jm` + `Disallow:/` | 专栏页 403 |
/// | `www.sohu.com` | `*` → `Disallow: /` | 通用 UA 一律禁抓 |
/// | **`travel.qunar.com`** | `*` 仅禁 `/plan*`、`/search/`、含 `?` 的 URL | **200 + UTF-8 + 服务端直出中文正文** |
///
/// 所以本轮生效的国内源只有去哪儿攻略；其余四家保留在表里并标 `enabled: false`
/// （记录实测结论，方便日后复查/换源，不参与匹配）。
///
/// ## 关键坑
/// 去哪儿的 URL 里 **ID 才是权威**，slug 只是装饰：`p-cs<id>-<slug>` 若 ID 与 slug
/// 不匹配，服务端会按 ID 渲染并**静默返回另一座城市**（HTTP 仍是 200）。因此：
/// - 城市页 URL 一律由 `guide_city_sources.dart` 的 ID 表构造；
/// - 抓回来必须用 `pageCityName()` 复核城市名，对不上直接丢弃。
///
/// ## 硬性纪律（SPEC，违反即不合格）
/// 1. robots 前置（缓存 24h），disallow 的路径不强爬；
/// 2. 同域名请求间隔 ≥ 规则里的 crawlDelay（默认 1s），并发 ≤3；
/// 3. 不闯登录墙、不解 CAPTCHA、不伪造 Cookie/Referer 绕 403/429——
///    收到反爬信号即放弃该源并降级；
/// 4. 只提取正文文本，不下载图片媒体本体；
/// 5. 任何被采用的内容必须带 `sourceUrl` + 来源名；
/// 6. 单 URL 缓存 7 天；失败 30 分钟内不重爬。
library;

class GuideSourceRule {
  const GuideSourceRule({
    required this.name,
    required this.host,
    required this.pathPattern,
    required this.trust,
    this.enabled = true,
    this.charset = '',
    this.crawlDelay = const Duration(seconds: 1),
    this.note = '',
  });

  final String name; // 来源展示名
  final String host; // 域名
  final RegExp pathPattern; // 允许抓取的路径模式
  final double trust; // 源信誉分 0.4~1.0
  final bool enabled; // 是否参与匹配（false = 只留档）
  final String charset; // 空=按响应头/UTF-8 猜测
  final Duration crawlDelay; // 同域最小间隔（robots 里有 Crawl-delay 时取更大者）
  final String note; // 换源依据/实测结论
}

/// 正文抓取白名单。
final List<GuideSourceRule> kGuideCrawlerRules = [
  GuideSourceRule(
    name: '去哪儿攻略',
    host: 'travel.qunar.com',
    pathPattern: RegExp(r'^/p-cs\d+-[a-z0-9]+$'),
    trust: 0.9,
    charset: 'utf-8',
    crawlDelay: Duration(seconds: 1),
    note: '实测唯一可用：robots 对通用 UA 放行 + 服务端直出中文正文；只有主城市页可用',
  ),
  // ===== 以下四家实测不可用，保留规则仅作记录（enabled: false） =====
  GuideSourceRule(
    name: '马蜂窝',
    host: 'www.mafengwo.cn',
    pathPattern: RegExp(r'^/yj/\d+'),
    trust: 0.9,
    enabled: false,
    note: 'robots: User-agent:* Disallow:/（全站禁抓）；实测返回 202 空壳',
  ),
  GuideSourceRule(
    name: '穷游网',
    host: 'bbs.qyer.com',
    pathPattern: RegExp(r'^/thread-\d+'),
    trust: 0.85,
    enabled: false,
    note: '重定向到 search.qyer.com，命中「完成安全验证」JS 壳',
  ),
  GuideSourceRule(
    name: '知乎',
    host: 'zhuanlan.zhihu.com',
    pathPattern: RegExp(r'^/p/\d+'),
    trust: 0.8,
    enabled: false,
    note: 'robots: * Disallow:/；实测专栏页 403',
  ),
  GuideSourceRule(
    name: '搜狐旅游',
    host: 'www.sohu.com',
    pathPattern: RegExp(r'^/a/\d+'),
    trust: 0.7,
    enabled: false,
    note: 'robots: * Disallow:/（仅放行白名单搜索引擎 UA）；文章页本身可读，但通用 UA 不在放行名单内',
  ),
];

/// 文章流白名单（游记/攻略列表）。去哪儿城市页的「热门攻略」区块即在此列。
final List<GuideSourceRule> kGuideArticleRules = [
  GuideSourceRule(
    name: '去哪儿攻略',
    host: 'travel.qunar.com',
    pathPattern: RegExp(r'^/youji/\d+$'),
    trust: 0.85,
    charset: 'utf-8',
    crawlDelay: Duration(seconds: 1),
    note: '城市页「热门攻略」区块里的游记详情页（只做外跳，不抓正文）',
  ),
  GuideSourceRule(
    name: '马蜂窝',
    host: 'www.mafengwo.cn',
    pathPattern: RegExp(r'^/yj/'),
    trust: 0.9,
    enabled: false,
    note: '同正文白名单：全站禁抓',
  ),
  GuideSourceRule(
    name: '穷游网',
    host: 'bbs.qyer.com',
    pathPattern: RegExp(r'^/thread-'),
    trust: 0.85,
    enabled: false,
    note: '同正文白名单：安全验证壳',
  ),
];

/// URL 是否命中白名单（只匹配 enabled 规则）。
GuideSourceRule? matchGuideRule(String url, {bool articles = false}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final rules = articles ? kGuideArticleRules : kGuideCrawlerRules;
  for (final r in rules) {
    if (!r.enabled) continue;
    if (uri.host == r.host && r.pathPattern.hasMatch(uri.path)) return r;
  }
  return null;
}

/// 该域名是否落在「已知禁抓」名单里（含 robots 全禁的站点）。
///
/// 用于在发现阶段就掐断，不浪费一次请求：即便规则被临时启用，
/// 这些域名也不应被抓。
bool isKnownBlockedHost(String host) {
  const blocked = {
    'www.mafengwo.cn',
    'm.mafengwo.cn',
    'bbs.qyer.com',
    'search.qyer.com',
    'zhuanlan.zhihu.com',
    'www.sohu.com',
  };
  return blocked.contains(host);
}
