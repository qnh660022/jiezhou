import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/tokens.dart';

/// 金额工具：全 App 金额一律 int 分存储，仅在展示层经此处格式化
abstract final class MoneyFormat {
  static final NumberFormat _grouped = NumberFormat('#,##0');

  /// 分 -> 元字符串（含千分位与负号），如 1234567 -> '12,345.67'
  static String fenToYuan(int fen) {
    final negative = fen < 0;
    final abs = fen.abs();
    final yuan = abs ~/ 100;
    final cents = (abs % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}${_grouped.format(yuan)}.$cents';
  }

  /// 展示用完整金额文本
  static String display(int fen, {String symbol = '¥', bool showSign = false}) {
    final sign = fen > 0 && showSign ? '+' : '';
    return sign + symbol + fenToYuan(fen);
  }
}

/// 金额文本：等宽数字（tabularFigures）+ 粗体，收入/支出可选语义着色
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.fen, {
    super.key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.showSign = false,
    this.symbol = '¥',
    this.semanticColor = false,
    this.incomeColor,
    this.expenseColor,
  });

  /// 分（正=收入，负=支出）
  final int fen;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final bool showSign;
  final String symbol;

  /// true 时按正负自动着色（收入绿 / 支出红）
  final bool semanticColor;
  final Color? incomeColor;
  final Color? expenseColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? resolved = color;
    if (semanticColor && resolved == null) {
      if (fen > 0) {
        resolved = incomeColor ?? SemanticColors.income;
      } else if (fen < 0) {
        resolved = expenseColor ?? SemanticColors.expense;
      }
    }
    return Text(
      MoneyFormat.display(fen, symbol: symbol, showSign: showSign),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.money(
        context,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: resolved ?? scheme.onSurface,
      ),
    );
  }
}
