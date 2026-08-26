// 数据来源: D:\AI\money\utils\trip.js · 条数 5
// 由 travel-assistant-v2/integrator 从旧版小程序数据层迁移生成；纯常量，无任何第三方/flutter 依赖。
// 行程安排（trip item）类型常量。colorIndex 为应用主题色板索引（0 起），
// 迁移对照旧版十六进制色值：0=#4f8ff7, 1=#f7a84f, 2=#38c3c3, 3=#9b7bf2, 4=#9aa0a6。

/// 行程安排类型。
class TripItemType {
  /// 类型 key：attraction | food | transport | stay | note
  final String key;

  /// 显示名
  final String name;

  /// 图标（emoji）
  final String icon;

  /// 主题色板索引
  final int colorIndex;

  const TripItemType(this.key, this.name, this.icon, this.colorIndex);
}

/// 五类安排类型全集（顺序即主题色索引顺序）。
const List<TripItemType> kItemTypes = [
  TripItemType('attraction', '景点', '🏛️', 0),
  TripItemType('food', '餐饮', '🍜', 1),
  TripItemType('transport', '交通', '🚗', 2),
  TripItemType('stay', '住宿', '🏨', 3),
  TripItemType('note', '备注', '📝', 4),
];

/// 按 key 查找类型；未命中回落到「备注」（对齐旧版 getItemType）。
TripItemType findTripItemType(String key) {
  for (final t in kItemTypes) {
    if (t.key == key) return t;
  }
  return kItemTypes[kItemTypes.length - 1];
}
