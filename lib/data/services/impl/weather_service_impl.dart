/// 天气实现：内置城市坐标→Open-Meteo→WMO映射→1h缓存。
/// 缓存存 SharedPreferences（跨 Web / 原生通用）。
///
/// V2.6 治理（§6.2）：
/// - 移除 Nominatim 兜底（大陆不可达且与 poi 层结论矛盾）；坐标缺失 → null
///   （UI 呈现 copy('svc.cityNoCoord') 空态）；
/// - TTL 收敛 6h → 1h；缓存键累积清理（上限 64 条，LRU 逐出）；
/// - 所有 GET：connectTimeout 8s / receiveTimeout 15s；幂等失败 300ms 后重试 1 次。
library;
import "dart:convert";
import "package:dio/dio.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../weather_service.dart";
import "../../seed/city_coords.dart";
import "../../seed/wmo_codes.dart";
import "../../../core/date_utils.dart";

class WeatherServiceImpl implements WeatherService {
  WeatherServiceImpl([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
            ));
  final Dio _dio;
  static const _cacheHours = 1;
  static const _cacheKey = 'weather_cache_json';
  static const _cacheMaxEntries = 64;

  /// 幂等 GET：失败 300ms 后重试 1 次。
  Future<Response<T>> _getWithRetry<T>(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      return await _dio.get(path,
          queryParameters: queryParameters, options: options);
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _dio.get(path,
          queryParameters: queryParameters, options: options);
    }
  }

  @override
  Future<List<WeatherDay>?> daily(WeatherQuery q) async {
    double? lat = q.anchorLat, lng = q.anchorLng;
    if (lat == null || lng == null) {
      final c = matchCity(q.destination);
      if (c != null) { lat = c[0]; lng = c[1]; }
    }
    // 大陆网络下无在线坐标兜底（Nominatim 已移除）：城市无坐标 → 可读空态由 UI 呈现
    if (lat == null || lng == null) return null;
    final cacheKey = "${q.tripId??""}_${(lat*1000).toInt()}_${(lng*1000).toInt()}";
    final cached = await _readCache(cacheKey);
    if (cached != null) return cached;
    final today = todayEpochDay();
    final sd = q.startEpochDay < today ? today : q.startEpochDay;
    final ed = q.endEpochDay > today + 16 ? today + 16 : q.endEpochDay;
    if (sd > ed) return null;
    try {
      final r = await _getWithRetry("https://api.open-meteo.com/v1/forecast",queryParameters:{
        "latitude":lat,"longitude":lng,
        "daily":"weather_code,temperature_2m_max,temperature_2m_min",
        "timezone":"auto",
        "start_date":fmtIsoDate(epochDayToDate(sd)),
        "end_date":fmtIsoDate(epochDayToDate(ed)),
      });
      final daily = r.data["daily"];
      if (daily == null) return null;
      final codes = daily["weather_code"] as List? ?? [];
      final maxs = daily["temperature_2m_max"] as List? ?? [];
      final mins = daily["temperature_2m_min"] as List? ?? [];
      final dates = daily["time"] as List? ?? [];
      final result = <WeatherDay>[];
      for (var i = 0; i < codes.length; i++) {
        final code = codes[i] as int? ?? 0;
        final w = kWmoWeatherByCode[code];
        result.add(WeatherDay(date:DateTime.parse(dates[i]),codeText:w?.text??"未知",iconEmoji:w?.icon??"🌡️",tempMax:(maxs[i] as num?)?.round()??0,tempMin:(mins[i] as num?)?.round()??0));
      }
      await _writeCache(cacheKey, result);
      return result;
    } catch (_) { return null; }
  }

  Future<List<WeatherDay>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheKey);
      if (rawJson == null) return null;
      final raw = jsonDecode(rawJson) as Map;
      final e = raw[key];
      if (e == null) return null;
      final ts = DateTime.parse(e["ts"]);
      if (DateTime.now().difference(ts).inHours >= _cacheHours) return null;
      return (e["days"] as List).map((d)=>WeatherDay(date:DateTime.parse(d["date"]),codeText:d["codeText"],iconEmoji:d["iconEmoji"],tempMax:d["tempMax"],tempMin:d["tempMin"])).toList();
    } catch (_) { return null; }
  }

  Future<void> _writeCache(String key, List<WeatherDay> days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheKey);
      final raw = Map<String,dynamic>.from(rawJson == null ? <String,dynamic>{} : jsonDecode(rawJson) as Map);
      raw[key] = {"ts":DateTime.now().toIso8601String(),"days":[for(final d in days){"date":d.date.toIso8601String(),"codeText":d.codeText,"iconEmoji":d.iconEmoji,"tempMax":d.tempMax,"tempMin":d.tempMin}]};
      // 缓存键累积治理：超上限按时间戳 LRU 逐出最旧条目
      if (raw.length > _cacheMaxEntries) {
        final entries = raw.entries.toList()
          ..sort((a, b) => (a.value["ts"] as String? ?? '')
              .compareTo(b.value["ts"] as String? ?? ''));
        for (final e in entries.take(raw.length - _cacheMaxEntries)) {
          raw.remove(e.key);
        }
      }
      await prefs.setString(_cacheKey, jsonEncode(raw));
    } catch (_) {}
  }
}
