/// 行程数据备份：导出结构 + 导入 id 重映射引擎（单行程范畴）。
///
/// 【纯 Dart 无 IO】仓储层负责把行对象组装成本文件的 Map 结构并落盘/读取；
/// 核心重映射逻辑在此单测覆盖。
///
/// 备份根结构：
/// ```json
/// {"app":"travel-assistant-v2-trip","version":1,
///  "trip":{...},"items":[...],"photos":[...],"checklist":[...]}
/// ```
///
/// 【重映射】行程/安排/照片/清单一律换发新 id，导入即全新副本；
/// tripId 统一指向新行程 id，groupId 置空（行程备份独立、不挂原团）。
library;

import 'dart:convert';

import '../core/uid.dart';

/// 行程备份文件应用标识
const String kTripBackupApp = 'travel-assistant-v2-trip';

/// 当前行程备份格式版本
const int kTripBackupVersion = 1;

/// id 换发器签名（测试注入确定性实现）
typedef IdGen = String Function(String prefix);

String _defaultGen(String prefix) => newId(prefix);

Map<String, dynamic> _copy(Map<String, dynamic> m) => Map<String, dynamic>.of(m);

List<Map<String, dynamic>> _asMapList(Object? v) => [
      for (final e in (v as List<dynamic>? ?? <dynamic>[]))
        if (e is Map) (e as Map).cast<String, dynamic>(),
    ];

/// 组装备份根结构（不修改任何入参）。
Map<String, dynamic> buildTripBackup({
  required Map<String, dynamic> trip,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> photos,
  required List<Map<String, dynamic>> checklist,
}) =>
    <String, dynamic>{
      'app': kTripBackupApp,
      'version': kTripBackupVersion,
      'trip': _copy(trip),
      'items': [for (final it in items) _copy(it)],
      'photos': [for (final p in photos) _copy(p)],
      'checklist': [for (final c in checklist) _copy(c)],
    };

/// 备份 → JSON 文本
String encodeTripBackup(Map<String, dynamic> backup) => jsonEncode(backup);

/// 解析后的行程备份视图
class TripBackup {
  const TripBackup({
    required this.version,
    required this.trip,
    required this.items,
    required this.photos,
    required this.checklist,
  });

  final int version;
  final Map<String, dynamic> trip;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> photos;
  final List<Map<String, dynamic>> checklist;
}

/// 解析并校验备份文本；非法输入抛 [FormatException]。
TripBackup parseTripBackup(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw FormatException('行程备份内容不是合法 JSON');
  }
  if (decoded is! Map) throw FormatException('行程备份根节点必须是对象');
  return parseTripBackupMap(decoded.cast<String, dynamic>());
}

/// 解析并校验已解码的备份根节点（二进制信封解码后直接走这里）。
TripBackup parseTripBackupMap(Map<String, dynamic> root) {
  if (root['app'] != kTripBackupApp) {
    throw FormatException('不是「芥舟」的行程备份文件');
  }
  final version = root['version'];
  if (version is! int || version <= 0 || version > kTripBackupVersion) {
    throw FormatException('不支持的行程备份版本: $version');
  }
  final tRaw = root['trip'];
  if (tRaw is! Map) throw FormatException('缺少 trip 节点');
  return TripBackup(
    version: version,
    trip: tRaw.cast<String, dynamic>(),
    items: _asMapList(root['items']),
    photos: _asMapList(root['photos']),
    checklist: _asMapList(root['checklist']),
  );
}

/// 导入过程统计（UI 的 SnackBar 报告用）
class TripImportStats {
  const TripImportStats({
    required this.items,
    required this.photos,
    required this.checklist,
  });
  final int items;
  final int photos;
  final int checklist;

  @override
  String toString() =>
      '安排$items · 照片$photos · 清单$checklist';
}

/// 导入产物：全部实体已换发新 id 且内部自洽，可直接批量入库。
class TripImportResult {
  const TripImportResult({
    required this.trip,
    required this.items,
    required this.photos,
    required this.checklist,
    required this.stats,
  });

  final Map<String, dynamic> trip;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> photos;
  final List<Map<String, dynamic>> checklist;
  final TripImportStats stats;
}

/// 行程导入报告（UI 摘要用）
class TripImportReport {
  const TripImportReport({
    required this.trip,
    required this.items,
    required this.photos,
    required this.checklist,
  });
  final String trip;
  final int items;
  final int photos;
  final int checklist;
}

/// 执行导入重映射：行程/安排/照片/清单统一换发新 id，tripId 指向新行程。
TripImportResult applyTripImport(
  TripBackup backup, {
  IdGen? gen,
}) {
  final g = gen ?? _defaultGen;
  final newTripId = g('trip');

  final itemMap = <String, String>{};
  final newItems = <Map<String, dynamic>>[];
  for (final it in backup.items) {
    final nid = g('item');
    final old = it['id'];
    if (old is String) itemMap[old] = nid;
    newItems.add(<String, dynamic>{..._copy(it), 'id': nid, 'tripId': newTripId});
  }

  final newPhotos = <Map<String, dynamic>>[];
  for (final p in backup.photos) {
    final nid = g('photo');
    newPhotos.add(<String, dynamic>{..._copy(p), 'id': nid, 'tripId': newTripId});
  }

  final newChecklist = <Map<String, dynamic>>[];
  for (final c in backup.checklist) {
    final nid = g('chk');
    newChecklist.add(<String, dynamic>{
      ..._copy(c),
      'id': nid,
      'tripId': newTripId,
      'scope': 'trip',
    });
  }

  final newTrip = <String, dynamic>{
    ..._copy(backup.trip),
    'id': newTripId,
    'groupId': null,
  };

  return TripImportResult(
    trip: newTrip,
    items: newItems,
    photos: newPhotos,
    checklist: newChecklist,
    stats: TripImportStats(
      items: newItems.length,
      photos: newPhotos.length,
      checklist: newChecklist.length,
    ),
  );
}
