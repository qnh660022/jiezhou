import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/member_avatar.dart';
import '../widgets/stagger_in.dart';

/// 👤 成员管理：八色轮换头像、新增改名、被引用拦截。
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final groupId = ref.watch(activeGroupIdProvider).value;
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
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) =>
                        const EmptyState(emoji: '😵', title: '成员加载失败'),
                    data: (list) {
                      if (list.isEmpty) {
                        return EmptyState(
                          emoji: '👥',
                          title: '还没有成员',
                          message: 'AA 记账至少要有两位同行人哦',
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(
                            Spacing.xl, Spacing.md, Spacing.xl, 120),
                        children: [
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
          Positioned(
            right: Spacing.xl,
            bottom: 88 + MediaQuery.paddingOf(context).bottom,
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
              decoration: InputDecoration(hintText: 'TA 的名字或称呼'),
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(sheetContext).pop();
                HapticFeedback.lightImpact();
                try {
                  await addMember(ref, groupId, name);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('添加失败，再试一次')));
                  }
                }
              },
            child: const Text('加入'),
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
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.34,
      minChildSize: 0.28,
      builder: (sheetContext, __) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('移除 ' + member.name + '？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            Text(expenseCount > 0
                ? 'TA 参与 ' + expenseCount.toString() + ' 笔账单，直接移除会让这些账对不上号。'
                : '移除后 TA 名下没有历史包袱。',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('算了'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      try {
                        await removeMember(ref, member.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('已移除 ' + member.name)));
                        }
                      } on StateError {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('该成员已参与 ' + expenseCount.toString() + ' 笔账单，不能删除'),
                          ));
                        }
                      }
                    },
                    child: const Text('移除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
