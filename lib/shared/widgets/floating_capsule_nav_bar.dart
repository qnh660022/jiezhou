import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/tokens.dart';
import 'glass_surface.dart';

/// 底栏 Tab 数据
/// V2.8.2 S1：新增 [icon]（JieZhouIcons）；[emoji] 保留兼容（Web 桌面底栏继续用）。
class CapsuleTabItem {
  const CapsuleTabItem({required this.emoji, required this.label, this.icon});

  final String emoji;
  final String label;
  final IconData? icon;
}

/// 悬浮胶囊底栏：毛玻璃 + 选中弹性缩放 + 触觉反馈
class FloatingCapsuleNavBar extends StatelessWidget {
  const FloatingCapsuleNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<CapsuleTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, Spacing.sm),
        // V2.8.1 S2：σ24+α0.88 手写玻璃收编为 GlassSurface(navBar)，
        // 手写阴影删除（由 GlassSurface 双层影替代）；触觉与弹性缩放不动。
        // V2.8.3.4：玻璃特效全 App 撤销后，底栏是**唯一**保留模糊的表面
        // （页面内容从胶囊下方穿过，模糊是它可读性的前提），故显式开 blur。
        child: GlassSurface(
          level: GlassLevel.navBar,
          blur: true,
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _CapsuleTab(
                      item: items[i],
                      selected: i == currentIndex,
                      selectedColor: scheme.primary,
                      idleColor: scheme.onSurfaceVariant,
                      onTap: () {
                        if (i == currentIndex) return;
                        HapticFeedback.selectionClick();
                        onTap(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CapsuleTab extends StatelessWidget {
  const _CapsuleTab({
    required this.item,
    required this.selected,
    required this.selectedColor,
    required this.idleColor,
    required this.onTap,
  });

  final CapsuleTabItem item;
  final bool selected;
  final Color selectedColor;
  final Color idleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : idleColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.icon != null)
              Icon(item.icon,
                  size: selected ? 24 : 22,
                  color: selected ? selectedColor : idleColor)
            else
              Text(item.emoji,
                  style: TextStyle(
                      fontSize: selected ? 23 : 20,
                      color: selected ? selectedColor : idleColor)),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
