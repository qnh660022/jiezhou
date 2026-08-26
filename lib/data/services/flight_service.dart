/// 航班号识别服务抽象接口。
///
/// 实现归 integrator：正则解析(IATA/ICAO) → SharedPreferences 缓存(TTL 30 天)
/// → 内置 seed(62 航司/138 机场/11 常用航线) → adsbdb 在线兜底。
library;

/// 信息来源标记
enum FlightSource {
  /// 本地缓存命中（未过期）
  cache,

  /// 内置种子数据命中（航司库/常用航线）
  builtin,

  /// adsbdb 在线查询成功
  online,
}

/// 航班识别结果（纯数据类）
class FlightInfo {
  const FlightInfo({
    required this.flightNo,
    required this.airlineName,
    required this.fromAirport,
    required this.toAirport,
    required this.source,
    required this.cachedAt,
  });

  /// 规范化后的航班号（大写）
  final String flightNo;

  /// 航司中文名（未知航司回退空串由 UI 决定展示）
  final String airlineName;

  /// 出发机场名
  final String fromAirport;

  /// 到达机场名
  final String toAirport;

  /// 来源标记
  final FlightSource source;

  /// 该信息的获取时间（缓存命中时为当初写入时间）
  final DateTime cachedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightInfo &&
          flightNo == other.flightNo &&
          airlineName == other.airlineName &&
          fromAirport == other.fromAirport &&
          toAirport == other.toAirport &&
          source == other.source &&
          cachedAt == other.cachedAt;

  @override
  int get hashCode =>
      Object.hash(flightNo, airlineName, fromAirport, toAirport, source, cachedAt);
}

abstract class FlightService {
  /// 依据航班号（如 MU5137 / CES5137）识别航司与起降机场。
  ///
  /// 无法解析或全部来源失败时返回 null，不抛异常。
  Future<FlightInfo?> lookup(String flightNo);
}
