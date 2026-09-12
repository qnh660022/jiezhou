/// 手写轻量 HTML 清洗（§7.4）：不引入外部解析依赖。
/// 去 script/style/注释/标签、解码常见实体、空白压缩、按块级标签分段抽取。
library;

/// 清洗正文：返回按段落分行的纯文本。
String cleanGuideHtml(String html) {
  var s = html;
  // script/style/noscript/iframe 整块剔除
  s = s.replaceAll(
      RegExp(r'<(script|style|noscript|iframe)[^>]*>.*?</\1>',
          dotAll: true, caseSensitive: false),
      '');
  // 注释
  s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  // 块级标签结尾转换行分段
  s = s.replaceAllMapped(
      RegExp(r'</(p|div|h[1-6]|li|tr|section|article|blockquote)>',
          caseSensitive: false),
      (_) => '\n');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  // 剩余标签
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  // 实体解码（常见集）
  s = _decodeEntities(s);
  // 空白压缩（保留换行）
  s = s.replaceAll(RegExp(r'[ \t\r\f]+'), ' ');
  s = s.replaceAll(RegExp(r'\n\s*\n+'), '\n');
  return s.trim();
}

/// 抽取正文段落列表（非空、去重、长度过滤）。
List<String> extractParagraphs(String html, {int minLen = 8, int max = 20}) {
  final text = cleanGuideHtml(html);
  final seen = <String>{};
  final out = <String>[];
  for (final line in text.split('\n')) {
    final l = line.trim();
    if (l.length < minLen) continue;
    if (seen.contains(l)) continue;
    seen.add(l);
    out.add(l);
    if (out.length >= max) break;
  }
  return out;
}

String _decodeEntities(String s) {
  return s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&mdash;', '—')
      .replaceAll('&hellip;', '…')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.tryParse(m.group(1)!);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      });
}

// ============================================================
// 结构化抽取（2026-09 换源：去哪儿城市页）
//
// 通用段落抽取（extractParagraphs）只适合「整页都是正文」的文章页；去哪儿城市页
// 导航占了七成体积，必须按段落标记切块后再取块内文本。
// ============================================================

/// 一个带层级的标题块（去哪儿城市页的段落标记都是 `<h1>`/`<h2>`）。
class HtmlSection {
  const HtmlSection({required this.level, required this.title, required this.body});
  final int level; // 1 / 2 / 3
  final String title; // 去掉标签后的标题文本
  final String body; // 该标题到下一个同级或更高级标题之间的纯文本
}

/// 抽出全部标题块（标题 + 块内正文），按出现顺序返回。
///
/// 正文走 [cleanGuideHtml]（去 script/style/注释、实体解码、压缩空白），
/// 因此可以直接按行取要点。
List<HtmlSection> extractSections(String html) {
  final marks = <({int level, String title, int start, int end})>[];
  final re = RegExp(r'<h([1-3])[^>]*>([\s\S]{0,200}?)</h\1>', caseSensitive: false);
  for (final m in re.allMatches(html)) {
    final title = _decodeEntities(m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), ''))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty || title.length > 60) continue;
    marks.add((
      level: int.parse(m.group(1)!),
      title: title,
      start: m.end,
      end: html.length,
    ));
  }
  final out = <HtmlSection>[];
  for (var i = 0; i < marks.length; i++) {
    // 块尾 = 下一个 level <= 当前 level 的标题起点
    var end = html.length;
    for (var j = i + 1; j < marks.length; j++) {
      if (marks[j].level <= marks[i].level) {
        end = marks[j].start - 1;
        break;
      }
    }
    out.add(HtmlSection(
      level: marks[i].level,
      title: marks[i].title,
      body: cleanGuideHtml(html.substring(marks[i].start, end)),
    ));
  }
  return out;
}

/// 按标题文本取块（可选层级），标题做包含匹配——站点常给标题加装饰。
HtmlSection? sectionByTitle(String html, String title, {int? level}) {
  for (final s in extractSections(html)) {
    if (level != null && s.level != level) continue;
    if (s.title.contains(title)) return s;
  }
  return null;
}

/// 取两段标记之间的原始 HTML（用于「不可错过」这类无标题的图墙区块）。
/// [startMarker] 不存在时返回 null（调用方按空结果降级，不猜）。
String? extractBetween(String html, String startMarker, {String? endMarker}) {
  final i = html.indexOf(startMarker);
  if (i < 0) return null;
  final from = i + startMarker.length;
  if (endMarker == null) return html.substring(from);
  final j = html.indexOf(endMarker, from);
  return html.substring(from, j < 0 ? html.length : j);
}

/// 块内正文按行切成要点列表（已去噪、去重、限长）。
///
/// [minLen] 单行最短长度；[maxLen] 超过即截断（导航残留常常一整行糊在一起）。
List<String> bulletLines(
  String body, {
  int minLen = 4,
  int maxLen = 400,
  bool Function(String)? keep,
  int max = 40,
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in body.split('\n')) {
    var l = raw.trim();
    if (l.length < minLen) continue;
    if (l.length > maxLen) l = l.substring(0, maxLen);
    if (!seen.add(l)) continue;
    if (keep != null && !keep(l)) continue;
    out.add(l);
    if (out.length >= max) break;
  }
  return out;
}

/// 抽取「链接文字 + 链接尾随说明」成对结构（去哪儿攻略的 POI 卡片：
/// `>景点名</a>` 后紧跟一句简介）。
///
/// 返回 `(text, tail)` 列表：[tail] 是该 `</a>` 之后到下一个 `<a` 之间的纯文本。
/// 用 `</a>` 作为起点锚（而不是 `<a ...>`）：从开标签到闭标签之间是链接文字，
/// 闭标签之后才是简介——早前从开标签起算会把文字本身吃进 tail。
List<({String text, String tail})> extractLinkPairs(String html, {int max = 60}) {
  final out = <({String text, String tail})>[];
  final starts = <int>[];
  for (final m in RegExp(r'<a\b').allMatches(html)) {
    starts.add(m.start);
  }
  if (starts.isEmpty) return out;
  starts.add(html.length); // 哨兵：最后一个链接的 tail 到文末
  final closeRe = RegExp(r'</a>', caseSensitive: false);
  for (var i = 0; i + 1 < starts.length; i++) {
    final seg = html.substring(starts[i], starts[i + 1]);
    final close = closeRe.firstMatch(seg);
    if (close == null) continue;
    final inner = seg.substring(0, close.start);
    // 链接文字：去掉内层标签后取纯文本（保留最后一段非空文本）
    final text = _decodeEntities(inner.replaceAll(RegExp(r'<[^>]*>'), ''))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty || text.length > 40) continue;
    final tail = cleanGuideHtml(seg.substring(close.end))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    out.add((text: text, tail: tail));
    if (out.length >= max) break;
  }
  return out;
}

/// 取页面城市名（`<h1>城市旅游攻略</h1>` 或 `<title>` 前缀），用于抓取后复核
/// 「拿到的到底是不是这座城市」——去哪儿 URL 里 ID 才是权威，ID/slug 错配会
/// 静默返回别的城市。
String? pageCityName(String html) {
  final heads = RegExp(r'<h1[^>]*>([\s\S]{0,80}?)</h1>', caseSensitive: false)
      .allMatches(html);
  for (final m in heads) {
    var t = _decodeEntities(m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ''))
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'(旅游攻略|自助游|攻略)$'), '')
        .trim();
    if (t.isNotEmpty && t.length <= 8) return t;
  }
  final title = RegExp(r'<title[^>]*>([^<]{2,60})', caseSensitive: false)
      .firstMatch(html)
      ?.group(1);
  if (title == null) return null;
  final t = title.replaceAll(RegExp(r'(旅游攻略|自助游|旅游|攻略).*$'), '').trim();
  return (t.isNotEmpty && t.length <= 8) ? t : null;
}

