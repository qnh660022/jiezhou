/// 开源数据增强层（§7.2-②）：公开无版权争议源补充事实/坐标。
/// 2026-09-06 真实现（用户要求「离线+在线结合做实」）：
/// - Open-Meteo：城市坐标拉 3 日天气 → 「行前准备」天气事实条目（大陆直连实测可用）；
/// - Photon（OSM 生态）：城市名+类别查真实景点 POI → 「景点」补充条目
///   （实测 q=城市名&osm_tag=tourism 返回真实景点；美食查询噪音大不采用）。
/// 所有条目带 source/sourceUrl 标注；种子文本优先，在线只补不改写（§7.16）。
library;
import 'dart:convert';

import 'guide_http.dart';
import 'guide_normalize.dart';
import '../seed/city_coords.dart' show kCityCoords;

class GuideOpenSourceLayer {
  GuideOpenSourceLayer({GuideHttp? http, this.fetchOverride})
      : _http = http ?? GuideHttp.instance;

  final GuideHttp _http;

  /// 测试注入：给定 url 直接返回结果（绕过真实网络）。
  final GuideFetchResult Function(String url)? fetchOverride;

  Future<GuideFetchResult> _fetch(String url) => fetchOverride != null
      ? Future.value(fetchOverride!(url))
      : _http.fetchText(url, checkRobots: false);

  /// 每栏最多补充条数（轻量、克制）。
  static const _maxSpots = 4;

  /// 返回 null = 该层无数据（静默降级到下一层）。任何失败都不得抛出。
  Future<Map<String, List<Map<String, dynamic>>>?> enhance(
      GuideLocation loc) async {
    final out = <String, List<Map<String, dynamic>>>{};
    try {
      final weather = await _weather(loc);
      final spots = await _spots(loc);
      if (weather != null) out['prep'] = [weather];
      if (spots.isNotEmpty) out['spots'] = spots;
    } catch (_) {
      return null;
    }
    return out.isEmpty ? null : out;
  }
  // ============ Open-Meteo 天气事实（prep 栏） ============

  Future<Map<String, dynamic>?> _weather(GuideLocation loc) async {
    final coords = kCityCoords[loc.name] ?? kCityCoords[loc.key];
    if (coords == null) return null;
    final url = 'https://api.open-meteo.com/v1/forecast'
        '?latitude=${coords[0]}&longitude=${coords[1]}'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max'
        '&timezone=Asia%2FShanghai&forecast_days=3';
    final res = await _fetch(url);
    if (res.cls != GuideFetchClass.ok) return null;
    try {
      final data = jsonDecode(res.body) as Map;
      final daily = data['daily'];
      if (daily is! Map) return null;
      final days = (daily['time'] as List?) ?? const [];
      final maxT = (daily['temperature_2m_max'] as List?) ?? const [];
      final minT = (daily['temperature_2m_min'] as List?) ?? const [];
      final rain = (daily['precipitation_probability_max'] as List?) ?? const [];
      if (days.isEmpty || maxT.isEmpty) return null;
      final parts = <String>[];
      for (var i = 0; i < days.length && i < 3; i++) {
        final dt = DateTime.tryParse(days[i].toString());
        if (dt == null) continue;
        final rainText = i < rain.length ? '，降水概率${rain[i]}%' : '';
        parts.add('${dt.month}月${dt.day}日 '
            '${(minT[i] as num).round()}~${(maxT[i] as num).round()}℃$rainText');
      }
      if (parts.isEmpty) return null;
      return {
        'title': '未来3天天气（网络）',
        'detail': parts.join('；'),
        'source': 'Open-Meteo',
        'sourceUrl': 'https://open-meteo.com/',
      };
    } catch (_) {
      return null;
    }
  }

  // ============ Photon / OSM 景点 POI（spots 栏） ============

  Future<List<Map<String, dynamic>>> _spots(GuideLocation loc) async {
    final q = Uri.encodeComponent(loc.name);
    final coords = kCityCoords[loc.name] ?? kCityCoords[loc.key];
    final bias = coords != null ? '&lat=${coords[0]}&lon=${coords[1]}' : '';
    final url = 'https://photon.komoot.io/api/?q=$q'
        '&osm_tag=tourism&osm_tag=historic&limit=8$bias';
    final res = await _fetch(url);
    if (res.cls != GuideFetchClass.ok) return const [];
    try {
      final data = jsonDecode(res.body) as Map;
      final features = (data['features'] as List?) ?? const [];
      final out = <Map<String, dynamic>>[];
      for (final f in features) {
        if (out.length >= _maxSpots) break;
        final p = (f['properties'] as Map?) ?? const {};
        final name = p['name']?.toString() ?? '';
        if (name.isEmpty ||
            name == loc.name ||
            name.contains(loc.name) && name.length <= loc.name.length + 1) {
          continue; // 地名自身/泛化命中不是景点
        }
        final osmType = p['osm_type']?.toString() ?? '';
        final osmId = p['osm_id']?.toString() ?? '';
        final city = p['city']?.toString() ?? '';
        final district = p['district']?.toString() ?? '';
        out.add({
          'name': name,
          'addr': [district, city].where((s) => s.isNotEmpty).join(' '),
          'tag': 'OSM·${p['osm_value'] ?? ''}',
          'timeText': '',
          'note': '来自网络补充（OpenStreetMap）',
          'source': 'OpenStreetMap',
          if (osmType.isNotEmpty && osmId.isNotEmpty)
            'sourceUrl': 'https://www.openstreetmap.org/$osmType/$osmId',
        });
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
