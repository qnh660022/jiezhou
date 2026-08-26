/// 金额核心工具：全程 int 分存储与计算，仅展示层格式化。
///
/// 【全局约定】amountCents 带符号 —— normal/prepay 为正、refund 为负。
/// 解析只接受用户输入的「元」字符串；展示统一走 formatMoney 千分位。
library;

/// 严格金额格式：非负整数元，或最多两位小数的非负小数。
/// 例："12" ✓、"12.5" ✓、"12.34" ✓、".5" ✗、"1.234" ✗、"-1" ✗、"1." ✗
final RegExp _moneyPattern = RegExp(r'^\d+(\.\d{1,2})?$');

/// 展示格式回读：千分位分组整数部分必须搭配固定两位小数，
/// 即 [formatMoney] 的输出形态。例："1,024.00" ✓；"1,000" ✗（裸分组无小数视为非法）。
final RegExp _groupedMoneyPattern = RegExp(r'^\d{1,3}(,\d{3})+\.\d{2}$');

/// 把「元」字符串解析为 int 分。
///
/// 输入先去首尾空白；接受两种形态——用户严格输入（无千分位）与
/// [formatMoney] 的展示输出（千分位 + 固定两位小数）。其余返回 null
/// （不抛异常，由 UI 层提示「金额格式不正确」）。
int? parseMoney(String input) {
  final s = input.trim();
  if (_moneyPattern.hasMatch(s)) {
    final dot = s.indexOf('.');
    if (dot < 0) return int.parse(s) * 100;
    final yuan = s.substring(0, dot);
    final frac = s.substring(dot + 1).padRight(2, '0'); // "12.5" -> "50"
    return int.parse(yuan) * 100 + int.parse(frac);
  }
  if (_groupedMoneyPattern.hasMatch(s)) {
    final dot = s.indexOf('.');
    final yuan = s.substring(0, dot).replaceAll(',', '');
    return int.parse(yuan) * 100 + int.parse(s.substring(dot + 1));
  }
  return null;
}

/// int 分 → 千分位 + 固定两位小数字符串（带符号）。
///
/// 例：1234567 -> "12,345.67"；-50 -> "-0.50"；0 -> "0.00"。
String formatMoney(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}${_groupThousands(yuan)}.$fen';
}

/// 整数千分位分组：1234567 -> "1,234,567"
String _groupThousands(int value) {
  final digits = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buf.write(digits[i]);
    final rest = digits.length - i - 1;
    if (rest > 0 && rest % 3 == 0) buf.write(',');
  }
  return buf.toString();
}
