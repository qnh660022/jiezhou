import 'package:flutter/material.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../theme/tokens.dart';

/// 主进度卡：大进度环 + 百分比数字滚动 + 剩余件数文案
class ChecklistProgressCard extends StatelessWidget {
  const ChecklistProgressCard({
    super.key,
    required this.total,
    required this.done,
    required this.headerLabel,
  });

  final int total;
  final int done;

  /// 卡片标题（行李模式「打包进度」/ 待办模式「待办进度」）
  final String headerLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final left = total - done;
    final doneText = '$done';
    final totalText = '$total';

    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) {
            final n = (animated * 100).round();
            return ProgressRing(
              value: animated,
              size: 84,
              strokeWidth: 9,
              child: Text(
                '$n%',
                style: TextStyle(
                  fontSize: AppFontSizes.bodyLarge,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: AppTextStyles.tabularFigures,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: Spacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headerLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: Spacing.xs),
              if (total > 0 && left == 0)
                Text(
                  '全部搞定！🎉',
                  style: TextStyle(
                    fontSize: AppFontSizes.title,
                    fontWeight: FontWeight.w800,
                    color: SemanticColors.income,
                  ),
                )
              else
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '还剩 '),
                      TextSpan(
                        text: '$left',
                        style: TextStyle(
                          fontSize: AppFontSizes.headline,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                          fontFeatures: AppTextStyles.tabularFigures,
                        ),
                      ),
                      TextSpan(text: ' 件待完成'),
                    ],
                    style: TextStyle(
                      fontSize: AppFontSizes.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              const SizedBox(height: Spacing.sm),
              Text(
                '已完成 $doneText/$totalText 件',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFeatures: AppTextStyles.tabularFigures,
                    ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
