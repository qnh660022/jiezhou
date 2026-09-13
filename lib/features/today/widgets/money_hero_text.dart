// 驾驶舱大数字金额：整数部分大、小数部分缩半（V2.6.6.2 §8.4 第 2 条）。
//
// 与 shared/widgets/money_text.dart 同一口径：入参一律 **int 分**，
// 展示层经 [MoneyFormat] 格式化；等宽数字保证纵向对齐。
// 这里只负责"字号分档"，不引入任何新色值。
import 'package:flutter/material.dart';

import '../../../shared/widgets/money_text.dart';
import '../../../theme/tokens.dart';

/// 大数字金额文本（如「¥1,280.<small>50</small>」）。
class MoneyHeroText extends StatelessWidget {
  const MoneyHeroText(
    this.cents, {
    super.key,
    this.fontSize = AppFontSizes.display,
    this.color,
    this.symbol = '¥',
  });

  /// 金额（分）；负数（退款冲减）显示前导负号。
  final int cents;
  final double fontSize;
  final Color? color;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = AppTextStyles.money(
      context,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color ?? scheme.onSurface,
    );
    final text = MoneyFormat.fenToYuan(cents);
    final negative = text.startsWith('-');
    final body = negative ? text.substring(1) : text;
    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    // 小数部分连同小数点一起缩小到半号，视觉重心落在整数位。
    final decPart = dot < 0 ? '' : body.substring(dot);

    return Text.rich(
      TextSpan(
        children: [
          if (negative) TextSpan(text: '-', style: base),
          TextSpan(
            text: symbol,
            style: base.copyWith(fontSize: fontSize * 0.55),
          ),
          TextSpan(text: intPart, style: base),
          if (decPart.isNotEmpty)
            TextSpan(
              text: decPart,
              style: base.copyWith(fontSize: fontSize * 0.5),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
