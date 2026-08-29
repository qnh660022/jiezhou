/// 旅行团数据备份：导出结构 + 导入四级 id 重映射引擎。
///
/// 【纯 Dart 无 IO】drift 仓储层(import_export.dart)负责把行对象组装成
/// 本文件的 Map 结构并落盘/读取；核心重映射逻辑在此单测覆盖。
///
/// 备份根结构：
/// ```json
/// {"app":"travel-assistant-v2","version":1,
///  "group":{...},"members":[...],"expenses":[...],
///  "settlements":[...],"trips":[{"items":[...]}],"customCategories":[...]}
/// ```
///
/// 【四级重映射】成员 → 账单 → 行程 → 安排：
/// * 所有实体一律换发新 id，导入即全新副本；
/// * 关联字段（payers/shares/portions 的 memberId、settledRoundId、
///   tripId、tripItemId、transfers 的 from/to、expenseIds）映射失败时：
///   单值关联置 null 并计数，数组元素直接剔除并计数；
/// * 自定义分类同名复用既有 key（含导入批次内部去重），
///   内置分类 key（不在 customCategories 清单中的）原样保留。
library;

import 'dart:convert';

import '../core/uid.dart';

/// 备份文件应用标识
const String kBackupApp = 'travel-assistant-v2';

/// 当前备份格式版本
const int kBackupVersion = 1;

/// id 换发器签名（测试注入确定性实现）
typedef IdGen = String Function(String prefix);

String _defaultGen(String prefix) => newId(prefix);

Map<String, dynamic> _copy(Map<String, dynamic> m) => Map<String, dynamic>.of(m);

/// 组装备份根结构（不修改任何入参）。
///
/// [trips] 中每个行程可用 `items` 键携带安排数组（同为 Map 列表），
/// 其余字段与数据库列一一对应。
Map<String, dynamic> buildGroupBackup({
  required Map<String, dynamic> group,
  required List<Map<String, dynamic>> members,
  required List<Map<String, dynamic>> expenses,
  required List<Map<String, dynamic>> settlements,
  required List<Map<String, dynamic>> trips,
  required List<Map<String, dynamic>> customCategories,
}) =>
    <String, dynamic>{
      'app': kBackupApp,
      'version': kBackupVersion,
      'group': _copy(group),
      'members': [for (final m in members) _copy(m)],
      'expenses': [for (final e in expenses) _copy(e)],
      'settlements': [for (final s in settlements) _copy(s)],
      'trips': [
        for (final t in trips)
          <String, dynamic>{
            ..._copy(t),
            'items': [
              for (final it in (t['items'] as List<dynamic>? ?? <dynamic>[]))
                _copy((it as Map).cast<String, dynamic>()),
            ],
          },
      ],
      'customCategories': [for (final c in customCategories) _copy(c)],
    };

/// 备份 → JSON 文本
String encodeGroupBackup(Map<String, dynamic> backup) => jsonEncode(backup);

/// 解析后的备份视图
class GroupBackup {
  const GroupBackup({
    required this.version,
    required this.group,
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.trips,
    required this.customCategories,
  });

  final int version;
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> settlements;

  /// 每个行程自带 `items` 键
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> customCategories;
}

List<Map<String, dynamic>> _asMapList(Object? v) => [
      for (final e in (v as List<dynamic>? ?? <dynamic>[]))
        (e as Map).cast<String, dynamic>(),
    ];

/// 解析并校验备份文本；非法输入抛 [FormatException]。
GroupBackup parseGroupBackup(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw FormatException('备份内容不是合法 JSON');
  }
  if (decoded is! Map) throw FormatException('备份根节点必须是对象');
  return parseGroupBackupMap(decoded.cast<String, dynamic>());
}

/// 解析并校验已解码的备份根节点（二进制信封解码后直接走这里）。
GroupBackup parseGroupBackupMap(Map<String, dynamic> root) {
  if (root['app'] != kBackupApp) throw FormatException('不是「芥舟」的备份文件');
  final version = root['version'];
  if (version is! int || version <= 0 || version > kBackupVersion) {
    throw FormatException('不支持的备份版本: $version');
  }
  final gRaw = root['group'];
  if (gRaw is! Map) throw FormatException('缺少 group 节点');
  return GroupBackup(
    version: version,
    group: gRaw.cast<String, dynamic>(),
    members: _asMapList(root['members']),
    expenses: _asMapList(root['expenses']),
    settlements: _asMapList(root['settlements']),
    trips: _asMapList(root['trips']),
    customCategories: _asMapList(root['customCategories']),
  );
}

/// 导入过程统计（UI 的 SnackBar 报告用）
class ImportStats {
  const ImportStats({
    required this.members,
    required this.expenses,
    required this.trips,
    required this.items,
    required this.nulledTripLinks,
    required this.nulledItemLinks,
    required this.nulledSettleLinks,
    required this.droppedShareEntries,
    required this.droppedPortionEntries,
    required this.droppedTransfers,
    required this.droppedExpenseRefs,
    required this.reusedCategories,
    required this.createdCategories,
  });

  final int members;
  final int expenses;
  final int trips;
  final int items;

  /// 关联被置 null 的计数
  final int nulledTripLinks;
  final int nulledItemLinks;
  final int nulledSettleLinks;

  /// 数组中被剔除的无效元素计数
  final int droppedShareEntries;
  final int droppedPortionEntries;
  final int droppedTransfers;

  /// 结单里指向不存在账单的引用计数
  final int droppedExpenseRefs;

  /// 分类复用/新建数量
  final int reusedCategories;
  final int createdCategories;

  @override
  String toString() =>
      '成员$members · 账单$expenses · 行程$trips · 安排$items；'
      '分类复用$reusedCategories · 新建$createdCategories；'
      '悬空引用已清理：分摊$droppedShareEntries · 转账$droppedTransfers · '
      '行程关联$nulledTripLinks · 安排关联$nulledItemLinks';
}

/// 导入产物：全部实体已换发新 id 且内部自洽，可直接批量入库。
class ImportResult {
  const ImportResult({
    required this.group,
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.trips,
    required this.customCategories,
    required this.stats,
  });

  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> settlements;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> customCategories;
  final ImportStats stats;
}

/// 执行导入重映射。
///
/// [existingCategoryByName] 提供库内已有自定义分类 名称→key，
/// 同名者复用其 key；未命中的换发新 key（前缀 cat_）。
ImportResult applyImport(
  GroupBackup backup, {
  IdGen? gen,
  Map<String, String> existingCategoryByName = const {},
}) {
  final g = gen ?? _defaultGen;
  var nulledTrip = 0, nulledItem = 0, nulledSettle = 0;
  var droppedShares = 0, droppedPortions = 0, droppedTransfers = 0, droppedRefs = 0;

  // 单值关联安全解映射：命中返回新 id，未命中置 null 并计数
  String? remapOpt(Object? v, Map<String, String> map, void Function() bump) {
    if (v == null) return null;
    final target = map[v];
    if (target == null) {
      bump();
      return null;
    }
    return target;
  }

  // ① 团：换发新 id
  final newGroupId = g('group');
  final newGroup = <String, dynamic>{..._copy(backup.group), 'id': newGroupId};

  // ② 成员（第一级）
  final memberMap = <String, String>{};
  final newMembers = <Map<String, dynamic>>[];
  for (final m in backup.members) {
    final nid = g('member');
    final old = m['id'];
    if (old is String) memberMap[old] = nid;
    newMembers.add(<String, dynamic>{..._copy(m), 'id': nid});
  }

  // ③ 行程 + 安排（第三、四级；账单要引用它们故先建）
  final tripMap = <String, String>{};
  final itemMap = <String, String>{};
  final newTrips = <Map<String, dynamic>>[];
  for (final t in backup.trips) {
    final newTripId = g('trip');
    final oldT = t['id'];
    if (oldT is String) tripMap[oldT] = newTripId;
    final newItems = <Map<String, dynamic>>[];
    for (final it in _asMapList(t['items'])) {
      final newItemId = g('item');
      final oldI = it['id'];
      if (oldI is String) itemMap[oldI] = newItemId;
      newItems.add(<String, dynamic>{..._copy(it), 'id': newItemId, 'tripId': newTripId});
    }
    newTrips.add(<String, dynamic>{
      ..._copy(t)..remove('items'),
      'id': newTripId,
      'groupId': newGroupId,
      'items': newItems,
    });
  }

  // ④ 自定义分类：同名复用（先看库内，再看本批次已换发的）
  final keyMap = <String, String>{};
  final batchNameToKey = <String, String>{};
  var reused = 0, created = 0;
  final newCategories = <Map<String, dynamic>>[];
  for (final c in backup.customCategories) {
    final oldKey = c['key'];
    if (oldKey is! String) continue;
    final name = c['name'];
    final existing = name is String
        ? (existingCategoryByName[name] ?? batchNameToKey[name])
        : null;
    if (existing != null) {
      keyMap[oldKey] = existing;
      reused++;
      continue;
    }
    final newKey = g('cat');
    keyMap[oldKey] = newKey;
    if (name is String) batchNameToKey[name] = newKey;
    created++;
    newCategories.add(<String, dynamic>{..._copy(c), 'key': newKey});
  }

  // ⑤ id 预登记（账单与结算互相引用，需先有全量新旧对照）
  final expenseMap = <String, String>{};
  for (final e in backup.expenses) {
    final old = e['id'];
    if (old is String) expenseMap[old] = g('expense');
  }
  final settleMap = <String, String>{};
  for (final s in backup.settlements) {
    final old = s['id'];
    if (old is String) settleMap[old] = g('settle');
  }

  // ⑥ 账单体（第二级）
  final newExpenses = <Map<String, dynamic>>[];
  for (final e in backup.expenses) {
    List<Map<String, dynamic>> remapByMember(Object? raw, void Function() onDrop) {
      final out = <Map<String, dynamic>>[];
      for (final en in _asMapList(raw)) {
        final mid = en['memberId'];
        if (mid is String && memberMap.containsKey(mid)) {
          out.add(<String, dynamic>{...en, 'memberId': memberMap[mid]});
        } else {
          onDrop();
        }
      }
      return out;
    }

    final payers =
        remapByMember(e['payers'], () => droppedShares++);
    final shares = remapByMember(e['shares'], () => droppedShares++);
    final portions =
        remapByMember(e['portions'], () => droppedPortions++);

    final oldCat = e['categoryKey'];
    newExpenses.add(<String, dynamic>{
      ..._copy(e)..remove('portions'),
      'id': expenseMap[e['id']],
      'groupId': newGroupId,
      'payers': payers,
      'shares': shares,
      if (portions.isNotEmpty) 'portions': portions,
      'categoryKey':
          oldCat is String && keyMap.containsKey(oldCat) ? keyMap[oldCat] : oldCat,
      'settledRoundId':
          remapOpt(e['settledRoundId'], settleMap, () => nulledSettle++),
      'tripId': remapOpt(e['tripId'], tripMap, () => nulledTrip++),
      'tripItemId': remapOpt(e['tripItemId'], itemMap, () => nulledItem++),
    });
  }

  // ⑦ 结算轮
  final newSettlements = <Map<String, dynamic>>[];
  for (final s in backup.settlements) {
    final transfers = <Map<String, dynamic>>[];
    for (final tr in _asMapList(s['transfers'])) {
      final from = tr['from'];
      final to = tr['to'];
      if (from is String &&
          to is String &&
          memberMap.containsKey(from) &&
          memberMap.containsKey(to)) {
        transfers.add(<String, dynamic>{
          ...tr,
          'from': memberMap[from],
          'to': memberMap[to],
        });
      } else {
        droppedTransfers++;
      }
    }
    final expenseIds = <String>[];
    for (final id in (s['expenseIds'] as List<dynamic>? ?? <dynamic>[])) {
      final mapped = expenseMap[id];
      if (mapped != null) {
        expenseIds.add(mapped);
      } else {
        droppedRefs++;
      }
    }
    newSettlements.add(<String, dynamic>{
      ..._copy(s),
      'id': settleMap[s['id']],
      'transfers': transfers,
      'expenseIds': expenseIds,
    });
  }

  return ImportResult(
    group: newGroup,
    members: newMembers,
    expenses: newExpenses,
    settlements: newSettlements,
    trips: newTrips,
    customCategories: newCategories,
    stats: ImportStats(
      members: newMembers.length,
      expenses: newExpenses.length,
      trips: newTrips.length,
      items: newTrips.fold(0, (s, t) => s + _asMapList(t['items']).length),
      nulledTripLinks: nulledTrip,
      nulledItemLinks: nulledItem,
      nulledSettleLinks: nulledSettle,
      droppedShareEntries: droppedShares,
      droppedPortionEntries: droppedPortions,
      droppedTransfers: droppedTransfers,
      droppedExpenseRefs: droppedRefs,
      reusedCategories: reused,
      createdCategories: created,
    ),
  );
}
