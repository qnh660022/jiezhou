import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/member_avatar.dart';
import 'invite_companion_sheet.dart';
import '../widgets/stagger_in.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../theme/app_icons.dart';

/// 👤 成员管理：八色轮换头像、新增改名、被引用拦截。
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    // 用已解析的当前团取 id：比裸 activeGroupId 流更稳，
    // 避免刚建团/切团后流尚未同步导致 FAB 禁用或页面异常。
    final groupId = ref.watch(activeGroupProvider).value?.id;
    // S4：个人账本成员固定为「我」，隐藏添加成员入口与邀请入口。
    final personal = ref.watch(activeGroupProvider).value?.isPersonal ?? false;
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];

    return Scaffold(
      appBar: GlassAppBar(title: '成员管理'),
      // FAB 用 Stack 手动定位：外层 HomeShell 的悬浮胶囊底栏会盖住
      // Scaffold 默认 endFloat 的 FAB（extendBody:true 导致 body 延伸到屏幕底部）。
      body: Stack(
        children: [
          Positioned.fill(
            child: membersAsync.isLoading
                ? ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(Spacing.xl),
                    children: const [
                      SkeletonListTile(),
                      SkeletonListTile(),
                      SkeletonListTile(),
                    ],
                  )
                : membersAsync.when(
                    loading: () => ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(Spacing.xl),
                      children: const [
                        SkeletonListTile(),
                        SkeletonListTile(),
                        SkeletonListTile(),
                      ],
                    ),
                    // V2.9.0:错误态收口 ErrorState,提供真实重试入口。
                    error: (e, s) => ErrorState(
                      onRetry: () => ref.invalidate(membersProvider),
                      error: e,
                      stackTrace: s,
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return ListView(children: [
                          if (!personal) _InviteTile(groupId: groupId),
                          const EmptyState(
                            icon: AppIcons.members,
                            title: '还没有成员',
                            message: 'AA 记账至少要有两位同行人哦',
                          ),
                        ]);
                      }
                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          Spacing.xl,
                          Spacing.md,
                          Spacing.xl,
                          AppBottomLayout.withSafeArea(
                            context,
                            AppBottomLayout.contentTail,
                          ),
                        ),
                        children: [
                          if (!personal) _InviteTile(groupId: groupId),
                          StaggerIn(index: 0, child: PalettePreview()),
                          const SizedBox(height: Spacing.lg),
                          for (var i = 0; i < list.length; i++)
                            StaggerIn(
                              index: i + 1,
                              child: MemberRow(
                                member: list[i],
                                expenseCount: countMemberReferences(
                                    expenses, list[i].id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          if (!personal)
            Positioned(
              right: Spacing.xl,
              bottom: AppBottomLayout.withSafeArea(
                context,
                AppBottomLayout.actionButtonOffset,
              ),
              child: FloatingActionButton.extended(
                heroTag: 'fab-member-add',
                onPressed: groupId == null
                    ? null
                    : () => _addMemberSheet(context, ref, groupId),
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('加成员'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addMemberSheet(BuildContext context, WidgetRef ref, String groupId) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController();
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.42,
      minChildSize: 0.32,
      builder: (sheetContext, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl,
            Spacing.xxl + MediaQuery.viewInsetsOf(sheetContext).bottom),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text('添加成员', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.sm),
          Text('颜色会按加入顺序自动从八色盘里轮换',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Spacing.lg),
          TextField(
              controller: controller,
              autofocus: true,
              maxLength: 12,
              // V2.9.0:输入框提示 —— 名字留空时按钮置灰,不再静默 return。
              decoration: const InputDecoration(
                labelText: 'TA 的名字或称呼',
                helperText: '填好名字后「加入」才会亮起',
              ),
          ),
          const SizedBox(height: Spacing.lg),
          // V2.9.0:名为空时按钮禁用（监听输入框实时置灰）。
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSubmit = value.text.trim().isNotEmpty;
              return FilledButton(
              onPressed: canSubmit
                  ? () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;
                      Navigator.of(sheetContext).pop();
                      HapticFeedback.lightImpact();
                      try {
                        await addMember(ref, groupId, name);
                      } catch (e, s) {
                        debugPrint('addMember failed: $e\n$s');
                        if (context.mounted) {
                          showAppSnackBar(context, '添加失败，再试一次', tone: SnackTone.destructive);
                        }
                      }
                    }
                  : null,
              child: const Text('加入'),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 八色预览条
class PalettePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: scheme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLowest,
        borderRadius: AppRadius.input,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('成员颜色 · 八色自动轮换',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          for (final c in AvatarPalette.colors) ...[
            const SizedBox(width: 5),
            Container(width: 13, height: 13, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          ],
        ],
      ),
    );
  }
}

class MemberRow extends ConsumerWidget {
  const MemberRow({super.key, required this.member, required this.expenseCount});

  final LedgerMemberView member;
  final int expenseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.input,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
        leading: MemberAvatar(member: member, size: 40),
        title: Text(member.name, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(expenseCount > 0 ? '参与 ' + expenseCount.toString() + ' 笔账单'
            : '还没一起记过账', style: Theme.of(context).textTheme.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '改名',
              icon: Icon(Icons.edit_outlined, size: 19, color: scheme.onSurfaceVariant),
              onPressed: () => _renameSheet(context, ref),
            ),
            IconButton(
              tooltip: '移除',
              icon: Icon(Icons.person_remove_outlined, size: 19, color: scheme.error.withValues(alpha: 0.8)),
              onPressed: () => _confirmRemove(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: member.name);
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.38,
      minChildSize: 0.3,
      builder: (sheetContext, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl,
            Spacing.xxl + MediaQuery.viewInsetsOf(sheetContext).bottom),
        children: [
          Text('改个称呼', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.lg),
          TextField(controller: controller, autofocus: true, maxLength: 12),
          const SizedBox(height: Spacing.lg),
          FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty || name == member.name) {
                  Navigator.of(sheetContext).pop();
                  return;
                }
                Navigator.of(sheetContext).pop();
                HapticFeedback.lightImpact();
                await renameMember(ref, member.id, name);
              },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final hasHistory = expenseCount > 0;
    // V2.9.0:自绘确认弹层收口 L2 危险确认（body 含影响数量）;按钮用语「删除/取消」。
    // S2 G1：有历史账单时物理删除被仓储拒绝，走软删除（保留历史）。
    final ok = await showDangerConfirm(
      context: context,
      title: '移除 ' + member.name + '？',
      body: hasHistory
          ? 'TA 参与 ' + expenseCount.toString() +
              ' 笔账单。为保住历史账目，将采用「移除成员（保留历史）」：TA 不再出现在记账选择里，历史账单与结算结果不变。'
          : '将移除 1 名成员，TA 名下没有历史包袱，移除后不可恢复。',
      confirmLabel: '删除',
      icon: Icons.person_remove_outlined,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (hasHistory) {
        await archiveMember(ref, member.id);
        messenger.showSnackBar(
            SnackBar(content: Text('已移除 ' + member.name + '（保留历史）')));
      } else {
        await removeMember(ref, member.id);
        messenger.showSnackBar(
            SnackBar(content: Text('已移除 ' + member.name)));
      }
    } on StateError catch (e) {
      // 兜底：公款池管理人等约束 → 明确提示，不静默失败。
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}


/// 「邀请旅伴」入口（云功能）。
///
/// 未登录时**不再整块隐藏**——隐藏会让用户完全看不到「可以邀请旅伴」这件事，
/// 是「分享功能根本不知道从哪进」的根因之一。改为显示但点击走登录引导。
class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.groupId});

  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    if (groupId == null) return const SizedBox.shrink();
    final signedIn = uid != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.group_add_rounded),
          title: Text(copy('share.invite')),
          subtitle: Text(
              signedIn ? copy('share.inviteCode') : copy('share.signInHint'),
              style: const TextStyle(fontSize: AppFontSizes.caption)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => signedIn
              // V2.9.0:邀请弹层收口统一抽屉入口（InviteCompanionSheet 已不再自带
              // SheetSurface,由 SheetContainer 提供玻璃底面）。
              ? showDraggableSheet<void>(
                  context: context,
                  initialChildSize: 0.55,
                  minChildSize: 0.35,
                  builder: (sheetContext, scrollController) =>
                      SingleChildScrollView(
                    controller: scrollController,
                    child: InviteCompanionSheet(groupId: groupId!),
                  ),
                )
              : context.push('/profile/cloud'),
        ),
      ),
    );
  }
}
