// 今日驾驶舱系列的共用表面件（卡面 / 小块标题）。
//
// 仅用 tokens 与 colorScheme：浅色用 surfaceContainerLowest、暗色用
// surfaceContainerHigh 抬高对比（石墨夜同过验收）。不自造毛玻璃——
// 玻璃面只走 glass_app_bar 与 SheetSurface 两条既有路径。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/tokens.dart';

/// 卡面：大圆角 24 + 表面色 + 可选描边与点击。
class TodaySurface extends StatelessWidget {
  const TodaySurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Spacing.xl),
    this.accent = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// true 时叠一圈主题色柔光描边（用于主卡 / 摘要卡）。
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        border: accent
            ? Border.all(color: scheme.primary.withValues(alpha: 0.22), width: 1)
            : Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.55), width: 1),
      ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, 0),
      child: Material(
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                borderRadius: AppRadius.card,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
                child: content,
              ),
      ),
    );
  }
}

/// 卡内小块标题（13 号 caption + 可选右侧动作）。
class TodayCardTitle extends StatelessWidget {
  const TodayCardTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 「查看详情 ›」内联入口。
class TodayMoreLink extends StatelessWidget {
  const TodayMoreLink({super.key, this.label = '查看详情'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSizes.caption,
            fontWeight: FontWeight.w500,
            color: scheme.primary,
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 16, color: scheme.primary),
      ],
    );
  }
}
