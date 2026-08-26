import 'package:flutter/material.dart';
import '../../../theme/tokens.dart';

/// 数字滚动文本：目标值变化时从当前值平滑补间（预算超支红字、百分比等场景）。
///
/// 默认走等宽数字（tabularFigures），滚动中位数宽度稳定不抖动。
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 750),
  });

  /// 目标整数值（如分、百分比、笔数）
  final int value;

  /// 展示格式化器（如 formatMoney / 百分比拼接）；缺省直接显示整数
  final String Function(int value)? formatter;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // begin 为 null：从动画当前值续滚到新目标，值频繁变化也丝滑
      tween: Tween<double>(begin: null, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        final v = animated.round();
        final defaultStyle = AppTextStyles.money(context);
        return Text(
          formatter != null ? formatter!(v) : v.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (style ?? defaultStyle).copyWith(
            fontFeatures: AppTextStyles.tabularFigures,
          ),
        );
      },
    );
  }
}
