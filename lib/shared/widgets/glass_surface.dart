import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// V2.8.1 S2：统一玻璃表面 —— 全 App 毛玻璃**唯一**实现。
///
/// 结构（外→内）：
/// ```
/// ClipRRect(borderRadius)
///   └ BackdropFilter(ImageFilter.compose(blur(σ,σ), ColorFilter.saturate(sat)))
///       └ Container(decoration)
///           · color: scheme.surfaceContainerLow × tint（按 level 修正）
///           · gradient 前景高光: 160° 白 [hi→0]，38% 处截止
///           · boxShadow 双层: 环影(blur40, offset(0,18)) + 关键影(blur10, offset(0,3))
/// ```
/// 档位修正表（阴影倍率 / tint 倍率）：
/// | level       | shadow | tint  |
/// |-------------|--------|-------|
/// | navBar      | ×0.6   | ×1.00 |
/// | sheet       | ×1.0   | ×1.00 |
/// | floatingCard| ×1.2   | ×0.92 |
/// | overlay     | ×0.8   | ×0.95 |
///
/// 降级：`MediaQuery.disableAnimationsOf(context) == true` 或 [fallbackOpaque]
/// → 跳过 BackdropFilter，直接不透明 surfaceContainer（无模糊纯色）。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.level = GlassLevel.floatingCard,
    this.borderRadius,
    this.fallbackOpaque = false,
  });

  final Widget child;
  final GlassLevel level;

  /// 缺省按档位取值：navBar 用胶囊 28，其余用卡片 24。
  final BorderRadius? borderRadius;

  /// 强制降级为不透明表面（低端机 / 测试 / 显式静态场景）。
  final bool fallbackOpaque;

  /// 环影基础 α（浅/深），× 档位倍率。
  static const double _ambientAlphaLight = 0.10;
  static const double _ambientAlphaDark = 0.32;

  /// 关键影基础 α（浅/深），× 档位倍率。
  static const double _keyAlphaLight = 0.08;
  static const double _keyAlphaDark = 0.24;

  static double _shadowMul(GlassLevel level) => switch (level) {
        GlassLevel.navBar => 0.6,
        GlassLevel.sheet => 1.0,
        GlassLevel.floatingCard => 1.2,
        GlassLevel.overlay => 0.8,
      };

  static double _tintMul(GlassLevel level) => switch (level) {
        GlassLevel.navBar => 1.0,
        GlassLevel.sheet => 1.0,
        GlassLevel.floatingCard => 0.92,
        GlassLevel.overlay => 0.95,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    final radius = borderRadius ??
        (level == GlassLevel.navBar
            ? BorderRadius.circular(28)
            : BorderRadius.circular(AppRadius.cardValue));

    final tint = (dark ? GlassTokens.tintAlphaDark : GlassTokens.tintAlphaLight) *
        _tintMul(level);
    final highlight = dark
        ? GlassTokens.highlightAlphaDark
        : GlassTokens.highlightAlphaLight;
    final edge =
        dark ? GlassTokens.edgeAlphaDark : GlassTokens.edgeAlphaLight;
    final shadowMul = _shadowMul(level);
    final ambientA = (dark ? _ambientAlphaDark : _ambientAlphaLight) * shadowMul;
    final keyA = (dark ? _keyAlphaDark : _keyAlphaLight) * shadowMul;

    final decoration = BoxDecoration(
      color: scheme.surfaceContainerLow.withValues(alpha: tint.clamp(0.0, 1.0)),
      borderRadius: radius,
      gradient: LinearGradient(
        begin: const Alignment(-1.0, -0.35),
        end: const Alignment(1.0, 0.35),
        colors: [
          Colors.white.withValues(alpha: highlight),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.38],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: edge)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: ambientA.clamp(0.0, 1.0)),
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: keyA.clamp(0.0, 1.0)),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

    final degraded =
        fallbackOpaque || MediaQuery.disableAnimationsOf(context);
    final surface = degraded
        ? ClipRRect(
            borderRadius: radius,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: child,
            ),
          )
        : ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.compose(
                outer: ImageFilter.blur(
                    sigmaX: GlassTokens.sigma, sigmaY: GlassTokens.sigma),
                inner: ColorFilter.matrix(<double>[
                  // saturate(sat) 的 5x4 色彩矩阵
                  0.213 + 0.787 * GlassTokens.saturation,
                  0.715 - 0.715 * GlassTokens.saturation,
                  0.072 - 0.072 * GlassTokens.saturation,
                  0, 0, //
                  0.213 - 0.213 * GlassTokens.saturation,
                  0.715 + 0.285 * GlassTokens.saturation,
                  0.072 - 0.072 * GlassTokens.saturation,
                  0, 0, //
                  0.213 - 0.213 * GlassTokens.saturation,
                  0.715 - 0.715 * GlassTokens.saturation,
                  0.072 + 0.928 * GlassTokens.saturation,
                  0, 0, //
                  0, 0, 0, 1, 0,
                ]),
              ),
              child: Container(decoration: decoration, child: child),
            ),
          );
    return surface;
  }
}
