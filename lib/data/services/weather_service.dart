/// 天气预报服务抽象接口（数据源 Open-Meteo 免 key）。
///
/// 实现归 integrator：定位三级回退（行程首个带坐标安排 → seed city_coords
/// 目的地模糊匹配 → Nominatim 地理编码），结果按行程缓存 6 小时。
library;

/// 单日天气（纯数据类，日期为本地零点）
class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.codeText,
    required this.iconEmoji,
    required this.tempMax,
    required this.tempMin,
  });

  /// 当天日期（本地时区，时分秒为零）
  final DateTime date;

  /// 天气文案，如「晴」「小雨」
  final String codeText;

  /// 天气图标 emoji，如 ☀️🌧️
  final String iconEmoji;

  /// 最高气温（℃）
  final int tempMax;

  /// 最低气温（℃）
  final int tempMin;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherDay &&
          date == other.date &&
          codeText == other.codeText &&
          iconEmoji == other.iconEmoji &&
          tempMax == other.tempMax &&
          tempMin == other.tempMin;

  @override
  int get hashCode =>
      Object.hash(date, codeText, iconEmoji, tempMax, tempMin);
}

/// 天气查询参数（纯数据类，刻意不依赖 drift 生成的 Trip 对象，
/// 由仓储层从行程实体组装）。
class WeatherQuery {
  const WeatherQuery({
    required this.destination,
    required this.startEpochDay,
    required this.endEpochDay,
    this.anchorLat,
    this.anchorLng,
    this.tripId,
  });

  /// 行程目的地名称（用于城市坐标库匹配与在线地理编码兜底）
  final String destination;

  /// 开始日期（epochDay，见 core/date_utils.dart）
  final int startEpochDay;

  /// 结束日期（epochDay）
  final int endEpochDay;

  /// 定位锚点：行程内首个带坐标的安排纬度（可空）
  final double? anchorLat;

  /// 定位锚点：经度（可空）
  final double? anchorLng;

  /// 行程 id（缓存键的一部分，可空）
  final String? tripId;
}

abstract class WeatherService {
  /// 查询行程期间逐日天气。
  ///
  /// 请求区间会被钳制到 [今天, 今天+16]（Open-Meteo 免费预报上限）；
  /// 定位与网络全部失败时返回 null，静默降级不抛异常。
  Future<List<WeatherDay>?> daily(WeatherQuery query);
}
