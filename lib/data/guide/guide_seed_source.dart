/// 离线种子层（§7.5）：assets 内置 guide_seed_v1.json + 官网更新包 + AI 导入单城覆盖。
///
/// ## 数据源优先级（高 → 低）
/// 1. `city_override/<key>.json` —— **App 内 AI 生成并导入的内容**（用户自己的内容，
///    优先于一切；可在攻略页菜单里删除，删除即回落）；
/// 2. `seed_override.json` —— 官网整包更新（§7.18，本轮官网未部署）；
/// 3. `assets/data/guide_seed_v1.json` —— 内置精品种子（随发版升级）。
///
/// 每一层都过 [GuideCity.validate]；不合格的一律丢弃并继续往下找，
/// 保证「任何一层坏掉都不会让攻略页空白」。
library;
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'guide_cache.dart';
import 'guide_models.dart';

class GuideSeedSource {
  GuideSeedSource(this._cache);

  final GuideCache _cache;

  static const seedAsset = 'assets/data/guide_seed_v1.json';

  /// 官网增量包地址（§7.18）。整包替换，24h 冷却，任何失败静默降级用内置。
  ///
  /// 【后端更新接口·预留】后端服务暂不开发，此处仅约定契约：
  /// - 内置种子 version 非空 + `cities` 数组，每城过 [GuideCity.validate] 即完成「发版」；
  /// - 客户端 `tryUpdateFromOfficial` 自动拉取 → 整包校验 → 落盘覆盖内置种子，
  ///   任一城校验失败整包丢弃——均无需改客户端。
  static const updateUrl =
      'https://jiezhou.22006.dpdns.org/guide/guide_seed_v2.json';

  Map<String, Map<String, dynamic>>? _seedIndex;
  Map<String, Map<String, dynamic>>? _overrideIndex;
  Map<String, Map<String, dynamic>>? _cityOverrideIndex;

  Future<Map<String, Map<String, dynamic>>> _loadSeedIndex() async {
    if (_seedIndex != null) return _seedIndex!;
    try {
      final raw = await rootBundle.loadString(seedAsset);
      final data = jsonDecode(raw) as Map;
      _seedIndex = _indexFrom((data).cast<String, dynamic>());
    } catch (e) {
      debugPrint('[guide] 内置种子加载失败：$e');
      _seedIndex = {};
    }
    return _seedIndex!;
  }

  /// 覆盖包（校验通过时）优先于内置种子。
  Future<Map<String, Map<String, dynamic>>> _loadOverrideIndex() async {
    if (_overrideIndex != null) return _overrideIndex!;
    final data = await _cache.readSeedOverride();
    _overrideIndex = _indexFrom(data);
    return _overrideIndex!;
  }

  /// AI 导入的单城覆盖包索引。
  ///
  /// 不走目录遍历：`guide_seed_source` 只按 key 查，所以按需读单文件即可。
  /// 这里保留一个进程内缓存，避免同一城反复读盘。
  final Map<String, Map<String, dynamic>?> _cityOverrideCache = {};

  Future<Map<String, dynamic>?> _cityOverride(String key) async {
    if (_cityOverrideCache.containsKey(key)) return _cityOverrideCache[key];
    final data = await _cache.readCityOverride(key);
    if (data != null && GuideCity.validate(data) != null) {
      debugPrint('[guide] $key 的 AI 导入内容结构非法，已忽略');
      _cityOverrideCache[key] = null;
      return null;
    }
    _cityOverrideCache[key] = data;
    return data;
  }

  /// 写入/刷新 AI 导入内容后调用，让进程内缓存失效。
  void invalidateCityOverride(String key) => _cityOverrideCache.remove(key);

  Map<String, Map<String, dynamic>> _indexFrom(Map<String, dynamic>? data) {
    if (data == null) return {};
    final cities = (data['cities'] as List?) ?? const [];
    final idx = <String, Map<String, dynamic>>{};
    for (final c in cities) {
      final m = (c as Map).cast<String, dynamic>();
      if (GuideCity.validate(m) == null) idx[m['key'] as String] = m;
    }
    return idx;
  }

  /// 取某城种子，按「AI 导入 > 官网整包 > 内置」优先级返回；全无则 null。
  Future<Map<String, dynamic>?> getSeed(String key) async {
    final ai = await _cityOverride(key);
    if (ai != null) return ai;
    final ov = await _loadOverrideIndex();
    if (ov.containsKey(key)) return ov[key];
    final seed = await _loadSeedIndex();
    return seed[key];
  }

  Future<Map<String, String>> cityNameIndex() async {
    final seed = await _loadSeedIndex();
    final ov = await _loadOverrideIndex();
    final out = <String, String>{};
    seed.forEach((k, v) => out[k] = v['name'] as String? ?? '');
    ov.forEach((k, v) => out[k] = v['name'] as String? ?? '');
    return out;
  }

  /// key → 大区（攻略页「换城市」选择器分组用）。缺失返回空串。
  Future<Map<String, String>> cityAreaIndex() async {
    final seed = await _loadSeedIndex();
    final ov = await _loadOverrideIndex();
    final out = <String, String>{};
    seed.forEach((k, v) => out[k] = (v['area'] as String?) ?? '');
    ov.forEach((k, v) => out[k] = (v['area'] as String?) ?? '');
    return out;
  }

  /// 全部内置城市（按种子顺序，供「精品城市」选择器直接列）。
  Future<List<({String key, String name, String area})>> allCities() async {
    final seed = await _loadSeedIndex();
    final ov = await _loadOverrideIndex();
    final merged = <String, Map<String, dynamic>>{...seed, ...ov};
    return [
      for (final e in merged.entries)
        (
          key: e.key,
          name: e.value['name'] as String? ?? e.key,
          area: e.value['area'] as String? ?? '',
        ),
    ];
  }

  /// 静默尝试拉官网更新包（§7.18）：校验通过才落盘；任何失败静默用内置。
  /// Web 端无文件缓存，跳过。返回 true=落盘成功。
  Future<bool> tryUpdateFromOfficial({
    required Future<String?> Function(String url) fetchText,
    DateTime? lastCheck,
  }) async {
    if (kIsWeb) return false;
    // 冷却 24h（prefs 层由 service 控制，这里再兜一层）
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < const Duration(hours: 24)) {
      return false;
    }
    try {
      final text = await fetchText(updateUrl);
      if (text == null || text.isEmpty) return false;
      final data = (jsonDecode(text) as Map).cast<String, dynamic>();
      if ((data['version'] as String?)?.isEmpty ?? true) return false;
      final cities = data['cities'];
      if (cities is! List || cities.isEmpty) return false;
      for (final c in cities) {
        final err = GuideCity.validate((c as Map).cast<String, dynamic>());
        if (err != null) return false; // 任一城校验失败 → 整包丢弃
      }
      await _cache.writeSeedOverride(data);
      _overrideIndex = null; // 失效索引，下次重载
      return true;
    } catch (_) {
      return false; // 404/网络/损坏包：静默用内置（明确验收用例）
    }
  }
}
