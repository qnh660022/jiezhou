import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../../../export/backup_format.dart';
import '../../../export/share_helper.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/group_summary_sheet.dart';
import '../widgets/stagger_in.dart';
import '../widgets/join_by_qr_tile.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../theme/app_icons.dart';

/// 旅行团管理：切换、新建入口、专有 .tav 备份导入导出。
class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final activeId = ref.watch(activeGroupIdProvider).value;

    return Scaffold(
      appBar: GlassAppBar(
        // V2.9.0:用语统一 ——「旅行团管理」→「账本管理」。
        title: '账本管理',
        actions: [
          // V2.8.1 S7：扫码入口统一组件
          const JoinByQrTile(compact: true),
          IconButton(
            tooltip: '局域网同步（同 Wi-Fi 快照合并）',
            onPressed: () => context.pushNamed('lan-sync'),
            icon: const Icon(Icons.wifi_tethering_rounded),
          ),
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
              // V2.9.0:错误态收口 ErrorState,提供真实重试入口。
              error: (e, s) => ErrorState(
                onRetry: () => ref.invalidate(groupsProvider),
                error: e,
                stackTrace: s,
              ),
              data: (groups) => groups.isEmpty
                  ? EmptyState(
                      icon: AppIcons.members,
                      title: '一个团都还没有',
                      message: '先建个团，再拉上伙伴们一起记',
                      // V2.9.0:用语统一 ——「新建旅行团」→「新建账本」。
                      actionLabel: '新建账本',
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
                            // V2.8.1 S7：团卡左滑删除（确认弹层接管，行本身不滑除）
                            child: Dismissible(
                              key: ValueKey('group-' + g.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: Spacing.xl),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.card,
                                ),
                                child: Icon(Icons.delete_outline_rounded,
                                    color: Theme.of(context).colorScheme.error),
                              ),
                              confirmDismiss: (_) async {
                                _confirmDeleteGroup(context, ref, g);
                                return false;
                              },
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
                                    showAppSnackBar(context, '已切到「' + g.name + '」');
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
                                title: Row(
                                  children: [
                                    // V2.8.2 S6：团卡→团编辑名称 Hero
                                    Flexible(
                                      child: Hero(
                                        tag: 'group-name-${g.id}',
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: Text(g.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.xs),
                                    // S4：账本类型标签 + 区别性图标。
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            g.isPersonal
                                                ? Icons.person_outline_rounded
                                                : Icons.groups_2_outlined,
                                            size: 12,
                                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            g.isPersonal ? '个人' : '旅行',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context).colorScheme.onSecondaryContainer),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  g.archived
                                      ? '已结束 · 数据保留，可随时恢复'
                                      : g.isPersonal
                                          ? '只记自己的每一笔'
                                          : g.budgetEnabled
                                              ? '预算已开启 · 目标 ¥' + MoneyFormat.fenToYuan(g.budgetCents ?? 0)
                                              : '轻点切换为当前团',
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
          // V2.9.0:用语统一 ——「新建团」→「新建账本」。
          label: const Text('新建账本'),
        ),
      ),
    );
  }

  // V2.9.0:本地 _yuan 退役,金额展示统一走 MoneyFormat。

  // ---------------------------------------------------------------------------
  // 单团长按操作
  // ---------------------------------------------------------------------------

  Future<void> _actionsSheet(BuildContext context, WidgetRef ref, LedgerGroupView g) async {
    HapticFeedback.selectionClick();
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.52,
      minChildSize: 0.4,
      builder: (sheetContext, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
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
              leading: Icon(g.archived
                  ? Icons.unarchive_rounded
                  : Icons.flag_rounded),
              title: Text(g.archived ? '恢复为进行中的团' : '结束团（生成总结）'),
              subtitle: Text(g.archived
                  ? '继续记账、结算，回到正常状态'
                  : '展示本轮总结，数据保留可随时修改'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (g.archived) {
                  await archiveGroup(ref, g.id, false);
                } else {
                  await showGroupSummarySheet(context, ref, g,
                      onConfirmed: () => archiveGroup(ref, g.id, true));
                }
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
                    showAppSnackBar(context, '备份失败，稍后再试', tone: SnackTone.destructive);
                  }
                }
              },
            ),
            const SizedBox(height: Spacing.sm),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('删除账本',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: const Text('连同该团全部账单、成员与结算一并删除，不可恢复'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDeleteGroup(context, ref, g);
              },
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
      BuildContext context, WidgetRef ref, LedgerGroupView g) async {
    final ok = await showDangerConfirm(
      context: context,
      title: '删除账本？',
      body: '将删除「${g.name}」及其 3 类数据：全部账单、成员与结算记录，不可恢复。',
      confirmLabel: '删除',
    );
    if (!ok || !context.mounted) return;
    HapticFeedback.lightImpact();
    await deleteGroup(ref, g.id);
    if (context.mounted) {
      showAppSnackBar(context, '已删除「${g.name}」', tone: SnackTone.destructive);
    }
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
                        showAppSnackBar(context, summary);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        showAppSnackBar(context, '导入失败：备份文件损坏或格式不认识',
                            tone: SnackTone.destructive);
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
        allowedExtensions: ['tav', 'tavA', 'json', 'txt'],
        withData: true,
      );
      if (result.isEmpty) return;
      final picked = result.single;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      final ext = (picked.extension ?? '').toLowerCase();
      // 全量备份（.tavA / 电脑端「导出全量备份」）：合并导入，不要求本端已有团。
      if (looksLikeBackupEnvelope(bytes, acceptedMagics: [kFullBackupMagic])) {
        final summary =
            await importFullBackupFile(ref, bytes, replace: false);
        if (context.mounted) {
          showAppSnackBar(context, summary);
        }
        return;
      }
      final summary = ext == 'tav'
          ? await importGroupBackupFile(ref, bytes)
          : await importGroupFromText(ref, utf8.decode(bytes));
      if (context.mounted) {
        showAppSnackBar(context, summary);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, '文件读取或解析失败了', tone: SnackTone.destructive);
      }
    }
  }
}