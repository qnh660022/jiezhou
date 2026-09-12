/// 攻略数据模型（V2.6 任务5，§7.3 缓存 JSON 契约）+ 校验。
library;

import 'guide_content_filter.dart' show cjkCount;

/// 六栏条目模型。
class GuideItem {
  const GuideItem(this.map);
  final Map<String, dynamic> map;

  String get title => (map['title'] ?? map['name'] ?? '') as String;
  String get detail => (map['detail'] ?? map['note'] ?? '') as String;
}

class GuideCity {
  GuideCity(this.key, this.name, this.sections,
      {this.articles = const [], this.area = ''});

  final String key;
  final String name;

  /// 六栏：prep / spots / food / transport / tips / budget。
  final Map<String, List<Map<String, dynamic>>> sections;

  /// 精选文章（仅聚合层产出）。
  final List<Map<String, dynamic>> articles;

  /// 所属大区（直辖市/华东/华南/华中/西南/西北/华北/东北/港澳台）。
  ///
  /// 2026-09 新增：攻略页「换城市」选择器按大区分组展示精品城市。
  /// 老数据没有该字段时为空串，不影响校验与渲染。
  final String area;

  // ===== JSON 契约 =====

  Map<String, dynamic> toJson({List<String> layersUsed = const []}) => {
        'key': key,
        'name': name,
        if (area.isNotEmpty) 'area': area,
        'sections': sections,
        if (articles.isNotEmpty) 'articles': articles,
        'layersUsed': layersUsed,
      };

  static const List<String> sectionKeys = [
    'prep', 'spots', 'food', 'transport', 'tips', 'budget',
  ];

  /// 六栏中文名（UI 与导入校验共用，避免多处 switch 漂移）。
  static const Map<String, String> sectionLabels = {
    'prep': '行前准备',
    'spots': '景点推荐',
    'food': '美食',
    'transport': '交通',
    'tips': '避坑注意',
    'budget': '预算参考',
  };

  /// 正文汉字数（阅读时长估算与「15 分钟以上」校验用）。
  ///
  /// 传 `raw`（任意含 `sections` 的 JSON）算那份数据；不传则算当前对象。
  static int textCharCount([Map<String, dynamic>? raw, Map<String, dynamic>? sections]) {
    final src = sections ?? (raw?['sections'] as Map?);
    if (src == null) return 0;
    var n = 0;
    for (final k in sectionKeys) {
      for (final it in (src[k] as List?) ?? const []) {
        if (it is! Map) continue;
        for (final v in it.values) {
          if (v is String) n += cjkCount(v);
        }
      }
    }
    return n;
  }

  /// 当前实例的正文汉字数。
  int get textChars => textCharCount(null, sections);

  /// 按 350 汉字/分钟估算阅读时长（向上取整，至少 1 分钟）。
  static int readingMinutes(int chars) => chars <= 0 ? 0 : (chars / 350).ceil();

  /// 校验：六栏 key 齐全、各栏为 List、name/key 非空（§7.18）。
  ///
  /// 容忍新增字段（area 等）：缺失不报错，保证老缓存/老更新包仍可用。
  static String? validate(Map<String, dynamic> m) {
    if (m['key'] is! String || (m['key'] as String).isEmpty) return 'key';
    if (m['name'] is! String || (m['name'] as String).isEmpty) return 'name';
    final s = m['sections'];
    if (s is! Map) return 'sections';
    for (final k in sectionKeys) {
      if (!s.containsKey(k)) return 'missing:$k';
      if (s[k] is! List) return 'type:$k';
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is GuideCity && other.key == key;
  @override
  int get hashCode => key.hashCode;
}
