/// 通行时长实现：haversine估算 → 配key时真实路线 → 失败回退。
/// 首次调用时从 prefs 读取 mapConfig（provider + key），缓存后复用；provider=none/无key 时走估算。
library;
import "dart:math";
import "package:dio/dio.dart";
import "../travel_time_service.dart";
import "../../repo/prefs_repo.dart";

class TravelTimeServiceImpl implements TravelTimeService {
  TravelTimeServiceImpl({Dio? dio, PrefsRepository? prefsRepo})
      : _dio = dio ?? Dio(),
        _prefsRepo = prefsRepo;
  final Dio _dio;
  final PrefsRepository? _prefsRepo;

  String? _qqKey;
  String? _amapKey;
  String _provider = 'none';
  bool _configLoaded = false;

  /// 懒加载 mapConfig（仅首次调用时读一次 SP，后续复用）
  Future<void> _ensureConfigLoaded() async {
    if (_configLoaded || _prefsRepo == null) return;
    try {
      final cfg = await _prefsRepo!.getMapConfig();
      _provider = (cfg['provider'] as String?) ?? 'none';
      final key = (cfg['key'] as String?)?.trim() ?? '';
      if (_provider == 'qq') {
        _qqKey = key.isEmpty ? null : key;
      } else if (_provider == 'amap') {
        _amapKey = key.isEmpty ? null : key;
      }
    } catch (_) {
      // 读取失败保持默认 none
    } finally {
      _configLoaded = true;
    }
  }

  @override
  Future<TravelEstimate> minutesBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2, {
    TravelMode mode = TravelMode.walk,
  }) async {
    await _ensureConfigLoaded();

    final km = _haversine(lat1, lng1, lat2, lng2);
    final speed = mode == TravelMode.walk
        ? 4.0
        : mode == TravelMode.drive
            ? 26.0
            : 16.0;
    final est = max(1, (km / speed * 60).ceil());

    // 尝试真实路线（按配置顺序：qq → amap）
    if (_qqKey != null) {
      try {
        return await _qqRoute(lat1, lng1, lat2, lng2, mode);
      } catch (_) {}
    }
    if (_amapKey != null) {
      try {
        return await _amapRoute(lat1, lng1, lat2, lng2, mode);
      } catch (_) {}
    }
    return TravelEstimate(
        minutes: est, distanceKm: km, source: TravelEstimateSource.estimate);
  }

  @override
  Future<bool> pingProvider() async {
    await _ensureConfigLoaded();

    String url;
    Map<String, dynamic> params;
    switch (_provider) {
      case 'qq':
        if (_qqKey == null) return false;
        url = "https://apis.map.qq.com/ws/direction/v1/walking";
        params = {"from": "39.9,116.3", "to": "39.91,116.31", "key": _qqKey!};
        break;
      case 'amap':
        if (_amapKey == null) return false;
        url = "https://restapi.amap.com/v3/direction/walking";
        params = {"origin": "116.3,39.9", "destination": "116.31,39.91", "key": _amapKey!};
        break;
      default:
        // none/未配置：探活 Photon（同 POI 搜索用的同一实例，已验证国内可达）
        url = "https://photon.komoot.io/api";
        params = {"q": "test", "limit": 1};
        break;
    }
    try {
      await _dio.get(
        url,
        queryParameters: params,
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1), dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double d) => d * pi / 180;

  Future<TravelEstimate> _qqRoute(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    TravelMode mode,
  ) async {
    final type = mode == TravelMode.walk
        ? "walking"
        : mode == TravelMode.drive
            ? "driving"
            : "transit";
    final r = await _dio.get(
      "https://apis.map.qq.com/ws/direction/v1/$type",
      queryParameters: {
        "from": "${lat1},${lng1}",
        "to": "${lat2},${lng2}",
        "key": _qqKey!,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    final dur = r.data["result"]?["routes"]?[0]?["duration"];
    if (dur == null) throw Exception("no route");
    return TravelEstimate(
      minutes: max(1, (int.parse(dur.toString()) / 60).ceil()),
      distanceKm: _haversine(lat1, lng1, lat2, lng2),
      source: TravelEstimateSource.route,
    );
  }

  Future<TravelEstimate> _amapRoute(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    TravelMode mode,
  ) async {
    final type = mode == TravelMode.walk
        ? "walking"
        : mode == TravelMode.drive
            ? "driving"
            : "transit";
    final r = await _dio.get(
      "https://restapi.amap.com/v3/direction/$type",
      queryParameters: {
        "origin": "${lng1},${lat1}",
        "destination": "${lng2},${lat2}",
        "key": _amapKey!,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    final dur = r.data["route"]?["paths"]?[0]?["duration"];
    if (dur == null) throw Exception("no route");
    return TravelEstimate(
      minutes: max(1, (int.parse(dur.toString()) / 60).ceil()),
      distanceKm: _haversine(lat1, lng1, lat2, lng2),
      source: TravelEstimateSource.route,
    );
  }
}
