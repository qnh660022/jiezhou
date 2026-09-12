/// AI 输出的攻略 JSON 解析（粘贴导入用）。
///
/// 模型经常把 JSON 包在 ```json 代码块里，或前后带一句「好的，这是攻略：」。
/// 这里做**宽容解析**：先从文本里定位第一个平衡的 `{…}`，再按 JSON 解析；
/// 解析失败返回 null，由调用方给用户可读的错误提示。
library;
import 'dart:convert';

import 'guide_models.dart';

/// 从任意文本里抽出第一个 JSON 对象并解析；失败返回 null。
Map<String, dynamic>? extractJsonObject(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        final raw = text.substring(start, i + 1);
        try {
          final obj = jsonDecode(raw);
          return obj is Map ? obj.cast<String, dynamic>() : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

/// 解析并校验一段「AI 生成的攻略」文本。
///
/// 返回 `(city, error)`：成功时 [error] 为 null；失败时给出可直接展示给用户的文案。
({Map<String, dynamic>? city, String? error}) parseGuideJson(
    String text, {
  String? expectKey,
  Map<String, String>? seedNames,
}) {
  if (text.trim().isEmpty) {
    return (city: null, error: '内容为空，先让 AI 生成攻略再粘贴');
  }
  final obj = extractJsonObject(text);
  if (obj == null) {
    return (city: null, error: '没找到合法 JSON；请让 AI 只输出 JSON 本体');
  }
  if (obj['sections'] is! Map) {
    return (city: null, error: '缺少 sections（六栏结构），不是一份攻略 JSON');
  }
  final key = (obj['key'] as String?)?.trim() ?? '';
  final name = (obj['name'] as String?)?.trim() ?? '';
  if (key.isEmpty || name.isEmpty) {
    return (city: null, error: '缺少 key 或 name（导入后无法挂到城市上）');
  }
  if (expectKey != null && key != expectKey) {
    return (city: null, error: '这份内容属于「$name」($key)，不是当前城市');
  }
  if (seedNames != null && !seedNames.containsKey(key)) {
    return (
      city: null,
      error: '攻略库里没有 $key；请让 AI 用已有城市的 key（可先在 AI 助手里问「有哪些城市」）'
    );
  }
  final err = GuideCity.validate(obj);
  if (err != null) {
    return (city: null, error: '结构不完整（$err），六栏必须齐全');
  }
  // 面积字段缺失时补一个空串，避免下游到处判空
  final city = <String, dynamic>{
    'key': key,
    'name': name,
    if ((obj['area'] as String?)?.isNotEmpty == true) 'area': obj['area'],
    'sections': obj['sections'],
  };
  return (city: city, error: null);
}

/// 生成给用户看的摘要（粘贴导入的预览卡使用）。
List<List<String>> guideJsonSummary(Map<String, dynamic> city) {
  final sections = (city['sections'] as Map?) ?? const {};
  final rows = <List<String>>[];
  for (final k in GuideCity.sectionKeys) {
    final items = (sections[k] as List?) ?? const [];
    final chars = GuideCity.textCharCount(null, {k: items});
    rows.add([GuideCity.sectionLabels[k] ?? k, '${items.length} 条 · $chars 字']);
  }
  final total = GuideCity.textCharCount(city);
  rows.add([
    '正文合计',
    '$total 字 · 约 ${GuideCity.readingMinutes(total)} 分钟',
  ]);
  return rows;
}
