/// 主题页（V2.6 任务3）：12 张直选卡（浅 5 区 / 深 6 区 + 跟随系统卡）
/// + 字体风格、圆角密度两段旋钮。换装时 320ms 渐变蒙版转场（§5.6）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/tokens.dart';

class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});

  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mask = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  Future<void> _select(ThemeFamily family, ThemeBrightnessMode brightness) async {
    if (_mask.isAnimating) return;
    final curFamily = ref.read(themeFamilyProvider);
    final curBright = ref.read(themeBrightnessProvider);
    final switchingDepth =
        (curFamily != family) && (curBright != brightness);
    _mask.value = 0;
    if (switchingDepth) {
      // 浅↔深：蒙版淡入 → 换装 → 蒙版淡出（§5.6）
      await _mask.forward();
      await ref.read(themeFamilyProvider.notifier).set(family);
      await ref.read(themeBrightnessProvider.notifier).set(brightness);
      await _mask.reverse();
    } else {
      // 同亮度档：先换装再轻蒙版一闪
      await ref.read(themeFamilyProvider.notifier).set(family);
      await ref.read(themeBrightnessProvider.notifier).set(brightness);
      await _mask.forward();
      await _mask.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(themeFamilyProvider);
    final brightness = ref.watch(themeBrightnessProvider);
    final fontMode = ref.watch(fontStyleProvider);
    final radius = ref.watch(radiusDensityProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // V2.9.0:次级页顶栏统一 GlassAppBar(原裸 AppBar)。
      appBar: GlassAppBar(title: '主题外观'),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            _sectionLabel(context, '浅色', Icons.wb_sunny_rounded),
            _cardGrid(ThemeStyles.lightStyles
                .map((s) => (
                      style: s,
                      selected: _isSelected(family, brightness, s),
                    ))
                .toList()),
            const SizedBox(height: Spacing.lg),
            _sectionLabel(context, '深色', Icons.dark_mode_rounded),
            // V2.9.0:「跟随系统」从深色栅格里拆出,单独一行置于分组顶部
            // (原塞在 3 列栅格里,宽度被压缩且语义上不属于「深色」)。
            _SystemCard(
              selected: brightness == ThemeBrightnessMode.system,
              onTap: () =>
                  _select(ref.read(themeFamilyProvider), ThemeBrightnessMode.system),
            ),
            const SizedBox(height: Spacing.md),
            _cardGrid(ThemeStyles.darkStyles
                .map((s) => (
                      style: s,
                      selected: _isSelected(family, brightness, s),
                    ))
                .toList()),
            const SizedBox(height: Spacing.lg),
            Text(copy(CopyTokens.themeSubtitle),
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: AppFontSizes.caption)),
            const SizedBox(height: Spacing.xl),
            Text('标题字体', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            SegmentedButton<FontMode>(
              segments: const [
                ButtonSegment(value: FontMode.serif, label: Text('衬线书卷')),
                ButtonSegment(value: FontMode.modern, label: Text('现代无衬线')),
              ],
              selected: {fontMode},
              onSelectionChanged: (s) =>
                  ref.read(fontStyleProvider.notifier).set(s.first),
            ),
            const SizedBox(height: Spacing.xl),
            Text('圆角密度', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            SegmentedButton<RadiusDensity>(
              segments: const [
                ButtonSegment(value: RadiusDensity.soft, label: Text('柔和')),
                ButtonSegment(value: RadiusDensity.standard, label: Text('标准')),
                ButtonSegment(value: RadiusDensity.clean, label: Text('利落')),
              ],
              selected: {radius},
              onSelectionChanged: (s) =>
                  ref.read(radiusDensityProvider.notifier).set(s.first),
            ),
            const SizedBox(height: Spacing.huge),
          ],
        ),
        // 换装转场蒙版（§5.6）：320ms 渐变；深浅切换用亮度蒙版
        FadeTransition(
          opacity: _mask,
          child: IgnorePointer(
            child: Container(
              color: (brightness == ThemeBrightnessMode.dark ||
                      family == ThemeFamily.night)
                  ? Colors.black.withValues(alpha: 0.72)
                  : scheme.primary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ]),
    );
  }

  bool _isSelected(
      ThemeFamily family, ThemeBrightnessMode brightness, ThemeStyle style) {
    if (style.brightness == Brightness.light) {
      return family.name == style.family &&
          brightness != ThemeBrightnessMode.dark &&
          family != ThemeFamily.night &&
          brightness != ThemeBrightnessMode.system;
    }
    // 深色卡：night 族常驻深色；其他族仅当 brightness=dark
    return family.name == style.family &&
        (brightness == ThemeBrightnessMode.dark || family == ThemeFamily.night);
  }

  Widget _sectionLabel(BuildContext context, String label, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Spacing.md),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: Spacing.sm),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );

  Widget _cardGrid(List<({ThemeStyle? style, bool selected})> cards) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        mainAxisSpacing: Spacing.md,
        crossAxisSpacing: Spacing.md,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.55,
        children: [
          for (final card in cards)
            if (card.style != null)
              _ThemeCard(
                style: card.style!,
                selected: card.selected,
                onTap: () => _select(
                    ThemeFamily.values
                        .firstWhere((f) => f.name == card.style!.family),
                    card.style!.brightness == Brightness.dark
                        ? ThemeBrightnessMode.dark
                        : ThemeBrightnessMode.light),
              )
            else
              _SystemCard(
                selected: card.selected,
                onTap: () => _select(
                    ref.read(themeFamilyProvider), ThemeBrightnessMode.system),
              ),
        ],
      );
    });
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final ThemeStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Spacing.lg),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: style.signatureGradient,
            ),
            borderRadius: BorderRadius.circular(Spacing.lg),
            border: selected
                ? Border.all(color: scheme.primary, width: 3)
                : Border.all(color: scheme.outlineVariant, width: 1),
            boxShadow: style.cardKind == CardKind.softShadow
                ? [BoxShadow(color: scheme.shadow.withValues(alpha: 0.2), blurRadius: 8)]
                : null,
          ),
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(style.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: AppFontSizes.bodyLarge)),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
              ]),
              const Spacer(),
              Row(children: [
                if (style.serifHeadline)
                  const Padding(
                    padding: EdgeInsets.only(right: Spacing.sm),
                    child: Icon(Icons.menu_book_rounded,
                        color: Colors.white70, size: 16),
                  ),
                Text('节律 ${style.motionTempo.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Spacing.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Spacing.lg),
            border: selected
                ? Border.all(color: scheme.primary, width: 3)
                : Border.all(color: scheme.outlineVariant, width: 1),
          ),
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.brightness_auto_rounded,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 28),
              const SizedBox(height: Spacing.sm),
              Text('跟随系统',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppFontSizes.body,
                      color: scheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
