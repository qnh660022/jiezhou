/// 航班识别实现：缓存→内置航线→adsbdb（在线补充）。
///
/// V2.6 治理（§6.2）：adsbdb 是 ADS-B 实时状态源，中国内地航班几乎必然无结果，
/// 保留为在线补充；TTL 收敛 30 天 → 7 天（来源标注由 FlightInfo.source 承载）；
/// 超时 8s/15s；无结果返回 null（UI 呈现「航班信息暂未收录，可手动填写」空态）。
library;
import "dart:convert";
import "package:dio/dio.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../flight_service.dart";
import "../../seed/airlines.dart";
import "../../seed/airports.dart";
import "../../seed/common_routes.dart";

class FlightServiceImpl implements FlightService {
  FlightServiceImpl([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
            ));
  final Dio _dio;
  static const _cacheKey = "flight_cache_v1";
  static const _ttl = 7 * 24 * 3600 * 1000; // 7 天（V2.6 收敛，原 30 天）
  static const _cacheMaxEntries = 96;
  final _iataRe = RegExp(r"^[A-Z0-9]{2}\d{1,4}$");
  final _icaoRe = RegExp(r"^[A-Z][A-Z0-9]{2}\d{1,4}$");

  @override
  Future<FlightInfo?> lookup(String flightNo) async {
    final fn = flightNo.replaceAll(RegExp(r"\s|-"), "").toUpperCase();
    if (fn.isEmpty) return null;
    final cached = await _fromCache(fn);
    if (cached != null) return cached;
    final rt = findCommonRoute(fn);
    if (rt != null) {
      final from = findAirport(rt.from), to = findAirport(rt.to);
      final info = FlightInfo(flightNo:fn,airlineName:_airlineName(fn),fromAirport:from?.name??"",toAirport:to?.name??"",source:FlightSource.builtin,cachedAt:DateTime.now());
      await _toCache(fn, info);
      return info;
    }
    final callsign = _toCallsign(fn);
    if (callsign != null) {
      try {
        final r = await _dio
            .get("https://api.adsbdb.com/v0/callsign/$callsign");
        final d = r.data["response"]?["aircraft"] ?? r.data["response"];
        if (d != null) {
          final from = d["origin"]?["iata"] ?? "", to = d["destination"]?["iata"] ?? "";
          final info = FlightInfo(flightNo:fn,airlineName:d["airline"]?["name"]??"",fromAirport:from,toAirport:to,source:FlightSource.online,cachedAt:DateTime.now());
          await _toCache(fn, info);
          return info;
        }
      } catch (_) {}
    }
    return null;
  }

  String _airlineName(String fn) {
    final code = fn.replaceAll(RegExp(r"\d+"), "");
    final a = findAirlineByIata(code) ?? findAirlineByIcao(code);
    return a?.name ?? "";
  }
  String? _toCallsign(String fn) {
    if (_icaoRe.hasMatch(fn)) return fn;
    final code = fn.replaceAll(RegExp(r"\d+"), "");
    final a = findAirlineByIata(code);
    if (a == null) return null;
    final num = fn.replaceAll(RegExp(r"[^0-9]"), "");
    return "${a.icao}$num";
  }
  Future<FlightInfo?> _fromCache(String fn) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_cacheKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map;
      final e = map[fn];
      if (e == null) return null;
      final at = DateTime.tryParse(e["cachedAt"]??"") ?? DateTime(2000);
      if (DateTime.now().difference(at).inMilliseconds > _ttl) return null;
      return FlightInfo(flightNo:fn,airlineName:e["airlineName"]??"",fromAirport:e["fromAirport"]??"",toAirport:e["toAirport"]??"",source:FlightSource.cache,cachedAt:at);
    } catch (_) { return null; }
  }
  Future<void> _toCache(String fn, FlightInfo info) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_cacheKey);
      final map = raw != null ? (jsonDecode(raw) as Map) : <String,dynamic>{};
      map[fn] = {"airlineName":info.airlineName,"fromAirport":info.fromAirport,"toAirport":info.toAirport,"cachedAt":info.cachedAt.toIso8601String()};
      // 键累积治理：超上限按时间 LRU 逐出最旧条目
      if (map.length > _cacheMaxEntries) {
        final entries = map.entries.toList()
          ..sort((a, b) => ((a.value["cachedAt"] as String?) ?? '')
              .compareTo((b.value["cachedAt"] as String?) ?? ''));
        for (final e in entries.take(map.length - _cacheMaxEntries)) {
          map.remove(e.key);
        }
      }
      await sp.setString(_cacheKey, jsonEncode(map));
    } catch (_) {}
  }
}
