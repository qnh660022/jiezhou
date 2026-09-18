/// 账本桥接层 · 导入导出 / 备份 / 快照 / CSV。
///
/// G4 拆分（V2.7.1 S2）：由 `ledger_providers.dart` barrel 统一 export。
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/csv_builder.dart';
import '../../../domain/models.dart';

/// 导出团专有备份(.tav)，返回 (字节, 文件名)
Future<(Uint8List, String)> exportGroupBackup(WidgetRef ref, String gid) async {
  final bytes = await ref.read(ledgerRepoProvider).exportGroupBackupBytes(gid);
  final g = await ref.read(ledgerRepoProvider).getGroup(gid);
  final name = _safeFileBase(g?.name ?? '团');
  return (bytes, '${name}_backup.tav');
}

/// 从 .tav 文件字节导入团备份
Future<String> importGroupBackupFile(WidgetRef ref, Uint8List bytes) async {
  final report = await ref.read(ledgerRepoProvider).importGroupBackupBytes(bytes);
  return summarizeImportReport(report);
}

/// 局域网同步：导出当前团整包 JSON 快照（稳定 id）
Future<String> exportGroupSnapshot(WidgetRef ref, String gid) =>
    ref.read(ledgerRepoProvider).exportGroupSnapshotJson(gid);

/// 局域网同步：把收到的整包快照按 id 合并进本地（LWW），返回人类可读摘要
Future<String> mergeGroupSnapshot(WidgetRef ref, String raw) =>
    ref.read(ledgerRepoProvider).mergeGroupSnapshotJson(raw);

/// 导入团（旧 JSON 文本粘贴），返回人类可读摘要
Future<String> importGroupFromText(WidgetRef ref, String jsonText) async {
  final report = await ref.read(ledgerRepoProvider).importGroupJson(jsonText);
  return summarizeImportReport(report);
}

/// 导出全量备份(.tavA)，返回 (字节, 文件名)
Future<(Uint8List, String)> exportFullBackup(WidgetRef ref) async {
  final bytes = await ref.read(ledgerRepoProvider).exportFullBackupBytes();
  final now = DateTime.now();
  final stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return (bytes, 'travel_assistant_full_$stamp.tavA');
}

/// 导入全量备份(.tavA)，replace=true 覆盖恢复 / false 合并，返回人类可读摘要
Future<String> importFullBackupFile(
  WidgetRef ref,
  Uint8List bytes, {
  required bool replace,
}) async {
  final report =
      await ref.read(ledgerRepoProvider).importFullBackupBytes(bytes, replace: replace);
  return report.toString();
}

/// 导出「全量同步码」JSON：全部团 + 未绑团行程。不依赖任何团存在（无需先建团）。
Future<String> exportFullSyncJson(WidgetRef ref) =>
    ref.read(ledgerRepoProvider).exportFullBackupJson();

/// 导入「全量同步码」JSON：LWW 合并，源端团不存在时自动创建，返回人类可读摘要。
Future<String> importFullSyncJson(WidgetRef ref, String raw) async {
  final report = await ref.read(ledgerRepoProvider).importFullBackupRawJson(raw);
  return report.toString();
}

/// 安全文件名基线（去掉路径分隔等非法字符）
String _safeFileBase(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_').trim();
  return cleaned.isEmpty ? 'backup' : cleaned;
}

/// CSV 导出文本
String buildCsvText({
  required List<ExpenseRecord> expenses,
  required Map<String, String> memberNames,
  Map<String, String> tripNames = const {},
  Map<String, String> itemTitles = const {},
  Map<String, String> categoryNames = const {},
}) =>
    buildExpensesCsv(
      expenses,
      memberNames: memberNames,
      tripNames: tripNames,
      itemTitles: itemTitles,
      categoryNames: categoryNames,
    );

/// 导入报告 → 摘要文案（字段缺失时优雅降级）
String summarizeImportReport(dynamic report) {
  try {
    return '导入成功：成员 ' + _n(report?.members).toString() +
        ' · 账单 ' + _n(report?.expenses).toString() +
        ' · 行程 ' + _n(report?.trips).toString() +
        ' · 安排 ' + _n(report?.tripItems).toString();
  } catch (_) {
    return '导入完成';
  }
}

int _n(dynamic v) => v is int ? v : 0;
