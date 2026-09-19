import 'package:flutter/material.dart';

import '../../../theme/app_icons.dart';

/// V2.8.2 S3：封面图标水印 —— 替换行程卡 86px emoji 视差位。
///
/// 图标 52px 白 45%；[child] 保留时可回落渲染 emoji（trip.emoji 数据字段
/// 只读不改，O6：本版仅渲染层水印）。
class CoverWatermark extends StatelessWidget {
  const CoverWatermark({super.key, this.icon, this.emoji, this.child});

  /// 水印图标（如 AppIcons.compass）。
  final IconData? icon;

  /// emoji 兜底（icon 为空且 emoji 非空时渲染 emoji 文字，白 45%）。
  final String? emoji;

  /// 自定义视差内容（调用方自带 ParallaxBox 时直接传 child）。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) return child!;
    if (icon != null) {
      return Icon(icon, size: 52, color: Colors.white.withValues(alpha: 0.45));
    }
    return Text(emoji ?? '',
        style: TextStyle(
            fontSize: 52,
            height: 1,
            color: Colors.white.withValues(alpha: 0.45)));
  }
}
