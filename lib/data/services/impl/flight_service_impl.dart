/// 航班识别实现：缓存→内置航线→adsbdb。
library;
import "dart:convert";
import "package:dio/dio.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../flight_service.dart";
import "../../seed/airlines.dart";
import "../../seed/airports.dart";
import "../../seed/common_routes.dart";

class FlightServiceImpl implements FlightService {
  FlightServiceImpl([Dio? dio]) : _dio = dio ?? Dio();
  final Dio _dio;
  static const _cacheKey = "flight_cache_v1";
  static const _ttl = 30 * 24 * 3600 * 1000;
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
        final r = await _dio.get("https://api.adsbdb.com/v0/callsign/$callsign",options:Options(sendTimeout:Duration(seconds:5),receiveTimeout:Duration(seconds:5)));
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
      await sp.setString(_cacheKey, jsonEncode(map));
    } catch (_) {}
  }
}
