/// CSV 导出构建器：账单 → Excel 友好的定长列 CSV 文本。
///
/// 硬性规范：
/// * UTF-8 BOM（\uFEFF）开头，保证 Excel 双击直开不乱码；
/// * 行尾一律 CRLF；
/// * csvEscape 处理逗号/引号/换行；
/// * 列定义集中在 [kCsvColumns]（唯一真源），顺序即列序，表头由 label 生成。
///
/// 【列数演进】V2.7.1 内叠加：S1 保持 17 列 → S3 增第 18 列「分摊百分比」
/// → S11 增第 19 列「支付方式」。任何新增列都必须追加进 [kCsvColumns]，
/// 禁止在导出逻辑里手写表头或列数。
library;

import '../core/date_utils.dart';
import '../core/money.dart';
import 'models.dart';

/// 导出上下文：把 id → 可读名 的映射集中传入各列的 [CsvColumn.valueOf]。
class CsvContext {
  const CsvContext({
    this.memberNames = const {},
    this.tripNames = const {},
    this.itemTitles = const {},
    this.categoryNames = const {},
  });

  /// memberId -> 姓名（缺失回退显示 id）
  final Map<String, String> memberNames;

  /// tripId -> 行程名
  final Map<String, String> tripNames;

  /// tripItemId -> 安排名
  final Map<String, String> itemTitles;

  /// categoryKey -> 分类中文名（缺失回退 key）
  final Map<String, String> categoryNames;
}

/// 单列定义：[key] 稳定标识（导入识别用），[label] 表头文案，[valueOf] 取值。
class CsvColumn {
  const CsvColumn(this.key, this.label, this.valueOf);

  final String key;
  final String label;
  final String Function(ExpenseRecord e, CsvContext ctx) valueOf;
}

/// 单元格转义：含逗号/引号/换行时加引号包裹并把内部引号翻倍
String csvEscape(String cell) {
  final needQuote =
      cell.contains(',') || cell.contains('"') || cell.contains('\n') || cell.contains('\r');
  if (!needQuote) return cell;
  return '"${cell.replaceAll('"', '""')}"';
}

String _typeLabel(ExpenseType t) {
  switch (t) {
    case ExpenseType.normal:
      return '正常';
    case ExpenseType.refund:
      return '退款';
    case ExpenseType.prepay:
      return '预付';
  }
}

String _modeLabel(ShareMode m) {
  switch (m) {
    case ShareMode.equal:
      return '平均';
    case ShareMode.portions:
      return '按份数';
    case ShareMode.percent:
      return '按百分比';
    case ShareMode.custom:
      return '自定义';
  }
}

String _payerNames(ExpenseRecord e, CsvContext c) =>
    e.payers.map((p) => c.memberNames[p.memberId] ?? p.memberId).join('、');

String _shareeNames(ExpenseRecord e, CsvContext c) =>
    e.shares.map((s) => c.memberNames[s.memberId] ?? s.memberId).join('、');

String _shareDetail(ExpenseRecord e, CsvContext c) => e.shares
    .map((s) => '${c.memberNames[s.memberId] ?? s.memberId}:${formatMoney(s.cents)}')
    .join('；');

/// 分摊百分比单元格（percent 模式）：按 shares 成员顺序输出每人百分比，
/// 值 = bp/100 两位小数（如单成员 `33.33`、多人 `33.33；66.67`）；其余模式留空。
String _sharePercentCell(ExpenseRecord e, CsvContext c) {
  final portions = e.portions;
  if (e.shareMode != ShareMode.percent || portions == null || portions.isEmpty) return '';
  return e.shares
      .map((s) => ((portions[s.memberId] ?? 0) / 100).toStringAsFixed(2))
      .join('；');
}

/// CSV 列定义（唯一真源；顺序即列序）。
///
/// V2.7.1 S1 基线 17 列，语义与历史导出逐行一致：
/// 日期/描述/分类/类型/金额元/币种/汇率/外币金额/付款人/分摊方式/分摊人数/
/// 分摊人/分摊明细/备注/状态/关联行程/关联安排。
const List<CsvColumn> kCsvColumns = <CsvColumn>[
  CsvColumn('date', '日期', _dateCell),
  CsvColumn('title', '描述', _titleCell),
  CsvColumn('category', '分类', _categoryCell),
  CsvColumn('type', '类型', _typeCell),
  CsvColumn('amount', '金额元', _amountCell),
  CsvColumn('currency', '币种', _currencyCell),
  CsvColumn('rate', '汇率', _rateCell),
  CsvColumn('amountForeign', '外币金额', _amountForeignCell),
  CsvColumn('payers', '付款人', _payerNames),
  CsvColumn('shareMode', '分摊方式', _shareModeCell),
  CsvColumn('shareCount', '分摊人数', _shareCountCell),
  CsvColumn('sharees', '分摊人', _shareeNames),
  CsvColumn('shareDetail', '分摊明细', _shareDetail),
  CsvColumn('note', '备注', _noteCell),
  CsvColumn('status', '状态', _statusCell),
  CsvColumn('trip', '关联行程', _tripCell),
  CsvColumn('tripItem', '关联安排', _tripItemCell),
  // ===== V2.7.1 S3 新增（第 18 列）=====
  CsvColumn('sharePercent', '分摊百分比', _sharePercentCell),
  // ===== V2.7.1 S11 新增（第 19 列）=====
  CsvColumn('payMethod', '支付方式', _payMethodCell),
];

String _dateCell(ExpenseRecord e, CsvContext c) =>
    fmtIsoDate(epochDayToDate(e.dateEpochDay));
String _titleCell(ExpenseRecord e, CsvContext c) => e.title;
String _categoryCell(ExpenseRecord e, CsvContext c) =>
    c.categoryNames[e.categoryKey] ?? e.categoryKey;
String _typeCell(ExpenseRecord e, CsvContext c) => _typeLabel(e.type);
String _amountCell(ExpenseRecord e, CsvContext c) => formatMoney(e.amountCents);
String _currencyCell(ExpenseRecord e, CsvContext c) => e.currency;
String _rateCell(ExpenseRecord e, CsvContext c) => e.rate.toStringAsFixed(4);
String _amountForeignCell(ExpenseRecord e, CsvContext c) =>
    e.amountForeignCents == null ? '' : formatMoney(e.amountForeignCents!);
String _shareModeCell(ExpenseRecord e, CsvContext c) => _modeLabel(e.shareMode);
String _shareCountCell(ExpenseRecord e, CsvContext c) =>
    e.shares.map((s) => s.memberId).toSet().length.toString();
String _noteCell(ExpenseRecord e, CsvContext c) => e.note ?? '';
String _statusCell(ExpenseRecord e, CsvContext c) =>
    e.settledRoundId != null ? '已结' : '未结';
String _tripCell(ExpenseRecord e, CsvContext c) =>
    e.tripId == null ? '' : (c.tripNames[e.tripId] ?? e.tripId!);
String _tripItemCell(ExpenseRecord e, CsvContext c) =>
    e.tripItemId == null ? '' : (c.itemTitles[e.tripItemId] ?? e.tripItemId!);
String _payMethodCell(ExpenseRecord e, CsvContext c) => e.payMethod ?? '';

/// 表头行（由 [kCsvColumns] 的 label 生成，禁止手写列数）。
String buildCsvHeader() => kCsvColumns.map((c) => csvEscape(c.label)).join(',');

/// 构建账单 CSV（列数与顺序由 [kCsvColumns] 决定）。
String buildExpensesCsv(
  List<ExpenseRecord> expenses, {
  required Map<String, String> memberNames,
  Map<String, String> tripNames = const {},
  Map<String, String> itemTitles = const {},
  Map<String, String> categoryNames = const {},
}) {
  final ctx = CsvContext(
    memberNames: memberNames,
    tripNames: tripNames,
    itemTitles: itemTitles,
    categoryNames: categoryNames,
  );
  final buf = StringBuffer('\uFEFF');
  buf.write(buildCsvHeader());
  buf.write('\r\n');
  for (final e in expenses) {
    buf.write(kCsvColumns.map((c) => csvEscape(c.valueOf(e, ctx))).join(','));
    buf.write('\r\n');
  }
  return buf.toString();
}
