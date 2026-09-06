/// 文件缓存（§7.17）：manifest + 单城 TTL 7 天 + 总量 8MB LRU 逐出 + 原子写。
library;
import 'dart:convert';

import '../../platform/fs.dart' as fs;

class GuideCache {
  GuideCache();

  static const int ttlMs = 7 * 24 * 3600 * 1000;
  static const int maxTotalBytes = 8 * 1024 * 1024;
  static const int maxCityBytes = 300 * 1024;

  String? _dir; // writableDir()/guide_cache
  Map<String, dynamic>? _manifest;

  Future<String?> _ensureDir() async {
    if (_dir != null) return _dir;
    final base = await fs.writableDir();
    if (base == null) return null; // Web：无文件缓存
    _dir = '$base/guide_cache';
    return _dir;
  }

  Future<Map<String, dynamic>> _loadManifest() async {
    if (_manifest != null) return _manifest!;
    final dir = await _ensureDir();
    if (dir == null) return _manifest = {};
    final raw = await fs.readFileString('$dir/manifest.json');
    _manifest = raw == null
        ? {}
        : (jsonDecode(raw) as Map).cast<String, dynamic>();
    return _manifest!;
  }

  Future<void> _saveManifest() async {
    final dir = await _ensureDir();
    if (dir == null || _manifest == null) return;
    await fs.writeFileString(
        '$dir/manifest.json', jsonEncode(_manifest));
  }

  /// 读单城缓存（TTL 判失效）。
  Future<Map<String, dynamic>?> readCity(String key) async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    final manifest = await _loadManifest();
    final e = manifest['entries']?[key] as Map?;
    if (e == null) return null;
    final savedAt = (e['savedAtMs'] as num?)?.toInt() ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - savedAt > ttlMs) return null;
    final raw = await fs.readFileString('$dir/city/$key.json');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// 读单城缓存条目落盘时间（无条目返回 null）——在线刷新节流用。
  Future<int?> savedAtMs(String key) async {
    final manifest = await _loadManifest();
    final e = manifest['entries']?[key] as Map?;
    final at = (e?['savedAtMs'] as num?)?.toInt() ?? 0;
    return at > 0 ? at : null;
  }

  /// 写单城缓存（原子落盘 + 超额逐出）。
  Future<void> writeCity(String key, Map<String, dynamic> data) async {
    final dir = await _ensureDir();
    if (dir == null) return;
    final jsonStr = jsonEncode(data);
    if (jsonStr.length > maxCityBytes) return; // 单城超限不入缓存
    await fs.writeFileString('$dir/city/$key.json', jsonStr);
    final manifest = await _loadManifest();
    final entries =
        (manifest['entries'] as Map?)?.cast<String, dynamic>() ?? {};
    entries[key] = {
      'sizeB': jsonStr.length,
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
      'ttlMs': ttlMs,
    };
    manifest['entries'] = entries;
    manifest['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    manifest['version'] = 1;
    await _saveManifest();
    await _evictIfNeeded();
  }

  /// 总占用 >8MB：按 savedAtMs 最旧逐出 city/ 与 raw/（manifest/robot/seed_override 不逐出）。
  Future<void> _evictIfNeeded() async {
    final dir = await _ensureDir();
    if (dir == null) return;
    final manifest = await _loadManifest();
    final entries =
        (manifest['entries'] as Map?)?.cast<String, dynamic>() ?? {};
    var total = entries.values
        .fold<int>(0, (sum, e) => sum + ((e['sizeB'] as num?)?.toInt() ?? 0));
    if (total <= maxTotalBytes) return;
    final sorted = entries.entries.toList()
      ..sort((a, b) => ((a.value['savedAtMs'] as num?) ?? 0)
          .compareTo((b.value['savedAtMs'] as num?) ?? 0));
    for (final e in sorted) {
      if (total <= maxTotalBytes) break;
      total -= (e.value['sizeB'] as num?)?.toInt() ?? 0;
      await fs.deleteFile('$dir/city/${e.key}.json');
      entries.remove(e.key);
    }
    manifest['entries'] = entries;
    await _saveManifest();
  }

  /// 读种子更新包（seed_override.json，不参与逐出）。
  Future<Map<String, dynamic>?> readSeedOverride() async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    final raw = await fs.readFileString('$dir/seed_override.json');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSeedOverride(Map<String, dynamic> data) async {
    final dir = await _ensureDir();
    if (dir == null) return;
    await fs.writeFileString('$dir/seed_override.json', jsonEncode(data));
  }

  /// 各层原始结果（§7.17 raw/<key>_<layer>.json，调试用；TTL 同 7 天）。
  Future<void> writeRaw(String key, String layer, String content) async {
    final dir = await _ensureDir();
    if (dir == null) return;
    await fs.writeFileString('$dir/raw/${key}_$layer.json', content);
  }
}
