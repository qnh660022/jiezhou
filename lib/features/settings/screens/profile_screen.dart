import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart'
    show currentUserEmailProvider, currentUserIdProvider, syncStatusProvider;
import '../../../data/sync/sync_models.dart' show SyncStatus, SyncStatusKind;
import '../../../features/desktop/desktop_utils.dart' show isDesktopWeb;
import '../../../platform/open_external.dart';
import '../../../shared/app_meta.dart';
import '../../../shared/check_update_dialog.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sync_status_capsule.dart'
    show syncStatusColor, syncStatusLabelText;
import '../../../shared/travel_quotes.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/tokens.dart';
import '../../ledger/ledger_providers.dart';
import '../../../shared/copy_tokens.dart';

/// 「我的」Tab 根页：大标题 + 用户卡 + 设置分组入口。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const String _appVersion = kAppVersionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 跟随全局主题即时刷新
    ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;

    if (isDesktopWeb(context)) {
      return _buildDesktop(context, ref, scheme);
    }

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
        // 用户卡（账号 + 云同步状态 + 云设置入口）
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
        // 分享与协作中心：邀请旅伴 / 只读分享链接 / 输入邀请码加团 / 局域网同步。
        // 此前这些入口散落且未登录时全隐藏，用户找不到（本轮补齐聚合入口）。
        _StaggerIn(
          index: 5,
          child: _ProfileTile(
            icon: Icons.ios_share_rounded,
            title: '分享与协作',
            subtitle: '邀请旅伴、只读分享链接、加入别人的账本',
            onTap: () => context.push('/profile/share'),
          ),
        ),
        if (!kIsWeb)
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
            icon: Icons.lock_outline_rounded,
            title: '启动锁',
            subtitle: '冷启动时用 6 位 PIN 解锁',
            onTap: () => context.push('/profile/app-lock'),
          ),
        ),
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
            icon: Icons.public,
            title: '官方网站',
            subtitle: kOfficialWebsite,
            onTap: () => openExternal(kOfficialWebsite),
          ),
        ),
        _StaggerIn(
          index: 10,
          child: _ProfileTile(
            icon: Icons.system_update_alt_rounded,
            title: '检查更新',
            onTap: () => showCheckUpdateDialog(context),
          ),
        ),
        _StaggerIn(
          index: 11,
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

  /// 桌面 Web 两列布局（大屏专属；手机保持单列）。
  Widget _buildDesktop(BuildContext context, WidgetRef ref, ColorScheme scheme) {
    final cardW = (DesktopLayout.contentMaxWidth - Spacing.lg) / 2;
    Widget section(String title, List<Widget> tiles) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Spacing.xl),
          SectionHeader(title: title),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.lg,
            runSpacing: Spacing.lg,
            children: [for (final t in tiles) SizedBox(width: cardW, child: t)],
          ),
        ],
      );
    }

    final budgetEnabled = ref.watch(budgetAlertsEnabledProvider).value ?? true;
    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: DesktopLayout.contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(Spacing.xxl),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.lg),
              child: Text('我的', style: AppTextStyles.display(scheme)),
            ),
            const _UserCard(),
            section('偏好设置', [
              _ProfileTile(
                icon: Icons.palette_outlined,
                title: '外观主题',
                trailing: const _ThemeSeedDots(),
                onTap: () => context.push('/profile/theme'),
              ),
              _ProfileTile(
                icon: Icons.notifications_active_outlined,
                title: '预算预警',
                subtitle: '超支时在账本页提醒',
                switchValue: budgetEnabled,
                onSwitchChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await ref.read(prefsRepoProvider).setBudgetAlertsEnabled(v);
                  ref.invalidate(budgetAlertsEnabledProvider);
                },
                onTap: () {},
              ),
              _ProfileTile(
                icon: Icons.menu_book_rounded,
                title: copy('guide.homeTitle'),
                subtitle: copy('guide.homeSub'),
                onTap: () => context.push('/guide'),
              ),
              _ProfileTile(
                icon: Icons.map_outlined,
                title: '地图服务设置',
                onTap: () => context.push('/trips/map-settings'),
              ),
              _ProfileTile(
                icon: Icons.groups_rounded,
                title: '记账团管理',
                onTap: () => context.push('/ledger/groups'),
              ),
              if (!kIsWeb)
                _ProfileTile(
                  icon: Icons.smart_toy_outlined,
                  title: 'AI 设置',
                  subtitle: '配置 AI 助手使用的模型服务',
                  onTap: () => context.push('/ai/settings'),
                ),
            ]),
            section('数据与隐私', [
              _ProfileTile(
                icon: Icons.lock_outline_rounded,
                title: '启动锁',
                subtitle: '冷启动时用 6 位 PIN 解锁',
                onTap: () => context.push('/profile/app-lock'),
              ),
              _ProfileTile(
                icon: Icons.shield_outlined,
                title: '隐私说明',
                onTap: () => context.push('/profile/privacy'),
              ),
              _ProfileTile(
                icon: Icons.cleaning_services_outlined,
                title: '清除本地缓存',
                subtitle: '清理临时文件与在线缓存，不影响数据',
                onTap: () => _confirmClearCache(context, ref),
              ),
              _ProfileTile(
                icon: Icons.restart_alt_rounded,
                title: '恢复默认设置',
                subtitle: '重置外观与开关，保留团/账单/行程',
                onTap: () => _confirmResetDefaults(context, ref),
              ),
            ]),
            section('其他', [
              _ProfileTile(
                icon: Icons.info_outline,
                title: '关于',
                trailing: Text('$_appVersion',
                    style: Theme.of(context).textTheme.labelSmall),
                onTap: () => context.push('/profile/about'),
              ),
              _ProfileTile(
                icon: Icons.public,
                title: '官方网站',
                subtitle: kOfficialWebsite,
                onTap: () => openExternal(kOfficialWebsite),
              ),
              _ProfileTile(
                icon: Icons.system_update_alt_rounded,
                title: '检查更新',
                onTap: () => showCheckUpdateDialog(context),
              ),
              _ProfileTile(
                icon: Icons.feedback_outlined,
                title: '意见反馈',
                onTap: () => _toast(context, '反馈入口：请通过应用商店留言或联系开发者'),
              ),
            ]),
            const SizedBox(height: Spacing.xl),
            const _TravelQuoteFooter(),
          ],
        ),
      ),
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

/// 用户卡：账号（邮箱/未登录）+ 同步状态 + 云设置入口。
/// 整卡可点 → 云端账号页（登录/账号管理/云设置）。
class _UserCard extends ConsumerWidget {
  const _UserCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(currentUserIdProvider);
    final email = ref.watch(currentUserEmailProvider);
    final status = ref.watch(syncStatusProvider).value ??
        const SyncStatus(kind: SyncStatusKind.unconfigured);

    final signedIn = uid != null;
    final accountText = signedIn ? (email ?? '已登录') : '未登录';
    final (subtitle, subtitleColor) = _subtitle(status, scheme, signedIn);
    final dotColor = syncStatusColor(scheme, status.kind);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, 0),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/profile/cloud'),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                  ),
                  child: const Text('👤', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(accountText,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: signedIn
                                      ? null
                                      : scheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: subtitleColor, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                // 同步状态小点 + 进入云设置
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, Color) _subtitle(
      SyncStatus status, ColorScheme scheme, bool signedIn) {
    if (!signedIn) return ('轻触登录，开启云端同步', scheme.onSurfaceVariant);
    return switch (status.kind) {
      SyncStatusKind.syncing => ('正在同步…', SemanticColors.warning),
      SyncStatusKind.offline => ('同步失败，轻触处理', SemanticColors.expense),
      SyncStatusKind.idle => status.lastSyncedAt == null
          ? ('云同步已就绪', SemanticColors.income)
          : (syncStatusLabelText(status), SemanticColors.income),
      _ => ('云端设置', scheme.onSurfaceVariant),
    };
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
                const SizedBox(height: Spacing.xs),
                Text(
                  copy(CopyTokens.profileQuotesNote),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
