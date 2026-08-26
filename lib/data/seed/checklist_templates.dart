// 数据来源: D:\AI\money\utils\trip.js · 组数 6 · 条目共 40
// 由 travel-assistant-v2/integrator 从旧版小程序数据层迁移生成；纯常量，无任何第三方/flutter 依赖。
// 行李/待办清单分类与默认模板文案。

/// 清单分类模板。
class ChecklistCategory {
  /// 分类 key（持久化用）
  final String key;

  /// 分类显示名
  final String name;

  /// 分类图标（emoji）
  final String icon;

  /// 该组默认清单文案
  final List<String> items;

  const ChecklistCategory(this.key, this.name, this.icon, this.items);
}

/// 清单分类模板全集（证件票务/衣物/电子设备/洗漱用品/药品/其他）。
const List<ChecklistCategory> kChecklistCategories = [
  ChecklistCategory('docs', '证件票务', '🪪', [
    '身份证',
    '护照',
    '签证材料',
    '机票/车票',
    '酒店预订单',
    '驾驶证',
    '景区预约凭证',
  ]),
  ChecklistCategory('clothes', '衣物', '👕', [
    '换洗衣物',
    '外套',
    '睡衣',
    '内衣袜子',
    '运动鞋',
    '拖鞋',
    '泳衣泳裤',
    '防晒衣',
  ]),
  ChecklistCategory('electronics', '电子设备', '🔌', [
    '手机',
    '充电器',
    '移动电源',
    '耳机',
    '相机',
    '转换插头',
    '自拍杆',
  ]),
  ChecklistCategory('toiletries', '洗漱用品', '🧴', [
    '牙刷',
    '牙膏',
    '毛巾',
    '洗面奶',
    '防晒霜',
    '护肤品',
    '梳子',
  ]),
  ChecklistCategory('medicine', '药品', '💊', [
    '常用药',
    '创可贴',
    '晕车药',
    '肠胃药',
    '防蚊液',
  ]),
  ChecklistCategory('other', '其他', '📦', [
    '雨伞',
    '水杯',
    '零食',
    '旅行枕',
    '眼罩',
    '垃圾袋',
  ]),
];

/// 按 key 查找清单分类；未命中时回落到最后一组「其他」（对齐旧版 getChecklistCategory）。
ChecklistCategory findChecklistCategory(String key) {
  for (final c in kChecklistCategories) {
    if (c.key == key) return c;
  }
  return kChecklistCategories[kChecklistCategories.length - 1];
}
