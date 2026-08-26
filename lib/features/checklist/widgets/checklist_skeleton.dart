import 'package:flutter/material.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';

/// 清单页加载骨架屏：进度卡 + 两张分区卡占位
class ChecklistSkeleton extends StatelessWidget {
  const ChecklistSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.huge),
      children: [
        const SkeletonBox(height: 112, radius: AppRadius.cardValue),
        const SizedBox(height: Spacing.lg),
        const _SectionSkeleton(),
        const SizedBox(height: Spacing.lg),
        const _SectionSkeleton(),
      ],
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
      ),
      child: Column(children: [
        Row(children: [
          const SkeletonBox(height: 34, width: 34, circle: true),
          const SizedBox(width: Spacing.md),
          const SkeletonBox(height: 14, width: 96, radius: 4),
          const Spacer(),
          const SkeletonBox(height: 14, width: 44, radius: 4),
        ]),
        const SizedBox(height: Spacing.lg),
        for (var i = 0; i < 3; i++) ...[
          const Row(children: [
            SkeletonBox(height: 24, width: 24, circle: true),
            SizedBox(width: Spacing.md),
            Expanded(child: SkeletonBox(height: 13, radius: 4)),
            SizedBox(width: Spacing.lg),
            SkeletonBox(height: 16, width: 18, radius: 4),
          ]),
          if (i != 2) const SizedBox(height: Spacing.lg),
        ],
      ]),
    );
  }
}
