/// 两点间通行时长估算服务抽象接口。
///
/// 实现归 integrator：haversine 直线距离 × 分模式平均速度免 key 估算；
/// 若 prefs_repo.mapConfig 配置了腾讯/高德 key 则走真实路线 API，
/// 失败自动回退直线估算。
library;

/// 出行方式
enum TravelMode {
  /// 步行（约 4 km/h）
  walk,

  /// 驾车（约 26 km/h）
  drive,

  /// 公交（约 16 km/h）
  transit,
}

/// 结果来源标记
enum TravelEstimateSource {
  /// 直线距离 × 平均速度估算（免 key，永远可用）
  estimate,

  /// 真实路线 API 返回（需配置 key）
  route,
}

/// 时长估算结果（纯数据类）
class TravelEstimate {
  const TravelEstimate({
    required this.minutes,
    required this.distanceKm,
    required this.source,
  });

  /// 预计耗时（分钟，向上取整，至少 1）
  final int minutes;

  /// 距离（公里；estimate 模式为球面直线距离）
  final double distanceKm;

  /// 来源标记
  final TravelEstimateSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TravelEstimate &&
          minutes == other.minutes &&
          distanceKm == other.distanceKm &&
          source == other.source;

  @override
  int get hashCode => Object.hash(minutes, distanceKm, source);
}

abstract class TravelTimeService {
  /// 估算两点间通行时长。任何情况下都不抛异常：
  /// 无网络/无 key 时返回直线估算（source=estimate）。
  Future<TravelEstimate> minutesBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2, {
    TravelMode mode = TravelMode.drive,
  });

  /// 连通性测试：当前配置的地图服务商（腾讯/高德）是否可用。
  /// 未配置或请求失败返回 false —— map-settings 屏的「测试连接」按钮使用。
  Future<bool> pingProvider();
}
