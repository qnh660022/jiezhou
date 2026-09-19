import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 统一玻璃表面 —— 全 App 毛玻璃**唯一**实现。
///
/// V2.8.3.1 重校准（iOS 26 Liquid Glass 最佳实践）：
/// 1. **材质分档**：GlassLevel 映射到三个材质档（thin / regular / thick），
///    各档独立 σ 与 tint —— 顶栏透滚动内容（thin），Sheet 压背景保读性（thick）；
/// 2. **去饱和**：模糊后 saturate 0.92，把背景高饱和色斑中和为柔光（旧 1.35 是
///    「脏水感」根因之一）；
/// 3. **双描边**：外圈 outlineVariant 深色 hairline（在浅背景上勾出轮廓）
///    + 内圈白描边（受光环）+ 顶边内高光；
/// 4. **层级规则**：玻璃是悬浮层专属，**禁止嵌套**（玻璃上不放玻璃、不放
///    半透明条目面）——嵌套时 debug 告警。
///
/// 结构（外→内）：
/// ```
/// ClipRRect(borderRadius)
///   └ BackdropFilter(ImageFilter.compose(blur(σtier,σtier), ColorFilter.saturate(sat)))
///       └ Container(decoration: tint底 + 对角柔光 + 外圈深 hairline + 双层阴影,
///                   foregroundDecoration: 内圈白描边 + 顶边受光高光)
///           └ child
/// ```
/// 档位修正表（阴影倍率 / tint 倍率）：
/// | level       | tier    | shadow | tint  |
/// |-------------|---------|--------|-------|
/// | navBar      | thin    | ×0.6   | ×1.00 |
/// | sheet       | thick   | ×1.0   | ×1.00 |
/// | floatingCard| regular | ×1.2   | ×0.92 |
/// | overlay     | thick   | ×0.8   | ×0.95 |
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
  static const double _ambientAlphaLight = 0.13;
  static const double _ambientAlphaDark = 0.32;

  /// 关键影基础 α（浅/深），× 档位倍率。
  static const double _keyAlphaLight = 0.06;
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

    assert(() {
      if (fallbackOpaque) return true;
      final nested = context.findAncestorWidgetOfExactType<GlassSurface>();
      if (nested != null) {
        // V2.8.3.1 层级规则：玻璃不能采样另一块玻璃（iOS 26 Liquid Glass）。
        // 嵌套只会得到双份模糊成本 + 发灰观感；条目应改实色，见 GlassTokens 注释。
        debugPrint(
            '⚠️ GlassSurface 嵌套告警：玻璃上不应再放玻璃（level=$level），'
            '请把内层改为实色 surfaceContainerHigh。');
      }
      return true;
    }());

    final radius = borderRadius ??
        (level == GlassLevel.navBar
            ? BorderRadius.circular(28)
            : BorderRadius.circular(AppRadius.cardValue));

    // 材质档位：σ 与 tint 按档取值，不再全局单值。
    final sigma = switch (level) {
      GlassLevel.navBar => GlassTokens.sigmaThin,
      GlassLevel.floatingCard => GlassTokens.sigmaRegular,
      GlassLevel.sheet || GlassLevel.overlay => GlassTokens.sigmaThick,
    };
    final tierTint = dark
        ? switch (level) {
            GlassLevel.navBar => GlassTokens.tintAlphaThinDark,
            GlassLevel.floatingCard => GlassTokens.tintAlphaRegularDark,
            GlassLevel.sheet || GlassLevel.overlay =>
              GlassTokens.tintAlphaThickDark,
          }
        : switch (level) {
            GlassLevel.navBar => GlassTokens.tintAlphaThinLight,
            GlassLevel.floatingCard => GlassTokens.tintAlphaRegularLight,
            GlassLevel.sheet || GlassLevel.overlay =>
              GlassTokens.tintAlphaThickLight,
          };

    final tint = tierTint * _tintMul(level);
    final highlight = dark
        ? GlassTokens.highlightAlphaDark
        : GlassTokens.highlightAlphaLight;
    final topSheen = dark
        ? GlassTokens.topSheenAlphaDark
        : GlassTokens.topSheenAlphaLight;
    final innerEdge =
        dark ? GlassTokens.innerEdgeDark : GlassTokens.innerEdgeLight;
    final outerEdge = dark
        ? GlassTokens.outerEdgeAlphaDark
        : GlassTokens.outerEdgeAlphaLight;
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
        stops: const [0, 0.30],
      ),
      // 外圈深色 hairline：负责在浅色页面上勾出玻璃轮廓（旧全周白描边在
      // 白底上不可见，是「边界糊掉」的根因）。
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: outerEdge),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: ambientA.clamp(0.0, 1.0)),
          blurRadius: 36,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: keyA.clamp(0.0, 1.0)),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    // 前景层：内圈白受光环 + 顶边受光高光（画在内容之上，代替 inset 阴影）。
    final foregroundDecoration = BoxDecoration(
      borderRadius: radius,
      border: Border.all(color: Colors.white.withValues(alpha: innerEdge)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: const Alignment(0.0, 0.14),
        colors: [
          Colors.white.withValues(alpha: topSheen),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 1.0],
      ),
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
                outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
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
              child: Container(
                decoration: decoration,
                foregroundDecoration: foregroundDecoration,
                child: child,
              ),
            ),
          );
    return surface;
  }
}
