import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/travel_quotes.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/tokens.dart';
import '../../ledger/ledger_providers.dart';

/// 「我的」Tab 根页：大标题 + 用户卡 + 设置分组入口。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const String _appVersion = 'v2.1.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 跟随全局主题即时刷新
    ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom + Spacing.huge + Spacing.xxl,
      ),
      children: [
        // 页面大标题（本地实现，样式对齐各 Tab 根页的 display 头部）
        Padding(
          padding: EdgeInsets.only(
            left: Spacing.xl,
            right: Spacing.lg,
            top: MediaQuery.paddingOf(context).top + Spacing.md,
            bottom: Spacing.sm,
          ),
          child: Text('我的', style: AppTextStyles.display(scheme)),
        ),
        // 用户卡
        _StaggerIn(index: 0, child: const _UserCard()),
        // 偏好设置分组
        const SectionHeader(title: '偏好设置'),
        _StaggerIn(
          index: 1,
          child: _ProfileTile(
            icon: Icons.palette_outlined,
            title: '外观主题',
            trailing: const _ThemeSeedDots(),
            onTap: () => context.push('/profile/theme'),
          ),
        ),
        _StaggerIn(
          index: 2,
          child: Consumer(
            builder: (context, ref, _) {
              final enabled =
                  ref.watch(budgetAlertsEnabledProvider).value ?? true;
              return _ProfileTile(
                icon: Icons.notifications_active_outlined,
                title: '预算预警',
                subtitle: '超支时在账本页提醒',
                switchValue: enabled,
                onSwitchChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await ref.read(prefsRepoProvider).setBudgetAlertsEnabled(v);
                  ref.invalidate(budgetAlertsEnabledProvider);
                },
                onTap: () {},
              );
            },
          ),
        ),
        _StaggerIn(
          index: 3,
          child: _ProfileTile(
            icon: Icons.map_outlined,
            title: '地图服务设置',
            onTap: () => context.push('/trips/map-settings'),
          ),
        ),
        _StaggerIn(
          index: 4,
          child: _ProfileTile(
            icon: Icons.groups_rounded,
            title: '记账团管理',
            onTap: () => context.push('/ledger/groups'),
          ),
        ),
        _StaggerIn(
          index: 5,
          child: _ProfileTile(
            icon: Icons.smart_toy_outlined,
            title: 'AI 设置',
            subtitle: '配置 AI 助手使用的模型服务',
            onTap: () => context.push('/ai/settings'),
          ),
        ),
        // 数据与隐私分组
        const SectionHeader(title: '数据与隐私'),
        _StaggerIn(
          index: 6,
          child: _ProfileTile(
            icon: Icons.shield_outlined,
            title: '隐私说明',
            onTap: () => context.push('/profile/privacy'),
          ),
        ),
        _StaggerIn(
          index: 6,
          child: _ProfileTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除本地缓存',
            subtitle: '清理临时文件与在线缓存，不影响数据',
            onTap: () => _confirmClearCache(context, ref),
          ),
        ),
        _StaggerIn(
          index: 7,
          child: _ProfileTile(
            icon: Icons.restart_alt_rounded,
            title: '恢复默认设置',
            subtitle: '重置外观与开关，保留团/账单/行程',
            onTap: () => _confirmResetDefaults(context, ref),
          ),
        ),
        // 其他分组
        const SectionHeader(title: '其他'),
        _StaggerIn(
          index: 8,
          child: _ProfileTile(
            icon: Icons.info_outline,
            title: '关于',
            trailing: Text('$_appVersion',
                style: Theme.of(context).textTheme.labelSmall),
            onTap: () => context.push('/profile/about'),
          ),
        ),
        _StaggerIn(
          index: 9,
          child: _ProfileTile(
            icon: Icons.system_update_alt_rounded,
            title: '检查更新',
            onTap: () => _toast(context, '当前已是最新版本'),
          ),
        ),
        _StaggerIn(
          index: 10,
          child: _ProfileTile(
            icon: Icons.feedback_outlined,
            title: '意见反馈',
            onTap: () => _toast(context, '反馈入口：请通过应用商店留言或联系开发者'),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        // 底部旅途哲理文案：每次进入/下拉刷新都不一样，仅 UI 展示
        const _TravelQuoteFooter(),
      ],
    );
  }

  void _toast(BuildContext context, String message) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(BuildContext context, String title, String message) async {
    HapticFeedback.lightImpact();
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _confirmClearCache(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context, '清除本地缓存',
        '将清理临时文件与在线缓存。你的行程、清单和账本数据不受影响，确定继续？');
    if (!ok || !context.mounted) return;
    await ref.read(prefsRepoProvider).clearTemporaryCache();
    if (!context.mounted) return;
    _toast(context, '缓存已清除');
  }

  Future<void> _confirmResetDefaults(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context, '恢复默认设置',
        '将把外观主题与预警开关重置为默认，已保存的团、账单和行程不受影响。确定继续？');
    if (!ok || !context.mounted) return;
    await ref.read(themeProvider.notifier).setTheme(ThemeKeys.green);
    await ref.read(prefsRepoProvider).setBudgetAlertsEnabled(true);
    ref.invalidate(budgetAlertsEnabledProvider);
    if (!context.mounted) return;
    _toast(context, '已恢复默认设置');
  }
}

/// 用户卡：圆形头像（主色浅底 emoji）+ 名称 + slogan
class _UserCard extends StatelessWidget {
  const _UserCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, 0),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                ),
                child: const Text('👤', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('旅行者', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '记录每一段旅途',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 六套配色种子色小圆点（外观主题入口的 trailing 预览）
class _ThemeSeedDots extends StatelessWidget {
  const _ThemeSeedDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seed in ThemeKeys.previewSeeds.values)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(left: Spacing.xs),
            decoration: BoxDecoration(color: seed, shape: BoxShape.circle),
          ),
      ],
    );
  }
}

/// 设置项 tile：Material + InkWell 圆角，点击带触觉反馈。
/// 传 [onSwitchChanged] 时以 Switch 作为 trailing（onTap 仍可保留为整卡点击）。
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.switchValue,
    this.onSwitchChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSwitch = onSwitchChanged != null;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.sm),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.input,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.lg,
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: scheme.primary),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasSwitch) ...[
                  Switch.adaptive(
                    value: switchValue ?? false,
                    activeColor: scheme.primary,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      onSwitchChanged!(v);
                    },
                  ),
                ] else if (trailing != null)
                  trailing!
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
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

/// 底部旅途哲理文案：随机取一条，仅 UI 展示，不进任何模型上下文。
class _TravelQuoteFooter extends StatefulWidget {
  const _TravelQuoteFooter();

  @override
  State<_TravelQuoteFooter> createState() => _TravelQuoteFooterState();
}

class _TravelQuoteFooterState extends State<_TravelQuoteFooter> {
  late var _quote = randomTravelQuote();

  /// 下拉/再次进入时换一条
  void _refresh() {
    setState(() => _quote = randomTravelQuote());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _refresh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.xxl, Spacing.md, Spacing.xxl, Spacing.md),
          // 关键：RefreshIndicator 的 Stack 会给子级宽松宽度约束，导致 Column
          // 收缩成最长一行的宽度、整块贴着左边。强制占满整行宽度后，
          // 两个 Text 的 textAlign.center 才会相对屏幕宽度真正居中。
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Icon(Icons.eco_outlined,
                    size: 20, color: scheme.primary.withValues(alpha: 0.6)),
                const SizedBox(height: Spacing.sm),
                Text(
                  '“${_quote.text}”',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
                ),
                const SizedBox(height: 2),
                Text(
                  '—— ${_quote.by} · 旅途哲思',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
