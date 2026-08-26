import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/tokens.dart';

/// 主题外观页：浅色五套配色画廊 + 深色模式（石墨夜 / 跟随系统），点击即时全局换装。
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 跟随全局主题即时刷新
    ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const GlassAppBar(title: '主题外观'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.paddingOf(context).bottom + Spacing.huge + Spacing.xxl,
        ),
        children: [
          // 顶部说明卡
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
            child: _StaggerIn(
              index: 0,
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: AppRadius.card,
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xl,
                    vertical: Spacing.lg,
                  ),
                  child: Row(
                    children: [
                      const Text('🎨', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('六套旅途配色',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text('点击即刻换装，选择会自动记住',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 浅色五卡画廊
          const SectionHeader(title: '主题色'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            mainAxisSpacing: Spacing.sm,
            crossAxisSpacing: Spacing.sm,
            childAspectRatio: 0.78,
            children: [
              _StaggerIn(index: 1, child: _ThemePreviewCard(themeKey: ThemeKeys.green)),
              _StaggerIn(index: 2, child: _ThemePreviewCard(themeKey: ThemeKeys.blue)),
              _StaggerIn(index: 3, child: _ThemePreviewCard(themeKey: ThemeKeys.orange)),
              _StaggerIn(index: 4, child: _ThemePreviewCard(themeKey: ThemeKeys.pink)),
              _StaggerIn(index: 5, child: _ThemePreviewCard(themeKey: ThemeKeys.purple)),
            ],
          ),
          // 深色模式两张选项卡
          const SectionHeader(title: '深色模式'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.66,
                    child: _StaggerIn(
                      index: 6,
                      child: _ThemePreviewCard(
                        themeKey: ThemeKeys.dark,
                        subtitle: '始终使用深色',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.66,
                    child: _StaggerIn(
                      index: 7,
                      child: _ThemePreviewCard(
                        themeKey: ThemeKeys.system,
                        subtitle: '随系统亮暗自动切换',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张主题预览卡：迷你样机 + 名称（可选副标题），选中描边 + 右上角对勾徽标。
class _ThemePreviewCard extends ConsumerWidget {
  const _ThemePreviewCard({required this.themeKey, this.subtitle});

  final String themeKey;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeProvider) == themeKey;
    final scheme = Theme.of(context).colorScheme;
    final mockScheme = AppSchemes.schemeFor(themeKey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(themeProvider.notifier).setTheme(themeKey);
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildMockup(scheme)),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ThemeKeys.labels[themeKey]!,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: Spacing.sm,
                  right: Spacing.sm,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mockScheme.primary,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: mockScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡内样机：跟随系统用亮暗分屏，其余按 key 取对应配色方案
  Widget _buildMockup(ColorScheme pageScheme) {
    if (themeKey == ThemeKeys.system) {
      return _SystemSplitMockup(pageScheme: pageScheme);
    }
    return _MiniMockup(mockScheme: AppSchemes.schemeFor(themeKey));
  }
}

/// 迷你界面样机：全部颜色取自传入配色方案的语义角色
class _MiniMockup extends StatelessWidget {
  const _MiniMockup({
    required this.mockScheme,
    this.borderRadius = AppRadius.input,
  });

  final ColorScheme mockScheme;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: mockScheme.surfaceContainerLowest,
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.all(Spacing.sm),
      child: Column(
        children: [
          // 顶栏
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: mockScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // 头像圆点
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mockScheme.primaryContainer,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: mockScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FractionallySizedBox(
            widthFactor: .8,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: mockScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FractionallySizedBox(
            widthFactor: .6,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: mockScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: FractionallySizedBox(
              widthFactor: .55,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: mockScheme.primary,
                  borderRadius: AppRadius.capsule,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「跟随系统」专用样机：左半薄荷绿浅色 / 右半石墨夜深色，中央叠加亮暗切换徽标。
class _SystemSplitMockup extends StatelessWidget {
  const _SystemSplitMockup({required this.pageScheme});

  final ColorScheme pageScheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.input,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniMockup(
                  mockScheme: AppSchemes.schemeFor(ThemeKeys.green),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              Expanded(
                child: _MiniMockup(
                  mockScheme: AppSchemes.schemeFor(ThemeKeys.dark),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ],
          ),
          Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pageScheme.surfaceContainerLowest,
              ),
              child: Icon(
                Icons.brightness_6,
                size: 14,
                color: pageScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表 stagger 入场：淡入 + 轻微上移，按 index 错峰（本地轻量实现）
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  static const double _stepPerIndex = 0.06;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560))
        ..forward();

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      (widget.index * _stepPerIndex).clamp(0.0, 0.6),
      1.0,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
