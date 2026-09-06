/// 开源数据增强层（§7.2-②）：公开无版权争议源补充事实/坐标。
/// 本轮为可空实现（规格允许：不可用则此层为空），预留接入位。
library;
import 'guide_models.dart';

class GuideOpenSourceLayer {
  const GuideOpenSourceLayer();

  /// 返回 null = 该层无数据（静默降级到下一层）。
  Future<Map<String, List<Map<String, dynamic>>>>? enhance(String cityKey) =>
      null;
}
