import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/tokens.dart';

/// 顶部分段控件：🧳 行李清单 / ✅ 待办清单
/// 白色滑块在胶囊轨道上平滑滑动，切换带 selectionClick 触觉。
class ChecklistSegmentedControl extends StatelessWidget {
  const ChecklistSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// 两段文案（emoji + 标签），当前固定为两段布局
  final List<SegmentLabel> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    assert(segments.length == 2, '分段控件当前按两段布局实现');

    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: AppRadius.capsule,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - 6;
          final thumbWidth = trackWidth / 2;
          return Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: thumbWidth * selectedIndex,
              top: 0,
              width: thumbWidth,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: AppRadius.capsule,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < segments.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i == selectedIndex) return;
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: AppFontSizes.body,
                          fontWeight: i == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == selectedIndex
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(segments[i].emoji,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: Spacing.sm),
                            Text(segments[i].label),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ]);
        }),
      ),
    );
  }
}

/// 分段文案数据
class SegmentLabel {
  const SegmentLabel({required this.emoji, required this.label});

  final String emoji;
  final String label;
}
