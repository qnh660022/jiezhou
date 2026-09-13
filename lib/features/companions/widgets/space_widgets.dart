/// 旅伴系列可复用组件（V2.6.6.2 §6.4）。
///
/// 三级视觉层次（SPEC）：
/// 1. Hero 层：空间名 headline(28) + 徽标胶囊 + 成员头像叠放 + 未读角标；
/// 2. 分区层：区块标题 title(22) + 分区卡 AppRadius.card(24)，区间距 Spacing.xxl；
/// 3. 条目层：左侧语义图标（圆角 12 容器 + 主题色低饱和底）+ 主文 body(15) /
///    副文 caption(13) + 右侧元信息（金额走 money_text，时间/状态走 caption）。
///
/// 硬约束：所有色值取当前主题 Scheme（禁止硬编码），暗色「石墨夜」必须同过验收；
/// 复用优先（section_header / stat_chip / avatar_badge / money_text /
/// primary_button / empty_state / skeleton_box），玻璃面只走既有路径。
library;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_account.dart';
import '../../../shared/widgets/avatar_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../space_actions.dart';

// ============================================================
// 条目层：角色徽标（owner 填充 / editor 描边 / viewer 浅底）
// ============================================================

class SpaceRoleBadge extends StatelessWidget {
  const SpaceRoleBadge({super.key, required this.role, this.size = AppFontSizes.caption});

  final String? role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = role ?? '';
    final (bg, fg, border) = switch (r) {
      SpaceRole.owner => (scheme.primary, scheme.onPrimary, null),
      SpaceRole.editor => (
          Colors.transparent,
          scheme.primary,
          scheme.primary.withValues(alpha: 0.7),
        ),
      SpaceRole.viewer => (
          scheme.primary.withValues(alpha: 0.12),
          scheme.primary,
          null,
        ),
      _ => (
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
          null,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.capsule,
        border: border == null ? null : Border.all(color: border, width: 1),
      ),
      child: Text(
        r.isEmpty ? '成员' : SpaceRole.label(r),
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// 成员头像叠放（最多 [max] 个 + 「+N」）。
class SpaceAvatarStack extends StatelessWidget {
  const SpaceAvatarStack({
    super.key,
    required this.names,
    this.max = 4,
    this.size = 26,
  });

  final List<String> names;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (names.isEmpty) return const SizedBox.shrink();
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - 9),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: AvatarBadge(name: shown[i], size: size - 4),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (size - 9),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Text('+$extra',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant)),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// 分区层：分区卡（统一圆角/内边距/间距）
// ============================================================

/// 旅伴系列分区卡：区块标题 title(22) + 卡（AppRadius.card 24），
/// 卡头右侧可选「管理 ›」次级入口（**禁止把四个区平铺成一张长列表**）。
class CompanionSectionCard extends StatelessWidget {
  const CompanionSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailingLabel,
    this.onTrailingTap,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xxl, Spacing.xl, Spacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall),
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
                        Text(trailingLabel ?? '管理',
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Material(
            color: scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLowest,
            borderRadius: AppRadius.card,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

/// 条目层：左侧语义图标容器（圆角 12 + 主题色低饱和底）。
class CompanionLeadingIcon extends StatelessWidget {
  const CompanionLeadingIcon({super.key, required this.icon, this.tint});

  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.primary;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

/// 条目层：三段式列表项（左图标 / 主副文 / 右侧元信息）。
class CompanionTile extends StatelessWidget {
  const CompanionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tint,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap?.call();
            }
          : null,
      borderRadius: AppRadius.button,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: Row(
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.45,
              child: CompanionLeadingIcon(icon: icon, tint: tint),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSizes.body,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Spacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 空间卡（旅伴中心 / 空间列表 / 首页置顶卡共用同一份样式）
// ============================================================

class SpaceCard extends ConsumerWidget {
  const SpaceCard({
    super.key,
    required this.space,
    required this.members,
    required this.myRole,
    this.unreadCount = 0,
    this.onTap,
  });

  final TravelSpace space;
  final List<SpaceMember> members;
  final String? myRole;
  final int unreadCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final names = [for (final m in members) m.displayName];
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!.call();
            },
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CompanionLeadingIcon(
                  icon: space.status == 'archived'
                      ? Icons.inventory_2_outlined
                      : Icons.groups_2_rounded,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: AppRadius.capsule,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.onError),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(space.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppFontSizes.body,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            )),
                      ),
                      const SizedBox(width: Spacing.sm),
                      SpaceRoleBadge(role: myRole),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MiniTag(
                        icon: Icons.flight_takeoff_rounded,
                        label: space.tripId == null ? '未关联行程' : '已关联行程',
                        active: space.tripId != null,
                      ),
                      _MiniTag(
                        icon: Icons.account_balance_wallet_rounded,
                        label: space.groupId == null ? '未关联账本' : '已关联账本',
                        active: space.groupId != null,
                      ),
                      if (members.isNotEmpty)
                        Text('${members.length} 位旅伴',
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            if (names.isNotEmpty) SpaceAvatarStack(names: names),
            const SizedBox(width: Spacing.xs),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label, required this.active});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.12 : 0.07),
        borderRadius: AppRadius.capsule,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================
// 新建空间向导（命名 → 可选关联行程 → 可选关联账本 → 创建）
// ============================================================

Future<String?> showCreateSpaceSheet(BuildContext context) => showDraggableSheet<String>(
      context: context,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      builder: (ctx, scrollController) =>
          _CreateSpaceSheet(scrollController: scrollController),
    );

class _CreateSpaceSheet extends ConsumerStatefulWidget {
  const _CreateSpaceSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_CreateSpaceSheet> createState() => _CreateSpaceSheetState();
}

class _CreateSpaceSheetState extends ConsumerState<_CreateSpaceSheet> {
  final _nameCtl = TextEditingController();
  String? _tripId;
  String? _groupId;
  int _step = 0;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = spaceErrorText('name_required'));
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final (spaceId, err) = await SpaceActions.createSpace(ref,
        name: name, tripId: _tripId, groupId: _groupId);
    if (!mounted) return;
    if (err.isNotEmpty) {
      setState(() {
        _busy = false;
        _error = spaceErrorText(err);
      });
      return;
    }
    Navigator.of(context).pop(spaceId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = ref.read(dbProvider);
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxl),
      children: [
        Text('新建旅伴空间', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Spacing.xs),
        Text('一程一空间：一个空间可以关联 1 个行程和 1 个账本，旅伴在空间里一起改行程、一起记账。',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Spacing.xl),

        // ① 命名
        _StepLabel(index: 1, text: '给空间起个名字', active: _step >= 0),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: _nameCtl,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: '例如「国庆京都行」',
            counterText: '',
          ),
          onChanged: (_) {
            if (_error.isNotEmpty) setState(() => _error = '');
          },
        ),
        const SizedBox(height: Spacing.lg),

        // ② 可选关联行程
        _StepLabel(index: 2, text: '关联行程（可选）', active: _step >= 1),
        const SizedBox(height: Spacing.sm),
        FutureBuilder<List<Trip>>(
          future: (db.select(db.trips)
                ..where((t) => t.archived.equals(false))
                ..orderBy([(t) => OrderingTerm.desc(t.startEpochDay)]))
              .get(),
          builder: (_, snap) {
            final trips = snap.data ?? const <Trip>[];
            if (trips.isEmpty) {
              return _EmptyHint(text: '还没有行程。可以先建空间，之后再关联。');
            }
            return Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final t in trips)
                  ChoiceChip(
                    label: Text('${t.emoji} ${t.name}'),
                    selected: _tripId == t.id,
                    onSelected: (_) => setState(
                        () => _tripId = _tripId == t.id ? null : t.id),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Spacing.lg),

        // ③ 可选关联账本
        _StepLabel(index: 3, text: '关联账本（可选）', active: _step >= 2),
        const SizedBox(height: Spacing.sm),
        FutureBuilder<List<Group>>(
          future: (db.select(db.groups)
                ..where((g) => g.archived.equals(false)))
              .get(),
          builder: (_, snap) {
            final groups = snap.data ?? const <Group>[];
            if (groups.isEmpty) {
              return _EmptyHint(text: '还没有账本。可以先建空间，之后再关联。');
            }
            return Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final g in groups)
                  ChoiceChip(
                    label: Text('${g.icon} ${g.name}'),
                    selected: _groupId == g.id,
                    onSelected: (_) => setState(
                        () => _groupId = _groupId == g.id ? null : g.id),
                  ),
              ],
            );
          },
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          Text(_error,
              style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
        ],
        const SizedBox(height: Spacing.xxl),
        PrimaryButton(
          label: _busy ? '创建中…' : '创建空间',
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: Spacing.sm),
        SecondaryButton(
          label: '取消',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _step = 2;
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.index, required this.text, required this.active});

  final int index;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Text('$index',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? scheme.onPrimary : scheme.onSurfaceVariant)),
        ),
        const SizedBox(width: Spacing.sm),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: AppFontSizes.caption,
          color: Theme.of(context).colorScheme.onSurfaceVariant));
}

// ============================================================
// 空间邀请码 sheet（生成 / 展示 / 复制 / 二维码）
// ============================================================

Future<void> showSpaceInviteSheet(
  BuildContext context, {
  required String spaceId,
  String spaceName = '',
}) =>
    showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      builder: (ctx, scrollController) => _SpaceInviteSheet(
        spaceId: spaceId,
        spaceName: spaceName,
        scrollController: scrollController,
      ),
    );

class _SpaceInviteSheet extends ConsumerStatefulWidget {
  const _SpaceInviteSheet({
    required this.spaceId,
    required this.spaceName,
    required this.scrollController,
  });

  final String spaceId;
  final String spaceName;
  final ScrollController scrollController;

  @override
  ConsumerState<_SpaceInviteSheet> createState() => _SpaceInviteSheetState();
}

class _SpaceInviteSheetState extends ConsumerState<_SpaceInviteSheet> {
  String _role = SpaceRole.editor;
  String? _code;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    // 24 小时有效期：邀请码是"拉人进空间"的短期凭证，长期有效会放大泄露风险；
    // 需要长期入口时重开本面板再生成一个即可（旧的仍有效，直到过期/撤销）。
    final (code, err) = await SpaceActions.createInvite(ref,
        spaceId: widget.spaceId, role: _role, ttlHours: 24);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _code = code.isEmpty ? null : code;
      _error = err.isEmpty ? '' : spaceErrorText(err);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xxl),
      children: [
        Text('邀请旅伴', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Spacing.xs),
        Text('对方输入这 6 位码（或扫二维码）即可加入'
            '${widget.spaceName.isEmpty ? '空间' : '「${widget.spaceName}」'}。',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Spacing.lg),
        Text('加入后的角色', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          children: [
            for (final r in const [SpaceRole.editor, SpaceRole.viewer])
              ChoiceChip(
                label: Text(SpaceRole.label(r)),
                selected: _role == r,
                onSelected: (_) {
                  setState(() => _role = r);
                  _generate();
                },
              ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_code != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xl, vertical: Spacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.input,
            ),
            child: Center(
              child: Text(
                _code!,
                style: TextStyle(
                  fontSize: AppFontSizes.headline,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text('24 小时内有效 · 角色：${SpaceRole.label(_role)}',
              style: TextStyle(
                  fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: '换一个',
                  onPressed: _busy ? null : _generate,
                ),
              ),
            ],
          ),
        ],
        if (_error.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          Text(_error,
              style: TextStyle(color: scheme.error, fontSize: AppFontSizes.caption)),
        ],
      ],
    );
  }
}

/// 空态（复用全局 EmptyState，保持文案与留白一致）。
Widget companionEmpty(String title, String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: EmptyState(emoji: '🧭', title: title, message: message),
    );
