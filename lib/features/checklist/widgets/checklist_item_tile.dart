import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../theme/tokens.dart';

/// 清单条目 tile：
/// - 右滑打勾（再右滑取消），勾选图标 scale 弹跳 + lightImpact 触觉；
/// - 左滑删除（父级负责 SnackBar 可撤销）；
/// - 已完成：删除线 + 60% 透明度折叠感；
/// - 尾部拖拽把手配合外层 ReorderableListView 长按排序。
class ChecklistItemTile extends StatelessWidget {
  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.onDeleteConfirmed,
  });

  final ChecklistItemView item;

  /// 在分区列表中的位置（拖拽把手需要）
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDeleteConfirmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('dismiss-' + item.id),
      background: _SwipeBackdrop(
        alignLeft: true,
        color: scheme.primary,
        icon: item.done ? Icons.undo_rounded : Icons.check_rounded,
        label: item.done ? '取消' : '完成',
      ),
      secondaryBackground: _SwipeBackdrop(
        alignLeft: false,
        color: Theme.of(context).colorScheme.error,
        icon: Icons.delete_outline_rounded,
        label: '删除',
      ),
      confirmDismiss: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // 右滑只切换状态，不真正移除
          HapticFeedback.lightImpact();
          onToggle();
          return Future.value(false);
        }
        // 左滑删除：交由父级展示可撤销 SnackBar
        HapticFeedback.lightImpact();
        return Future.value(true);
      },
      onDismissed: (_) => onDeleteConfirmed(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: item.done ? 0.6 : 1.0,
          child: Row(children: [
            _CheckBubble(done: item.done, onTap: onToggle),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onEdit();
                },
                child: Text(
                  item.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSizes.body,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: scheme.onSurface,
                    decoration:
                        item.done ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: scheme.onSurfaceVariant,
                    decorationThickness: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            // 拖拽把手：长按或按住拖动触发外层重排
            SizedBox(
              width: 34,
              height: 40,
              child: ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 勾选圆钮：状态切换时图标 scale 弹跳
class _CheckBubble extends StatelessWidget {
  const _CheckBubble({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs, horizontal: Spacing.xs),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1.0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.elasticOut,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? scheme.primary : Colors.transparent,
              border: Border.all(
                width: 1.7,
                color: done ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 16, weight: 3)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 滑动背景提示层
class _SwipeBackdrop extends StatelessWidget {
  const _SwipeBackdrop({
    required this.alignLeft,
    required this.color,
    required this.icon,
    required this.label,
  });

  final bool alignLeft;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      if (alignLeft) const SizedBox(width: Spacing.lg),
      Icon(icon, size: 20, color: color),
      const SizedBox(width: Spacing.xs),
      Text(
        label,
        style: TextStyle(
          fontSize: AppFontSizes.caption,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      if (!alignLeft) const SizedBox(width: Spacing.lg),
    ]);

    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.input,
      ),
      child: row,
    );
  }
}

/// 条目视图数据（UI 层视图模型，与数据层模型解耦）
class ChecklistItemView {
  const ChecklistItemView({
    required this.id,
    required this.text,
    required this.done,
  });

  final String id;
  final String text;
  final bool done;
}

/// 供分区卡复用的迷你进度环尺寸约定
const double kMiniRingSize = 26;
const double kMiniRingStroke = 3;

/// 分区头迷你进度环快捷封装
class MiniProgressBadge extends StatelessWidget {
  const MiniProgressBadge({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ProgressRing(
      value: value,
      size: kMiniRingSize,
      strokeWidth: kMiniRingStroke,
    );
  }
}
