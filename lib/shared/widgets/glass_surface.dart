import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 统一玻璃表面 —— 全 App 毛玻璃**唯一**实现。
///
/// **V2.8.3.4：玻璃特效全 App 撤销，只保留悬浮胶囊底栏。**
/// 实时模糊在任何底色上都容易显脏，且在滚动内容之上会出现「发灰/发白」观感；
/// 因此 [blur] 默认 `false` —— 除底栏（`FloatingCapsuleNavBar` 显式传
/// `blur=true`）外，所有调用点一律落到**实色表面**分支（不透明底色 + 细描边
/// + 双层柔影，无 BackdropFilter、无白受光渐变）。组件层保留全部档位 API，
/// 便于将来单独回收：把某个调用点改成 `blur=true` 即可恢复该处玻璃。
/// （门禁：`test/features/v2834_fixes_test.dart` 会扫全 `lib` 断言只有底栏
/// 出现该开关，因此注释里也不写带冒号的字面量。）
///
/// 以下为玻璃分支（仅底栏）的实现说明，逻辑自 V2.8.3.1 起未变：
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
///       └ Container(decoration: tint底 + 对角柔光(内容之下) + 外圈深 hairline + 双层阴影,
///                   foregroundDecoration: 1px 低α白受光环——绝不放白色渐变幕)
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
///
/// 说明：`blur == false`（默认）时走与降级同族的**实色分支**，区别只在底色
/// 取值（卡片用最亮容器色、顶栏/弹层用 surface），见 [_solidColor]。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.level = GlassLevel.floatingCard,
    this.borderRadius,
    this.fallbackOpaque = false,
    this.blur = false,
  });

  final Widget child;
  final GlassLevel level;

  /// 缺省按档位取值：navBar 用胶囊 28，其余用卡片 24。
  final BorderRadius? borderRadius;

  /// 强制降级为不透明表面（低端机 / 测试 / 显式静态场景）。
  final bool fallbackOpaque;

  /// 是否启用实时模糊（V2.8.3.4）。
  ///
  /// 默认 `false` = 实色表面。**全 App 只有悬浮胶囊底栏传 `true`**；
  /// 新增调用点不要开，除非产品明确要求某一处恢复玻璃。
  final bool blur;

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

  /// 实色分支底色（V2.8.3.4）。
  ///
  /// * 顶栏/弹层：`surface`（与页面同族但完全不透明，压住滚动内容）；
  /// * 卡片：浅色取 `surfaceContainerLowest`（最亮，即「白卡」），
  ///   深色取 `surfaceContainerHigh`（抬升感），与页面底明确分层。
  static Color _solidColor(ColorScheme scheme, GlassLevel level) =>
      switch (level) {
        GlassLevel.navBar ||
        GlassLevel.sheet ||
        GlassLevel.overlay =>
          scheme.surface,
        GlassLevel.floatingCard => scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
      };

  /// V2.8.3.1 层级规则：玻璃不能采样另一块玻璃（iOS 26 Liquid Glass）。
  ///
  /// 嵌套只会得到双份模糊成本 + 发灰观感；条目应改实色，见 GlassTokens 注释。
  /// 只在玻璃分支（`blur=true`）下做检查。
  bool _checkNestedGlass(bool useGlass, BuildContext context) {
    if (!useGlass) return true;
    if (context.findAncestorWidgetOfExactType<GlassSurface>() != null) {
      debugPrint(
          '⚠️ GlassSurface 嵌套告警：玻璃上不应再放玻璃（level=$level），'
          '请把内层改为实色 surfaceContainerHigh。');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    // V2.8.3.4：玻璃只在显式 `blur=true` 时启用（全 App 仅悬浮胶囊底栏）。
    final useGlass = blur && !fallbackOpaque;
    assert(_checkNestedGlass(useGlass, context));

    final radius = borderRadius ??
        (level == GlassLevel.navBar
            ? BorderRadius.circular(28)
            : BorderRadius.circular(AppRadius.cardValue));

    // 阴影倍率两分支共用：实色卡同样需要柔影抬升，否则与页面底糊在一起。
    final shadowMul = _shadowMul(level);
    final ambientA = (dark ? _ambientAlphaDark : _ambientAlphaLight) * shadowMul;
    final keyA = (dark ? _keyAlphaDark : _keyAlphaLight) * shadowMul;
    final shadows = <BoxShadow>[
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
    ];

    // ---- 实色表面（默认分支：全 App 除底栏外都走这里） ----
    if (!useGlass) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            color: _solidColor(scheme, level),
            borderRadius: radius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: shadows,
          ),
          child: child,
        ),
      );
    }

    // ---- 玻璃表面（仅底栏） ----

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
    final innerEdge =
        dark ? GlassTokens.innerEdgeDark : GlassTokens.innerEdgeLight;
    // 外圈深色 hairline 按档位分强度：吸顶栏（thin，全宽）最忌重描边。
    final outerEdge = dark
        ? switch (level) {
            GlassLevel.navBar => GlassTokens.outerEdgeThinDark,
            GlassLevel.floatingCard => GlassTokens.outerEdgeRegularDark,
            GlassLevel.sheet || GlassLevel.overlay =>
              GlassTokens.outerEdgeThickDark,
          }
        : switch (level) {
            GlassLevel.navBar => GlassTokens.outerEdgeThinLight,
            GlassLevel.floatingCard => GlassTokens.outerEdgeRegularLight,
            GlassLevel.sheet || GlassLevel.overlay =>
              GlassTokens.outerEdgeThickLight,
          };
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
      // 外圈深色 hairline：负责在浅色页面上勾出玻璃轮廓。
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: outerEdge),
      ),
      boxShadow: shadows,
    );

    // V2.8.3.2 发白事故修正：前景层只保留 1px 低 α 白受光环。
    // 3.1 曾在此叠加「顶边白色渐变幕」（白 α0.5，且 Alignment 坐标算错
    // 实际覆盖 57% 高度）——前景层画在内容之上，导致全 App 玻璃同时发白；
    // 且它与 tint / 对角柔光同向叠白。现彻底移除渐变幕，受光感由
    // 背景对角柔光（内容之下）+ 低 α 内圈描边承担。
    final foregroundDecoration = BoxDecoration(
      borderRadius: radius,
      border: Border.all(color: Colors.white.withValues(alpha: innerEdge)),
    );

    // V2.8.3.4：实色分支已在上面 return，此处必然是 `blur=true` 且非
    // `fallbackOpaque`，直接走实时模糊（不再需要 degraded 兜底判断）。
    return ClipRRect(
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
  }
}
