import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../../../export/share_helper.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/stagger_in.dart';

/// 旅行团管理：切换、新建入口、专有 .tav 备份导入导出。
class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final activeId = ref.watch(activeGroupIdProvider).value;

    return Scaffold(
      appBar: GlassAppBar(
        title: '旅行团管理',
        actions: [
          IconButton(
            tooltip: '导入团备份',
            onPressed: () => _importSheet(context, ref),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: groupsAsync.isLoading
          ? ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Spacing.xl),
              children: const [
                SkeletonBox(height: 76, radius: AppRadius.inputValue),
                SizedBox(height: Spacing.md),
                SkeletonBox(height: 76, radius: AppRadius.inputValue),
              ],
            )
          : groupsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const EmptyState(emoji: '😵', title: '加载失败'),
              data: (groups) => groups.isEmpty
                  ? EmptyState(
                      emoji: '👥',
                      title: '一个团都还没有',
                      message: '先建个团，再拉上伙伴们一起记',
                      actionLabel: '新建旅行团',
                      onAction: () => context.pushNamed('group-edit'),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.xl,
                        Spacing.md,
                        Spacing.xl,
                        AppBottomLayout.withSafeArea(
                          context,
                          AppBottomLayout.contentTail,
                        ),
                      ),
                      itemCount: groups.length,
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        final active = g.id == activeId;
                        return StaggerIn(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.md),
                            child: Material(
                              color: active
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : (Theme.of(context).colorScheme.brightness == Brightness.dark
                                      ? Theme.of(context).colorScheme.surfaceContainerHigh
                                      : Theme.of(context).colorScheme.surfaceContainerLowest),
                              borderRadius: AppRadius.card,
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.lg, vertical: Spacing.xs),
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  await activateGroup(ref, g.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('已切到「' + g.name + '」')));
                                  }
                                },
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(AppRadius.buttonValue),
                                  ),
                                  child: Text(g.icon, style: const TextStyle(fontSize: 22)),
                                ),
                                title: Text(g.name, style: Theme.of(context).textTheme.titleSmall),
                                subtitle: Text(
                                  g.budgetEnabled ? '预算已开启 · 目标 ¥' + _yuan(g.budgetCents ?? 0) : '轻点切换为当前团',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (active)
                                      Icon(Icons.check_circle_rounded,
                                          color: Theme.of(context).colorScheme.primary),
                                    IconButton(
                                      icon: Icon(Icons.more_horiz_rounded,
                                          size: 19, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      onPressed: () => _actionsSheet(context, ref, g),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
          heroTag: 'fab-group-add',
          onPressed: () => context.pushNamed('group-edit'),
          icon: const Icon(Icons.group_add_rounded),
          label: const Text('新建团'),
        ),
      ),
    );
  }

  String _yuan(int cents) =>
      (cents ~/ 100).toString() + '.' + (cents % 100).toString().padLeft(2, '0');

  // ---------------------------------------------------------------------------
  // 单团长按操作
  // ---------------------------------------------------------------------------

  Future<void> _actionsSheet(BuildContext context, WidgetRef ref, LedgerGroupView g) async {
    HapticFeedback.selectionClick();
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.42,
      minChildSize: 0.34,
      builder: (sheetContext, __) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text(g.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(g.name, style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: Spacing.lg),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('设为当前使用的团'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await activateGroup(ref, g.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑名称与图标'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.pushNamed('group-edit', queryParameters: {'id': g.id});
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('导出团备份（.tav）'),
              subtitle: const Text('团、账单、成员、结算、行程一并保存'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                try {
                  final (bytes, filename) = await exportGroupBackup(ref, g.id);
                  await shareFile(bytes, filename, 'application/x-travel-assistant-group');
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('备份失败，稍后再试')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 导入抽屉：粘贴文本 / 文件
  // ---------------------------------------------------------------------------

  Future<void> _importSheet(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController();
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.62,
      builder: (sheetContext, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxl),
        children: [
          Text('导入旅行团', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.xs),
          Text('导入 .tav 专有备份；也兼容粘贴旧版 JSON 文本',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(hintText: '旧版 JSON 备份内容（新备份请使用 .tav 文件）'),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _importFromFile(context, ref);
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('导入 .tav 文件'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.of(sheetContext).pop();
                    try {
                      final summary = await importGroupFromText(ref, text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(summary)));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('导入失败：备份文件损坏或格式不认识')));
                      }
                    }
                  },
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  label: const Text('导入这段文本'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tav', 'json', 'txt'],
        withData: true,
      );
      if (result.isEmpty) return;
      final picked = result.single;
      final path = picked.path;
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) return;
      final ext = (picked.extension ?? '').toLowerCase();
      final summary = ext == 'tav'
          ? await importGroupBackupFile(ref, bytes)
          : await importGroupFromText(ref, utf8.decode(bytes));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('文件读取或解析失败了')));
      }
    }
  }
}