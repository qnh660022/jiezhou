// 数据来源: D:\AI\money\utils\flight.js · 条数 11
// 由 travel-assistant-v2/integrator 从旧版小程序数据层迁移生成；纯常量，无任何第三方/flutter 依赖。
// 常用航线速查（离线命中，避免每次联网识别航班号）。

/// 常用航线。
class CommonRoute {
  /// 航班号
  final String no;

  /// 始发机场 IATA 码
  final String from;

  /// 到达机场 IATA 码
  final String to;

  const CommonRoute(this.no, this.from, this.to);
}

/// 内置常用航线全集。
const List<CommonRoute> kCommonRoutes = [
  CommonRoute('CA1833', 'PEK', 'SHA'),
  CommonRoute('CA1301', 'PEK', 'CAN'),
  CommonRoute('CA981', 'PEK', 'JFK'),
  CommonRoute('CA937', 'PEK', 'LHR'),
  CommonRoute('MU5101', 'SHA', 'PEK'),
  CommonRoute('MU583', 'PVG', 'LAX'),
  CommonRoute('MU551', 'PVG', 'LHR'),
  CommonRoute('CZ3101', 'CAN', 'PEK'),
  CommonRoute('CZ327', 'CAN', 'LAX'),
  CommonRoute('3U8881', 'CTU', 'PEK'),
  CommonRoute('MF8101', 'XMN', 'PEK'),
];

/// 按航班号查找常用航线（自动忽略大小写、空格与连字符）；未命中返回 null。
CommonRoute? findCommonRoute(String flightNo) {
  final normalized = flightNo.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  for (final r in kCommonRoutes) {
    if (r.no == normalized) return r;
  }
  return null;
}
