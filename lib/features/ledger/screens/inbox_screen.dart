import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/conflict_badge.dart';
import 'inbox_sheets.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// 📥 记账收件箱（S10）：先记后理。
///
/// 红线：pending 条目不出现在主页 / 统计 / 结算 / 导出 / 备份 / 分享；
/// 归类 = 转正（写正式账单），禁止用删除代替归类。
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final Set<String> _selected = {};
  bool _convertedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pendingAsync = ref.watch(pendingInboxProvider);
    final convertedAsync = ref.watch(convertedInboxProvider);
    final group = ref.watch(activeGroupProvider).value;

    final pending = pendingAsync.value ?? const <InboxItemView>[];
    final converted = convertedAsync.value ?? const <InboxItemView>[];
    final total = pending.fold<int>(0, (s, e) => s + e.amountCents);

    return Scaffold(
      appBar: GlassAppBar(title: '记账收件箱'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            Spacing.xl, Spacing.md, Spacing.xl, AppBottomLayout.withSafeArea(context, 96)),
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: AppRadius.card,
            ),
            child: Row(
              children: [
                Icon(Icons.inbox_rounded, color: scheme.primary),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${pending.length} 笔待归类',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('合计 ${formatMoney(total)}',
                          style: TextStyle(
                              fontSize: AppFontSizes.caption,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => _classifyBatch(pending),
                    child: Text('批量归类 (${_selected.length})'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          if (group != null)
            PrimaryButton(
              label: '快速记一笔',
              expanded: true,
              onPressed: () => showCaptureInboxSheet(context, ref, group.id),
            ),
          const SizedBox(height: Spacing.lg),
          if (pending.isEmpty)
            const EmptyState(
              icon: Icons.inbox_rounded,
              title: '收件箱空了',
              message: '随手记下的金额都在这里排队，归类后才会进入账本。',
            )
          else ...[
            Text('待归类', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.sm),
            for (final item in pending)
              _PendingTile(
                item: item,
                selected: _selected.contains(item.id),
                onToggle: () => setState(() => _selected.contains(item.id)
                    ? _selected.remove(item.id)
                    : _selected.add(item.id)),
                onClassify: () => _classifyOne(item),
              ),
          ],
          if (converted.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            InkWell(
              onTap: () => setState(() => _convertedExpanded = !_convertedExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Row(
                  children: [
                    Text('已归类 (${converted.length}) · 仅供查看',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Icon(_convertedExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            if (_convertedExpanded)
              for (final item in converted) _ConvertedTile(item: item),
          ],
        ],
      ),
    );
  }

  Future<void> _classifyOne(InboxItemView item) async {
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null) return;
    final draft = await showClassifySheet(context, ref, item);
    if (draft == null) return;
    try {
      await convertInboxItem(ref, itemId: item.id, draft: draft);
      if (mounted) {
        setState(() => _selected.remove(item.id));
        showAppSnackBar(context, '已归类进账本 ✅');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '归类失败：${e.toString()}', tone: SnackTone.destructive);
      }
    }
  }

  Future<void> _classifyBatch(List<InboxItemView> all) async {
    final items = all.where((i) => _selected.contains(i.id)).toList();
    if (items.isEmpty) return;
    final result = await showBatchClassifySheet(context, ref, items);
    if (result == null) return;
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null) return;
    try {
      final done = await convertInboxItems(
        ref,
        items: items,
        draftOf: (item) => buildClassifyDraft(
          ref: ref,
          item: item,
          groupId: gid,
          categoryKey: result.categoryKey,
          shareMode: ShareMode.equal,
        ),
      );
      if (mounted) {
        setState(() => _selected.clear());
        showAppSnackBar(context, '已归类 $done 笔 ✅');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '批量归类失败：${e.toString()}', tone: SnackTone.destructive);
      }
    }
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.item,
    required this.selected,
    required this.onToggle,
    required this.onClassify,
  });

  final InboxItemView item;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onClassify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : scheme.surfaceContainerLow,
        borderRadius: AppRadius.input,
        child: ListTile(
          onTap: onClassify,
          leading: Checkbox(value: selected, onChanged: (_) => onToggle()),
          title: Row(
            children: [
              MoneyText(item.amountCents, fontSize: AppFontSizes.bodyLarge),
              const SizedBox(width: Spacing.sm),
              if ((item.note ?? '').isNotEmpty)
                Expanded(
                  child: Text(item.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              // V2.7.1 S12.2：该条目存在未确认冲突时显示小标记（仅提示）。
              ConflictDot(entityId: item.id),
            ],
          ),
          subtitle: Text(
            '${capturedLabel(item.capturedAtMs)} 收进 · 点一下归类',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _ConvertedTile extends ConsumerWidget {
  const _ConvertedTile({required this.item});
  final InboxItemView item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          MoneyText(item.amountCents, fontSize: AppFontSizes.caption),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              (item.note ?? '').isEmpty ? '已归类' : item.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            tooltip: '移除记录',
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await deleteInboxItem(ref, item.id);
              } on StateError catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 捕捉时间的人性化文案。
String capturedLabel(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return sameDay ? '今天 $hh:$mm' : '${d.month}月${d.day}日 $hh:$mm';
}
