/// POI 搜索实现：
/// - 配置高德 key 时：离线库 → 高德 place/text(官方、中文最全) → Photon → Open-Meteo
/// - 未配置 key：离线库 → Photon(无 key、中文) → Open-Meteo Geocoding(城市兜底)
/// 大陆网络下 Nominatim 已不可达，移除该层；reverseGeocode 同步切 Photon /reverse。
library;
import "package:dio/dio.dart";
import "dart:math" as math;
import "../poi_service.dart";
import "../../seed/builtin_pois.dart";
import "../../repo/prefs_repo.dart";

class PoiServiceImpl implements PoiService {
  PoiServiceImpl({Dio? dio, PrefsRepository? prefsRepo})
      : _dio = dio ?? Dio(),
        _prefsRepo = prefsRepo;
  final Dio _dio;
  final PrefsRepository? _prefsRepo;
  static const _ua = "TravelAssistant2/2.0";

  String? _amapKey;
  String? _qqKey;

  /// 每次搜索都重新读取配置，确保用户刚保存的 Key 在当前进程立即生效。
  Future<void> _ensureConfigLoaded() async {
    _amapKey = null;
    _qqKey = null;
    if (_prefsRepo == null) return;
    try {
      final cfg = await _prefsRepo!.getMapConfig();
      final provider = (cfg['provider'] as String?) ?? 'none';
      final key = (cfg['key'] as String?)?.trim() ?? '';
      if (key.isEmpty) return;
      if (provider == 'amap') {
        _amapKey = key;
      } else if (provider == 'qq') {
        _qqKey = key;
      }
    } catch (_) {
      // 配置读取失败时保留离线/公共服务兜底。
    }
  }

  /// OSM key/value → emoji 映射（仅覆盖常见 POI 类型，其余默认 📍）
  static const _iconMap = {
    // tourism
    'museum': '🏛️', 'artwork': '🖼️', 'attraction': '🏛️', 'viewpoint': '🌄',
    'hotel': '🏨', 'hostel': '🏨', 'guest_house': '🏨', 'motel': '🏨', 'camp_site': '⛺',
    // amenity
    'restaurant': '🍽️', 'cafe': '☕', 'bar': '🍻', 'pub': '🍻', 'fast_food': '🍔',
    'bank': '🏦', 'atm': '💳', 'pharmacy': '💊', 'hospital': '🏥', 'clinic': '🏥',
    'school': '🏫', 'university': '🏫', 'library': '📚', 'post_office': '📮',
    'police': '🚔', 'fire_station': '🚒', 'fuel': '⛽', 'charging_station': '🔌',
    'parking': '🅿️', 'bicycle_parking': '🚲', 'taxi': '🚖', 'bus_station': '🚌',
    'marketplace': '🛍️', 'shop': '🛍️', 'mall': '🛍️', 'supermarket': '🛒',
    'convenience': '🏪', 'bakery': '🥖', 'butcher': '🥩', 'ice_cream': '🍦',
    'cinema': '🎬', 'theatre': '🎭', 'nightclub': '🌃', 'casino': '🎰',
    'place_of_worship': '⛪', 'grave_yard': '⚰️',
    // railway
    'station': '🚉', 'halt': '🚉', 'tram_stop': '🚋', 'subway_entrance': '🚇',
    // aeroway
    'aerodrome': '✈️', 'heliport': '🚁',
    // leisure
    'park': '🌳', 'garden': '🌸', 'playground': '🛝', 'pitch': '⚽',
    'stadium': '🏟️', 'sports_centre': '🏟️', 'swimming_pool': '🏊',
    // natural
    'beach': '🏖️', 'peak': '⛰️', 'volcano': '🌋', 'spring': '♨️',
    // waterway
    'waterfall': '🌊',
    // boundary
    'national_park': '🏞️',
  };

  static String _iconFor(String? key, String? value) {
    if (key != null && value != null) {
      final v = _iconMap["$key=$value"];
      if (v != null) return v;
      final v2 = _iconMap[value];
      if (v2 != null) return v2;
    }
    return '📍';
  }

  /// 从 Photon properties 拼装可读地址：state > city > district > suburb > street+house
  static String _buildAddress(Map<String, dynamic> pr) {
    final parts = <String>[];
    void addIf(String? v) { if (v != null && v.isNotEmpty && !parts.contains(v)) parts.add(v); }
    addIf(pr["state"] as String?);
    addIf(pr["city"] as String?);
    addIf(pr["district"] as String?);
    addIf(pr["suburb"] as String?);
    final street = pr["street"] as String?;
    final house = pr["housenumber"] as String?;
    if (street != null && street.isNotEmpty) {
      addIf(house != null && house.isNotEmpty ? "$street $house" : street);
    }
    final name = (pr["name"] as String?) ?? "";
    if (parts.isNotEmpty && parts.last == name) parts.removeLast();
    return parts.join(" · ");
  }

  /// GCJ-02（火星/高德/腾讯）→ WGS-84（GPS/OSM）标准近似转换
  /// 误差 < 2 米，满足旅行规划精度；纯 Dart、无依赖
  static _GcjWgs _gcjToWgs(double gcjLat, double gcjLng) {
    const a = 6378245.0;
    const ee = 0.00669342162296594323;
    double transformLat(double x, double y) {
      double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
      ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
      ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
      ret += (160.0 * math.sin(y / 12.0 * math.pi) + 320.0 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
      return ret;
    }
    double transformLng(double x, double y) {
      double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
      ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
      ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
      ret += (150.0 * math.sin(x / 12.0 * math.pi) + 300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
      return ret;
    }
    double dLat = transformLat(gcjLng - 105.0, gcjLat - 35.0);
    double dLng = transformLng(gcjLng - 105.0, gcjLat - 35.0);
    final radLat = gcjLat / 180.0 * math.pi;
    double magic = math.sin(radLat);
    magic = 1 - ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
    dLng = (dLng * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
    return _GcjWgs(wgsLat: gcjLat - dLat, wgsLng: gcjLng - dLng);
  }

  @override
  Future<List<PoiResult>> search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return [];
    await _ensureConfigLoaded();

    final results = <PoiResult>[];
    final seen = <String>{};

    // 1) 内置离线库（种子数据）——永远在最前
    for (final p in kBuiltinPois) {
      if (p.name.contains(query) || p.city.contains(query) || p.address.contains(query)) {
        final key = "${p.name}|${p.lat.toStringAsFixed(3)}|${p.lng.toStringAsFixed(3)}";
        if (seen.add(key)) {
          results.add(PoiResult(
            name: p.name,
            address: "${p.city} ${p.address}",
            lat: p.lat,
            lng: p.lng,
            icon: p.icon,
            source: PoiSource.offline,
          ));
        }
      }
    }

    // 2) 腾讯官方地点搜索（配置腾讯 Key 时使用官方中文 POI）
    if (_qqKey != null) {
      try {
        final r = await _dio.get(
          "https://apis.map.qq.com/ws/place/v1/search",
          queryParameters: {
            "keyword": query,
            "page_size": 8,
            "page_index": 1,
            "key": _qqKey!,
          },
          options: Options(
            headers: {"User-Agent": _ua},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        if (r.data["status"] == 0 && r.data["data"] is List) {
          for (final p in r.data["data"] as List) {
            if (p is! Map) continue;
            final name = p["title"]?.toString() ?? "";
            final location = p["location"];
            if (name.isEmpty || location is! Map) continue;
            final gcjLat = (location["lat"] as num?)?.toDouble();
            final gcjLng = (location["lng"] as num?)?.toDouble();
            if (gcjLat == null || gcjLng == null) continue;
            final wgs = _gcjToWgs(gcjLat, gcjLng);
            final dedupeKey = "$name|${wgs.wgsLat.toStringAsFixed(3)}|${wgs.wgsLng.toStringAsFixed(3)}";
            if (!seen.add(dedupeKey)) continue;
            results.add(PoiResult(
              name: name,
              address: p["address"]?.toString() ?? "",
              lat: wgs.wgsLat,
              lng: wgs.wgsLng,
              icon: '📍',
              source: PoiSource.qq,
            ));
          }
        }
      } catch (_) {}
    }

    // 3) 高德官方 place/text（配置 key 时优先，中文 POI 覆盖最全）
    if (_amapKey != null) {
      try {
        final r = await _dio.get(
          "https://restapi.amap.com/v3/place/text",
          queryParameters: {
            "keywords": query,
            "key": _amapKey!,
            "citylimit": "true",
            "offset": 8,
            "page": 1,
            "extensions": "base",
            "output": "json",
          },
          options: Options(
            headers: {"User-Agent": _ua},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        if (r.data["status"] == "1" && r.data["pois"] != null) {
          for (final p in (r.data["pois"] as List)) {
            final name = p["name"] as String? ?? "";
            if (name.isEmpty) continue;
            final location = (p["location"] as String?)?.split(",") ?? [];
            if (location.length < 2) continue;
            final gcjLng = double.tryParse(location[0]) ?? 0.0;
            final gcjLat = double.tryParse(location[1]) ?? 0.0;
            if (gcjLat == 0.0 && gcjLng == 0.0) continue;
            final wgs = _gcjToWgs(gcjLat, gcjLng);
            final lat = wgs.wgsLat;
            final lng = wgs.wgsLng;
            final dedupeKey = "$name|${lat.toStringAsFixed(3)}";
            if (seen.any((s) => s.contains(dedupeKey))) continue;
            seen.add(dedupeKey);
            final address = [p["pname"], p["cityname"], p["adname"], p["address"]]
                .where((e) => e != null && e.toString().isNotEmpty)
                .join(" · ");
            results.add(PoiResult(
              name: name,
              address: address,
              lat: lat,
              lng: lng,
              icon: '📍',
              source: PoiSource.amap,
            ));
          }
        }
      } catch (_) {}
    }

    // 3) Photon（komoot 公共实例，去掉 lang=zh 即可返回本地语言=中文名）
    try {
      final r = await _dio.get(
        "https://photon.komoot.io/api",
        queryParameters: {"q": query, "limit": 8},
        options: Options(
          headers: {"User-Agent": _ua},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      for (final f in (r.data["features"] as List?) ?? []) {
        final g = f["geometry"]?["coordinates"];
        final pr = f["properties"];
        if (g == null || pr == null) continue;
        final name = pr["name"] as String? ?? "";
        if (name.isEmpty) continue;
        if (g is! List || g.length < 2 || g[0] is! num || g[1] is! num) continue;
        final lat = (g[1] as num).toDouble();
        final lng = (g[0] as num).toDouble();
        final dedupeKey = "$name|${lat.toStringAsFixed(3)}";
        if (seen.any((s) => s.contains(dedupeKey))) continue;
        seen.add(dedupeKey);
        results.add(PoiResult(
          name: name,
          address: _buildAddress(pr),
          lat: lat,
          lng: lng,
          icon: _iconFor(pr["osm_key"] as String?, pr["osm_value"] as String?),
          source: PoiSource.photon,
        ));
      }
    } catch (_) {}

    // 4) Open-Meteo Geocoding（城市/行政区级兜底，results < 5 时触发）
    // 内置离线库对常见目的地名可能命中 3 条以上，若仍卡在 `<3` 会让在线
    // 城市级结果从不触发（大陆网络下 Photon 常不可达，在线来源只剩它兜底）。
    if (results.length < 5) {
      try {
        final r = await _dio.get(
          "https://geocoding-api.open-meteo.com/v1/search",
          queryParameters: {
            "name": query,
            "language": "zh",
            "count": 8,
            "format": "json",
          },
          options: Options(
            headers: {"User-Agent": _ua},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        for (final f in (r.data["results"] as List?) ?? []) {
          final name = f["name"] as String? ?? "";
          final lat = (f["latitude"] as num?)?.toDouble() ?? 0.0;
          final lng = (f["longitude"] as num?)?.toDouble() ?? 0.0;
          if (name.isEmpty || lat == 0.0 && lng == 0.0) continue;
          final dedupeKey = "$name|${lat.toStringAsFixed(3)}";
          if (seen.any((s) => s.contains(dedupeKey))) continue;
          seen.add(dedupeKey);
          final addrParts = <String>[];
          void addAddr(String? v) { if (v != null && v.isNotEmpty) addrParts.add(v); }
          addAddr(f["admin1"] as String?);
          addAddr(f["country"] as String?);
          results.add(PoiResult(
            name: name,
            address: addrParts.join(" · "),
            lat: lat,
            lng: lng,
            icon: '🏙️',
            source: PoiSource.openMeteo,
          ));
        }
      } catch (_) {}
    }

    return results.take(10).toList();
  }

  @override
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final r = await _dio.get(
        "https://photon.komoot.io/reverse",
        queryParameters: {"lat": lat, "lon": lng},
        options: Options(
          headers: {"User-Agent": _ua},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final features = (r.data["features"] as List?) ?? [];
      if (features.isEmpty) return "";
      final pr = features.first["properties"] as Map<String, dynamic>? ?? {};
      return _buildAddress(pr);
    } catch (_) {
      return "";
    }
  }
}

class _GcjWgs {
  const _GcjWgs({required this.wgsLat, required this.wgsLng});
  final double wgsLat;
  final double wgsLng;
}
