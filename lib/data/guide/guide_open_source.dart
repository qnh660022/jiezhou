/// 开源数据增强层（§7.2-②）：公开无版权争议源补充**事实**。
///
/// ## 2026-09 修正（用户原话：「获取的只是地点，不是攻略，而且全是外国的」）
/// 旧实现把 Photon/OSM 的 POI 当成「景点推荐」主体，导致：
/// - 海外城市（`kCityCoords` 里东京/巴黎/伦敦等占一半）也能出内容 → 全是外国的；
/// - 条目只有 `OSM·museum` 之类的外文地名，没有任何攻略信息 → 只是地点。
///
/// 现在的定位收窄为「**只补事实，不做攻略主体**」：
/// - Open-Meteo 天气 → `prep`（真实、时效性、无版权争议）；
/// - Photon/OSM POI → `spots` 微弱补充，且必须同时满足
///   ① `countrycode == CN`；② 名称含中文（[hasCjk]）。
/// 主体攻略内容由内置种子（5000 字/城）+ 去哪儿城市页抓取层承担。
library;
import 'dart:convert';

import 'guide_content_filter.dart';
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

  /// 每栏最多补充条数（轻量、克制；主体内容不靠这一层）。
  static const _maxSpots = 3;

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

  // ============ Photon / OSM 景点 POI（spots 栏，弱补充） ============

  /// 只接受**国内 + 中文名**的 POI；外文/海外一律丢弃（用户明确要求去掉外国内容）。
  Future<List<Map<String, dynamic>>> _spots(GuideLocation loc) async {
    final q = Uri.encodeComponent(loc.name);
    final coords = kCityCoords[loc.name] ?? kCityCoords[loc.key];
    final bias = coords != null ? '&lat=${coords[0]}&lon=${coords[1]}' : '';
    final url = 'https://photon.komoot.io/api/?q=$q'
        '&osm_tag=tourism&osm_tag=historic&limit=12$bias';
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
        if (name.isEmpty) continue;
        if (!hasCjk(name, min: 2)) continue; // 外文地名：丢弃
        final country = (p['countrycode'] ?? p['country'] ?? '').toString();
        if (!_isChina(country)) continue; // 海外 POI：丢弃
        if (name == loc.name ||
            (name.contains(loc.name) && name.length <= loc.name.length + 1)) {
          continue; // 地名自身/泛化命中不是景点
        }
        final osmType = p['osm_type']?.toString() ?? '';
        final osmId = p['osm_id']?.toString() ?? '';
        final city = p['city']?.toString() ?? '';
        final district = p['district']?.toString() ?? '';
        out.add({
          'name': name,
          'addr': [district, city].where((s) => s.isNotEmpty).join(' '),
          'tag': '网络补充',
          'timeText': '',
          'note': '来自 OpenStreetMap 的地点标注（仅坐标与名称，攻略详情见上方栏目）',
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

  /// 国内判定：ISO 国家码 CN，或国家级字段里含「中国」/China。
  bool _isChina(String country) {
    final c = country.trim().toLowerCase();
    if (c.isEmpty) return false;
    return c == 'cn' || c == 'chn' || c.contains('中国') || c.contains('china');
  }
}
