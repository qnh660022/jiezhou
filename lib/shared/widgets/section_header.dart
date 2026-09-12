import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// 区块标题：左侧标题 + 右侧可选「查看全部 ›」
///
/// 2026-09：右侧入口改为「有 [onTrailingTap] 才渲染」——此前必须显式传
/// `trailingLabel: null` 才能藏掉它，调用方很容易忘，于是出现只有字样、
/// 点了没反应的假入口。现在 `trailingLabel` 缺省为「查看全部」，
/// 但没有回调就不渲染。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String? subtitle;

  /// 右侧入口文案；仅当 [onTrailingTap] 非空时渲染，缺省「查看全部」。
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xl, Spacing.xl, Spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (onTrailingTap != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailingTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Row(
                  children: [
                    Text(trailingLabel ?? '查看全部',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            fontWeight: FontWeight.w500,
                            color: scheme.primary)),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: scheme.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
