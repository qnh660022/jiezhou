/// 目的地 → 种子城 key 匹配（V2.7.2 S9，纯函数；规格 §12.2）。
///
/// 算法：
/// 1. 按分隔符 `[-/／、·\s]+` 切段；
/// 2. 每段 trim → 去尾部「市」→ 与种子 city.name 全等比较（O(1) Map 注入）；
/// 3. 首个命中段 → 返回其 cityKey；无命中 → null。
library;

final RegExp _kSeparator = RegExp(r'[-/／、·\s]+');

/// [nameToKey]：种子城名 → cityKey（含 AI 导入/官网覆盖层；加载时构建一次）。
String? matchCityKey(String destination, Map<String, String> nameToKey) {
  if (destination.trim().isEmpty) return null;
  for (final raw in destination.split(_kSeparator)) {
    var seg = raw.trim();
    if (seg.isEmpty) continue;
    if (seg.length > 1 && seg.endsWith('市')) {
      seg = seg.substring(0, seg.length - 1);
    }
    final key = nameToKey[seg];
    if (key != null) return key;
  }
  return null;
}
