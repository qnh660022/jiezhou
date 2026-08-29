/// 天气实现：三级定位→Open-Meteo→WMO映射→6h缓存。
/// 缓存存 SharedPreferences（跨 Web / 原生通用，免去文件系统依赖）。
library;
import "dart:convert";
import "package:dio/dio.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../weather_service.dart";
import "../../seed/city_coords.dart";
import "../../seed/wmo_codes.dart";
import "../../../core/date_utils.dart";

class WeatherServiceImpl implements WeatherService {
  WeatherServiceImpl([Dio? dio]) : _dio = dio ?? Dio();
  final Dio _dio;
  static const _cacheHours = 6;

  @override
  Future<List<WeatherDay>?> daily(WeatherQuery q) async {
    double? lat = q.anchorLat, lng = q.anchorLng;
    if (lat == null || lng == null) {
      final c = matchCity(q.destination);
      if (c != null) { lat = c[0]; lng = c[1]; }
    }
    if (lat == null || lng == null) {
      try {
        final r = await _dio.get("https://nominatim.openstreetmap.org/search",queryParameters:{"q":q.destination,"format":"jsonv2","limit":1},options:Options(headers:{"User-Agent":"TravelAssistant2/2.0"},sendTimeout:Duration(seconds:5),receiveTimeout:Duration(seconds:5)));
        final f = (r.data as List?)?.firstOrNull;
        if (f != null) { lat = double.tryParse(f["lat"]??""); lng = double.tryParse(f["lon"]??""); }
      } catch (_) {}
    }
    if (lat == null || lng == null) return null;
    final cacheKey = "${q.tripId??""}_${(lat*1000).toInt()}_${(lng*1000).toInt()}";
    final cached = await _readCache(cacheKey);
    if (cached != null) return cached;
    final today = todayEpochDay();
    final sd = q.startEpochDay < today ? today : q.startEpochDay;
    final ed = q.endEpochDay > today + 16 ? today + 16 : q.endEpochDay;
    if (sd > ed) return null;
    try {
      final r = await _dio.get("https://api.open-meteo.com/v1/forecast",queryParameters:{
        "latitude":lat,"longitude":lng,
        "daily":"weather_code,temperature_2m_max,temperature_2m_min",
        "timezone":"auto",
        "start_date":fmtIsoDate(epochDayToDate(sd)),
        "end_date":fmtIsoDate(epochDayToDate(ed)),
      },options:Options(sendTimeout:Duration(seconds:10),receiveTimeout:Duration(seconds:10)));
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
      final rawJson = prefs.getString('weather_cache_json');
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
      final rawJson = prefs.getString('weather_cache_json');
      final raw = Map<String,dynamic>.from(rawJson == null ? <String,dynamic>{} : jsonDecode(rawJson) as Map);
      raw[key] = {"ts":DateTime.now().toIso8601String(),"days":[for(final d in days){"date":d.date.toIso8601String(),"codeText":d.codeText,"iconEmoji":d.iconEmoji,"tempMax":d.tempMax,"tempMin":d.tempMin}]};
      await prefs.setString('weather_cache_json', jsonEncode(raw));
    } catch (_) {}
  }
}
