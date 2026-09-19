import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'glass_surface.dart';
import 'secondary_button.dart';

/// 空状态：矢量图标（玻璃圆盘底座）或大 emoji（存量兼容）+ 一句引导 + 可选行动按钮。
///
/// V2.8.1 S11：新增可选 [icon]（AppIcons）与玻璃圆盘底座 + 3.2s 微浮动
///（±6px，`disableAnimations` 时静止）；[emoji] 参数保留兼容（既有调用零破坏）。
///
/// **V2.8.3.3 契约收口（图标岗位规则，见 `theme/app_icons.dart` 头注）**：
/// 功能岗位一律用 [icon]（`AppIcons.*` 或 `Icons.*_rounded`）；
/// emoji **仅允许内容岗位**。[icon] 与 [emoji] 同时传入时以 [icon] 优先。
/// 新代码禁止再传 [emoji] —— 手机端调用点已于 V2.8.3.3 全量换装，
/// 残留仅剩 `features/ai/`（无版本归属）、`companions/`（V2.8.1 O1 排除）、
/// `desktop_*`（V2.8.1 O7 禁触）三处，见《2.8.3.3 版本统筹裁定书》。
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

  /// emoji 图标（**存量兼容参数，新代码禁用**；仅内容岗位允许，见类头注）。
  final String? emoji;

  /// 矢量图标（优先渲染；玻璃圆盘底座 + 微浮动）。功能岗位唯一合法形态。
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
    // V2.8.3.1：玻璃圆盘不再叠 primary 半透明渐变（双层半透导致发灰；
    // 玻璃面只保留 GlassSurface 自身材质，单一玻璃容器原则）。
    return GlassSurface(
      level: GlassLevel.floatingCard,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Center(child: child),
      ),
    );
  }
}
