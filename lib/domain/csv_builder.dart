/// CSV 导出构建器：账单 → Excel 友好的 15 列 CSV 文本。
///
/// 硬性规范：
/// * UTF-8 BOM（\uFEFF）开头，保证 Excel 双击直开不乱码；
/// * 行尾一律 CRLF；
/// * csvEscape 处理逗号/引号/换行；
/// * 15 列固定顺序见 [_header]。
library;

import '../core/date_utils.dart';
import '../core/money.dart';
import 'models.dart';

const List<String> _header = [
  '日期', '描述', '分类', '类型', '金额元', '币种', '汇率', '外币金额',
  '付款人', '分摊方式', '分摊人数', '备注', '状态', '关联行程', '关联安排',
];

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
    case ShareMode.custom:
      return '自定义';
  }
}

/// 构建 15 列账单 CSV。
///
/// * [memberNames] memberId -> 姓名（缺失回退显示 id）；
/// * [tripNames]   tripId -> 行程名；
/// * [itemTitles]  tripItemId -> 安排名；
/// * [categoryNames] categoryKey -> 分类中文名（缺失回退 key）。
String buildExpensesCsv(
  List<ExpenseRecord> expenses, {
  required Map<String, String> memberNames,
  Map<String, String> tripNames = const {},
  Map<String, String> itemTitles = const {},
  Map<String, String> categoryNames = const {},
}) {
  final buf = StringBuffer('\uFEFF');
  buf.write(_header.map(csvEscape).join(','));
  buf.write('\r\n');
  for (final e in expenses) {
    final cells = <String>[
      fmtIsoDate(epochDayToDate(e.dateEpochDay)),
      e.title,
      categoryNames[e.categoryKey] ?? e.categoryKey,
      _typeLabel(e.type),
      formatMoney(e.amountCents),
      e.currency,
      e.rate.toStringAsFixed(4),
      e.amountForeignCents == null ? '' : formatMoney(e.amountForeignCents!),
      e.payers.map((p) => memberNames[p.memberId] ?? p.memberId).join('、'),
      _modeLabel(e.shareMode),
      e.shares.map((s) => s.memberId).toSet().length.toString(),
      e.note ?? '',
      e.settledRoundId != null ? '已结' : '未结',
      e.tripId == null ? '' : (tripNames[e.tripId] ?? e.tripId!),
      e.tripItemId == null ? '' : (itemTitles[e.tripItemId] ?? e.tripItemId!),
    ];
    buf.write(cells.map(csvEscape).join(','));
    buf.write('\r\n');
  }
  return buf.toString();
}
