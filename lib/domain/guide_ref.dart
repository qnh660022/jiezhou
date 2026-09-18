/// guideRef 契约（V2.7.2 S5，规格 §8.1）。
///
/// 格式：`"<cityKey>#<栏>#<序号>"`，栏 ∈ spots|food，序号为种子该栏数组下标
/// （0 起，十进制 int）。弱关联：不做外键、不做内容快照；种子更新导致序号
/// 漂移/越界/城缺失时，消费端反查失败一律静默降级（角标隐藏/精要不渲染）。
library;

/// 种子 timeText → durationMin 固定映射（规格附录 T1，枚举固定不变）。
const Map<String, int> kGuideTimeTextDuration = {
  '1-2小时': 90,
  '2-3小时': 150,
  '半天': 240,
  '一天': 480,
};

/// 攻略条目 timeText → 预估时长（分钟）；未登记/为空返回 null（未估时）。
int? guideDurationFromTimeText(String? timeText) {
  if (timeText == null) return null;
  return kGuideTimeTextDuration[timeText.trim()];
}

class GuideRef {
  const GuideRef({
    required this.cityKey,
    required this.section,
    required this.index,
  });

  final String cityKey;
  final String section; // spots | food
  final int index;

  /// 参与互链的栏目（其余栏目——prep/tips/budget/calendar/transport——不提供动作）。
  static const Set<String> knownSections = {'spots', 'food'};

  /// 非法 → null（空串/段数不对/栏不合法/序号负数或非数字）。
  static GuideRef? tryParse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final parts = s.split('#');
    if (parts.length != 3) return null;
    final cityKey = parts[0].trim();
    final section = parts[1].trim();
    final index = int.tryParse(parts[2].trim());
    if (cityKey.isEmpty || !knownSections.contains(section)) return null;
    if (index == null || index < 0) return null;
    return GuideRef(cityKey: cityKey, section: section, index: index);
  }

  /// 规范化输出。
  String format() => '$cityKey#$section#$index';

  /// 同城同栏前缀（前缀反查用）。
  String prefix() => '$cityKey#$section#';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuideRef &&
          other.cityKey == cityKey &&
          other.section == section &&
          other.index == index;

  @override
  int get hashCode => Object.hash(cityKey, section, index);

  @override
  String toString() => 'GuideRef(${format()})';
}
