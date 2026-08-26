import 'package:flutter/material.dart';
import '../../../theme/tokens.dart';

/// 分类图标色块：账单行左侧的圆角小方块。
///
/// 取色规则：以分类 key 做姓名哈希映射到八色盘 —— 同一分类全 App 颜色恒定，
/// 且不引入 tokens 之外的任何硬编码色值。
class CategoryIconBox extends StatelessWidget {
  const CategoryIconBox({
    super.key,
    required this.categoryKey,
    required this.icon,
    this.size = 44,
  });

  final String categoryKey;
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AvatarPalette.colorForName(categoryKey);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Text(icon, style: TextStyle(fontSize: size * 0.46)),
    );
  }
}

/// 类型徽标（退款 / 预付）小胶囊
class ExpenseTypeChip extends StatelessWidget {
  const ExpenseTypeChip({super.key, required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}
