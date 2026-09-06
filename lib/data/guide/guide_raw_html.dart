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
