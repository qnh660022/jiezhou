import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/tokens.dart';

/// 横滑行程选择 chips：选中实感高亮 + 尾部「复制历史行程」入口
class TripChipSelector extends StatelessWidget {
  const TripChipSelector({
    super.key,
    required this.trips,
    required this.selectedTripId,
    required this.onSelect,
    required this.onCopyFromHistory,
    this.onSmartTemplate,
  });

  final List<TripChipData> trips;
  final String? selectedTripId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCopyFromHistory;

  /// 智能模板库入口（可空则隐藏）
  final VoidCallback? onSmartTemplate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: trips.length + (onSmartTemplate != null ? 2 : 1),
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, index) {
          // 尾部固定：智能模板库 + 从历史行程复制入口
          if (index == trips.length && onSmartTemplate != null) {
            return _ActionChip(
              icon: Icons.auto_awesome_rounded,
              label: '智能模板',
              onTap: onSmartTemplate!,
            );
          }
          if (index == trips.length + (onSmartTemplate != null ? 1 : 0)) {
            return _ActionChip(
              icon: Icons.copy_rounded,
              label: '复制历史',
              onTap: onCopyFromHistory,
            );
          }
          final trip = trips[index];
          final selected = trip.id == selectedTripId;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (selected) return;
              HapticFeedback.selectionClick();
              onSelect(trip.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding:
                  const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
                borderRadius: AppRadius.capsule,
                border: Border.all(
                  color:
                      selected ? scheme.primary.withValues(alpha: 0.7) : scheme.outlineVariant,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(trip.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: Spacing.sm),
                Text(
                  trip.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
          borderRadius: AppRadius.capsule,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: Spacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ]),
      ),
    );
  }
}

/// 行程 chip 数据（UI 层视图模型，与数据层 Trip 解耦）
class TripChipData {
  const TripChipData({
    required this.id,
    required this.name,
    required this.emoji,
  });

  final String id;
  final String name;
  final String emoji;
}
