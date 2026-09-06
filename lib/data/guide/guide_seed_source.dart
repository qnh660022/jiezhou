/// 离线种子层（§7.5）：assets 内置 guide_seed_v1.json + 官网更新包优先（§7.18）。
library;
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'guide_cache.dart';
import 'guide_models.dart';

class GuideSeedSource {
  GuideSeedSource(this._cache);

  final GuideCache _cache;

  static const seedAsset = 'assets/data/guide_seed_v1.json';

  /// 官网增量包地址（§7.18：URL 与版本号放常量，本轮官网不部署，404 静默降级）。
  ///
  /// 【后端更新接口·预留】后端服务暂不开发，此处仅约定契约：
  /// - 内置种子 version 为 `v2`，与 [updateUrl] 包名 `guide_seed_v2.json` 对齐；
  /// - 后端将来只需在官网部署同构 JSON（`version` 非空 + `cities` 数组，
  ///   每城过 GuideCity.validate）即完成「发版」；
  /// - 客户端 tryUpdateFromOfficial 自动拉取 → 整包校验 → 落盘覆盖内置种子，
  ///   任一城校验失败整包丢弃，24h 冷却，任何失败静默降级用内置——均无需改客户端。
  static const updateUrl =
      'https://jiezhou.22006.dpdns.org/guide/guide_seed_v2.json';

  Map<String, Map<String, dynamic>>? _seedIndex;
  Map<String, Map<String, dynamic>>? _overrideIndex;

  Future<Map<String, Map<String, dynamic>>> _loadSeedIndex() async {
    if (_seedIndex != null) return _seedIndex!;
    try {
      final raw = await rootBundle.loadString(seedAsset);
      final data = jsonDecode(raw) as Map;
      final cities = (data['cities'] as List?) ?? const [];
      final idx = <String, Map<String, dynamic>>{};
      for (final c in cities) {
        final m = (c as Map).cast<String, dynamic>();
        if (GuideCity.validate(m) == null) idx[m['key'] as String] = m;
      }
      _seedIndex = idx;
    } catch (_) {
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

  /// 取某城种子（override > builtin）；无则 null。
  Future<Map<String, dynamic>?> getSeed(String key) async {
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
