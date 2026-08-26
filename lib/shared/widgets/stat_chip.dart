import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// 统计小胶囊：emoji/图标 + 标签 + 数值（数值走等宽数字）
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.emoji,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? emoji;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm + 2),
      decoration: BoxDecoration(
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 13))
          else if (icon != null)
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          if (emoji != null || icon != null) const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: AppFontSizes.caption,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(width: Spacing.xs + 2),
          Text(value,
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w700,
                color: valueColor ?? scheme.onSurface,
                fontFeatures: AppTextStyles.tabularFigures,
              )),
        ],
      ),
    );
  }
}
