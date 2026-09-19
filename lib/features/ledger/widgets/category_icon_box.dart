import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/tokens.dart';

/// 分类图标色块：账单行左侧的圆角小方块。
///
/// 取色规则：以分类 key 做姓名哈希映射到八色盘 —— 同一分类全 App 颜色恒定，
/// 且不引入 tokens 之外的任何硬编码色值。
///
/// V2.8.1 S4：新增 [iconKey]（内置分类 key）优先渲染 JieZhouIcons 矢量图标
/// （语义色 12% 底 + 内高光圈）；[icon]（emoji）参数保留兼容（内容岗位），
/// 未传 iconKey 时回落 emoji 渲染。
class CategoryIconBox extends StatelessWidget {
  const CategoryIconBox({
    super.key,
    required this.categoryKey,
    this.icon,
    this.iconKey,
    this.size = 44,
  });

  final String categoryKey;

  /// emoji 图标（兼容参数：自定义分类/未迁移调用点仍走这里）。
  final String? icon;

  /// 内置分类 key → AppIcons 映射渲染（优先）。
  final String? iconKey;

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AvatarPalette.colorForName(categoryKey);
    // 内置分类 key 自动命中映射；自定义分类回落 emoji（兼容），无 emoji 用 tag
    final effectiveKey = iconKey ??
        (AppIcons.categoryIcons.containsKey(categoryKey) ? categoryKey : null);
    final vectorIcon =
        effectiveKey == null ? null : AppIcons.forCategory(effectiveKey);
    final radius = BorderRadius.circular(size * 0.36);
    Widget child;
    if (vectorIcon != null) {
      // 语义色底 + 内高光圈（场景 F 头部样式）
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.4],
          ),
        ),
        child: Icon(vectorIcon,
            size: size * 0.52, color: scheme.onSurfaceVariant),
      );
    } else if ((icon ?? '').isEmpty) {
      // 无 emoji 的自定义分类 → tag 兜底图标
      child = Icon(AppIcons.tag,
          size: size * 0.52, color: scheme.onSurfaceVariant);
    } else {
      child = Text(icon!,
          style: TextStyle(fontSize: size * 0.46), textAlign: TextAlign.center);
    }    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: radius,
      ),
      child: child,
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
