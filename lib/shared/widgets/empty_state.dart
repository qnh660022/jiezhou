import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'glass_surface.dart';
import 'secondary_button.dart';

/// 空状态：大 emoji（内容岗位兼容参数）或矢量图标（玻璃圆盘底座）+ 一句引导 + 可选行动按钮。
///
/// V2.8.1 S11：新增可选 [icon]（AppIcons）与玻璃圆盘底座 + 3.2s 微浮动
///（±6px，`disableAnimations` 时静止）；[emoji] 参数保留兼容（既有调用零破坏）。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.emoji,
    this.icon,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// emoji 图标（兼容参数：内容岗位，未迁移调用点仍走这里）。
  final String? emoji;

  /// 矢量图标（优先渲染；玻璃圆盘底座 + 微浮动）。
  final IconData? icon;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final useIcon = icon != null;
    final visual = useIcon
        ? _FloatingGlassDisc(
            child: Icon(icon,
                size: 34, color: scheme.primary),
          )
        : Text(emoji ?? '', style: const TextStyle(fontSize: 64, height: 1.1));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            visual,
            const SizedBox(height: Spacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.9)),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Spacing.xxl),
              SecondaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// 玻璃圆盘底座 + 3.2s 微浮动（±6px 正弦缓动；disableAnimations 时静止）。
class _FloatingGlassDisc extends StatelessWidget {
  const _FloatingGlassDisc({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled) return _disc(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 3200),
      builder: (context, t, child) {
        // 正弦缓动 ±6px；t∈[0,1] 循环感由正弦对称承担（单程往复近似）
        final dy = sin(t * pi * 4) * 6;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: _disc(context),
    );
  }

  Widget _disc(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      level: GlassLevel.floatingCard,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.primary.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
