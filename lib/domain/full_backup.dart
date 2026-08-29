/// 全量备份：全部团（每团含成员/账单/结算/行程及安排/自定义分类）+ 未绑团行程。
///
/// 与单团 .tav 复用同一套稳定 id 结构；根结构：
/// ```json
/// {"app":"travel-assistant-v2","version":2,"kind":"full",
///  "groups":[{单团备份根: group/members/expenses/settlements/trips/customCategories}, ...],
///  "standaloneTrips":[{行程字段...,"items":[...]}, ...]}
/// ```
library;

import 'group_backup.dart' show kBackupApp;

/// 全量备份格式版本
const int kFullBackupVersion = 2;

/// 全量备份 kind 标识
const String kFullBackupKind = 'full';

/// 解析后的全量备份视图
class FullBackup {
  const FullBackup({required this.groups, required this.standaloneTrips});

  /// 每个元素为单团备份根结构（group/members/expenses/settlements/trips/customCategories）
  final List<Map<String, dynamic>> groups;

  /// 未绑团行程（含 `items` 数组）
  final List<Map<String, dynamic>> standaloneTrips;
}

/// 组装配全量备份根结构（不修改入参）。
Map<String, dynamic> buildFullBackup({
  required List<Map<String, dynamic>> groups,
  required List<Map<String, dynamic>> standaloneTrips,
}) =>
    <String, dynamic>{
      'app': kBackupApp,
      'version': kFullBackupVersion,
      'kind': kFullBackupKind,
      'groups': [for (final g in groups) Map<String, dynamic>.of(g)],
      'standaloneTrips': [
        for (final t in standaloneTrips) Map<String, dynamic>.of(t),
      ],
    };

/// 解析并校验已解码的全量备份根节点；非法输入抛 [FormatException]。
FullBackup parseFullBackupMap(Map<String, dynamic> root) {
  if (root['app'] != kBackupApp) {
    throw const FormatException('不是「芥舟」的备份文件');
  }
  final version = root['version'];
  if (version is! int || version <= 0 || version > kFullBackupVersion) {
    throw FormatException('不支持的备份版本: $version');
  }
  final groups = <Map<String, dynamic>>[];
  for (final g in (root['groups'] as List<dynamic>? ?? <dynamic>[])) {
    if (g is Map) groups.add(g.cast<String, dynamic>());
  }
  final trips = <Map<String, dynamic>>[];
  for (final t in (root['standaloneTrips'] as List<dynamic>? ?? <dynamic>[])) {
    if (t is Map) trips.add(t.cast<String, dynamic>());
  }
  return FullBackup(groups: groups, standaloneTrips: trips);
}

/// 全量备份导入摘要（UI SnackBar / 日志用）。
class FullImportReport {
  const FullImportReport({
    required this.groups,
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.trips,
    required this.items,
    required this.standaloneTrips,
    required this.replace,
  });

  final int groups;
  final int members;
  final int expenses;
  final int settlements;

  /// 绑定到团内的行程数
  final int trips;

  /// 行程内安排总数
  final int items;

  /// 未绑团独立行程数
  final int standaloneTrips;

  /// true=覆盖恢复；false=合并
  final bool replace;

  @override
  String toString() =>
      '${replace ? '恢复' : '合并'}完成：团$groups · 成员$members · 账单$expenses · '
      '结算$settlements · 行程$trips · 安排$items · 独立行程$standaloneTrips';
}

int _lenOf(Object? v) => v is List ? v.length : 0;

/// 由解析后的备份推导导入摘要（按「将处理」的口径统计）。
FullImportReport fullImportReportFor(FullBackup b, {required bool replace}) {
  var members = 0, expenses = 0, settlements = 0, trips = 0, items = 0;
  for (final g in b.groups) {
    members += _lenOf(g['members']);
    expenses += _lenOf(g['expenses']);
    settlements += _lenOf(g['settlements']);
    for (final t in (g['trips'] as List<dynamic>? ?? <dynamic>[])) {
      if (t is Map) {
        trips++;
        items += _lenOf(t['items']);
      }
    }
  }
  for (final t in b.standaloneTrips) {
    items += _lenOf(t['items']);
  }
  return FullImportReport(
    groups: b.groups.length,
    members: members,
    expenses: expenses,
    settlements: settlements,
    trips: trips,
    items: items,
    standaloneTrips: b.standaloneTrips.length,
    replace: replace,
  );
}
