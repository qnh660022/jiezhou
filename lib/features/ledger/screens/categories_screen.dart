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
import '../widgets/category_icon_box.dart';
import '../widgets/stagger_in.dart';

/// 🏷️ 分类管理：内置 7 类锁定展示 + 自定义增删（被引用拦截）。
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];

    return Scaffold(
      appBar: GlassAppBar(title: '分类管理'),
      body: categoriesAsync.isLoading
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Spacing.xl),
              children: const [
                SkeletonBox(height: 150, radius: AppRadius.cardValue),
                SizedBox(height: Spacing.lg),
                SkeletonListTile(),
                SkeletonListTile(),
              ],
            )
          : categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const EmptyState(emoji: '😵', title: '加载失败'),
              data: (all) {
                final builtin = all.where((c) => c.builtin).toList();
                final custom = all.where((c) => !c.builtin).toList();

                int refCount(String key) {
                  var n = 0;
                  for (final e in expenses) {
                    if (e.categoryKey == key) n++;
                  }
                  return n;
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
                    StaggerIn(index: 0, child: _BuiltinGrid(builtin: builtin)),
                    const SizedBox(height: Spacing.lg),
                    StaggerIn(
                      index: 1,
                      child: _CustomSection(
                        custom: custom,
                        refCount: refCount,
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          right: Spacing.xl,
          bottom: AppBottomLayout.withSafeArea(
            context,
            AppBottomLayout.actionButtonOffset,
          ),
        ),
        child: FloatingActionButton.extended(
          heroTag: 'fab-category-add',
          onPressed: () => _createSheet(context, ref),
          icon: const Icon(Icons.new_label_outlined),
          label: const Text('自定义分类'),
        ),
      ),
    );
  }

  Future<void> _createSheet(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final nameController = TextEditingController();
    var selectedIcon = categoryIconChoices.first;

    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxl),
          children: [
            Text('新建自定义分类', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 8,
              decoration: InputDecoration(hintText: '分类名，如「装备租赁」'),
            ),
            const SizedBox(height: Spacing.lg),
            Text('选个图标（' + categoryIconChoices.length.toString() + ' 选 1）',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: Spacing.sm,
                crossAxisSpacing: Spacing.sm,
              ),
              itemCount: categoryIconChoices.length,
              itemBuilder: (context, i) {
                final icon = categoryIconChoices[i];
                final selected = icon == selectedIcon;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setSheetState(() => selectedIcon = icon);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(sheetContext).colorScheme.primaryContainer
                          : Theme.of(sheetContext).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.buttonValue),
                      border: Border.all(
                        color: selected
                            ? Theme.of(sheetContext).colorScheme.primary
                            : Theme.of(sheetContext).colorScheme.outlineVariant.withValues(alpha: 0.6),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(sheetContext).pop();
                HapticFeedback.lightImpact();
                try {
                  await createCategory(ref, name, selectedIcon);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('「' + name + '」加好了 🏷️')));
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('创建失败：名字可能重复了')));
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 内置分类锁定网格
// ---------------------------------------------------------------------------

class _BuiltinGrid extends StatelessWidget {
  const _BuiltinGrid({required this.builtin});

  final List<CategoryView> builtin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('内置分类', style: Theme.of(context).textTheme.titleMedium)),
                Icon(Icons.lock_outline_rounded, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('系统预置不可改', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Spacing.md,
              crossAxisSpacing: Spacing.md,
              childAspectRatio: 0.95,
              children: [
                for (final c in builtin)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CategoryIconBox(categoryKey: c.key, icon: c.icon, size: 40),
                      const SizedBox(height: 5),
                      Flexible(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 自定义分区
// ---------------------------------------------------------------------------

class _CustomSection extends ConsumerWidget {
  const _CustomSection({required this.custom, required this.refCount});

  final List<CategoryView> custom;
  final int Function(String key) refCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    if (custom.isEmpty) {
      return EmptyState(
        emoji: '🏷️',
        title: '还没有自定义分类',
        message: '点右下角按钮，给特殊开销建个专属格子',
      );
    }

    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          children: [
            for (var i = 0; i < custom.length; i++) ...[
              if (i > 0)
                Divider(height: 0.8, thickness: 0.8, indent: 66, endIndent: Spacing.md),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                leading: CategoryIconBox(categoryKey: custom[i].key, icon: custom[i].icon),
                title: Text(custom[i].name, style: Theme.of(context).textTheme.titleSmall),
                subtitle: Text(refCount(custom[i].key) > 0
                    ? '已被 ' + refCount(custom[i].key).toString() + ' 笔账单使用'
                    : '尚未被引用',
                    style: Theme.of(context).textTheme.bodySmall),
                trailing: IconButton(
                  tooltip: '删除',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 19, color: scheme.error.withValues(alpha: 0.8)),
                  onPressed: () => _confirmDelete(context, ref, custom[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, CategoryView category) async {
    HapticFeedback.selectionClick();
    final n = refCount(category.key);
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.32,
      minChildSize: 0.26,
      builder: (sheetContext, __) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('删除「' + category.name + '」？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            Text(n > 0 ? '它已被 ' + n.toString() + ' 笔账单引用，删除会被拦下。' : '确认后即刻移除。',
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
                        await removeCategory(ref, category.key);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已删除「' + category.name + '」')));
                        }
                      } on StateError {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('该分类已被 ' + n.toString() + ' 笔账单引用，不能删除'),
                          ));
                        }
                      }
                    },
                    child: const Text('删除'),
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
