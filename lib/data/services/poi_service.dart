/// 地点搜索服务抽象接口。
///
/// 实现归 integrator（lib/data/services/impl/poi_service_impl.dart）：
/// 三级来源合并 —— 内置离线库(seed builtin_pois) → Photon(无 key、中文) → Open-Meteo Geocoding(城市兜底)，
/// 离线结果排前，「name|lat三位小数」去重后最多返回 10 条；
/// 网络失败静默降级，绝不向 UI 抛异常。
library;

/// 结果来源标记
enum PoiSource {
  /// 内置离线地点库（seed/kBuiltinPois）
  offline,

  /// photon.komoot.io 免 key 在线检索（去掉 lang=zh 即可返回本地语言=中文名）
  photon,

  /// nominatim.openstreetmap.org 免 key 兜底（大陆不可达，保留枚举以兼容旧数据/UI，不再产生新结果）
  osm,

  /// geocoding-api.open-meteo.com 免 key 城市/行政区级检索（同天气基建，国内可达）
  openMeteo,

  /// 高德地图 place/text 官方检索（需配置 key，中文 POI 最全，返回 GCJ02 坐标经内部转 WGS84）
  amap,

  /// 腾讯地图地点搜索（需配置 key，返回 GCJ02 坐标经内部转 WGS84）
  qq,
}

/// 单条地点检索结果（纯数据类，UI 直接消费）
class PoiResult {
  const PoiResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.icon,
    required this.source,
  });

  /// 地点名称
  final String name;

  /// 详细地址（离线库为「城市 · 地址」拼接，在线为原始地址）
  final String address;

  /// 纬度
  final double lat;

  /// 经度
  final double lng;

  /// 分类图标 emoji（离线库自带；在线结果默认 📍）
  final String icon;

  /// 来源标记
  final PoiSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoiResult &&
          name == other.name &&
          address == other.address &&
          lat == other.lat &&
          lng == other.lng &&
          icon == other.icon &&
          source == other.source;

  @override
  int get hashCode => Object.hash(name, address, lat, lng, icon, source);

  @override
  String toString() => 'PoiResult($name, $lat, $lng, $source)';
}

abstract class PoiService {
  /// 关键字搜索地点。
  ///
  /// 返回去重合并后的候选列表（最多 10 条），离线优先；
  /// 任何异常都被实现吞掉并返回已有结果，空关键字返回空列表。
  Future<List<PoiResult>> search(String keyword);

  /// 逆地理编码：坐标 → 地址文本；失败或无网络时返回空串。
  Future<String> reverseGeocode(double lat, double lng);
}

/// 在线结果的默认图标
const String kDefaultPoiIcon = '📍';
