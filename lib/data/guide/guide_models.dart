/// 攻略数据模型（V2.6 任务5，§7.3 缓存 JSON 契约）+ 校验。
library;

/// 六栏条目模型。
class GuideItem {
  const GuideItem(this.map);
  final Map<String, dynamic> map;

  String get title => (map['title'] ?? map['name'] ?? '') as String;
  String get detail => (map['detail'] ?? map['note'] ?? '') as String;
}

class GuideCity {
  GuideCity(this.key, this.name, this.sections, {this.articles = const []});

  final String key;
  final String name;

  /// 六栏：prep / spots / food / transport / tips / budget。
  final Map<String, List<Map<String, dynamic>>> sections;

  /// 精选文章（仅聚合层产出）。
  final List<Map<String, dynamic>> articles;

  // ===== JSON 契约 =====

  Map<String, dynamic> toJson({List<String> layersUsed = const []}) => {
        'key': key,
        'name': name,
        'sections': sections,
        if (articles.isNotEmpty) 'articles': articles,
        'layersUsed': layersUsed,
      };

  static const List<String> sectionKeys = [
    'prep', 'spots', 'food', 'transport', 'tips', 'budget',
  ];

  /// 校验：六栏 key 齐全、各栏为 List、name/key 非空（§7.18）。
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
