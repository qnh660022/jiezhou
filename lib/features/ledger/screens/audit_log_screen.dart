/// V2.7.1 S12.3：变更记录页（`/expenses/audit`）。
///
/// 【可见性】仅 owner / editor 可进入——入口按钮本身对 viewer 不渲染
/// （「隐藏不置灰」，规格 §S7.1.2 / §S12.3-3），本页不做二次口令或禁用态。
/// 数据全部来自本地 `audit_logs`（不上云、不进备份、不进分享）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/repo/observability_repo.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/tokens.dart';
import '../observability_providers.dart';
import '../../../theme/app_icons.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  /// null = 全部（`auditLogsProvider` 的 family 键）。
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(auditLogsProvider(_filter));
    return Scaffold(
      appBar: AppBar(
        title: const Text('变更记录'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _FilterBar(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const EmptyState(
                  icon: Icons.error_outline_rounded, title: '读不出变更记录', message: '稍后再试试'),
              data: (logs) {
                if (logs.isEmpty) {
                  return const EmptyState(
                    emoji: '🪶',
                    title: '还没有变更记录',
                    message: '这本账的每次增删改都会留在这里，方便回溯。',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: Spacing.xxxl),
                  itemCount: logs.length + 1,
                  separatorBuilder: (_, _) => Divider(
                    height: 0.8,
                    thickness: 0.8,
                    indent: Spacing.xl + 30,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, i) {
                    if (i == logs.length) return const _RetentionHint();
                    return _AuditTile(log: logs[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <(String?, String)>[
      (null, '全部'),
      for (final e in AuditEntity.filterable) (e, AuditEntity.labelOf(e)),
      (AuditEntity.backup, AuditEntity.labelOf(AuditEntity.backup)),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, i) {
          final (v, label) = items[i];
          return Center(
            child: ChoiceChip(
              label: Text(label),
              selected: value == v,
              onSelected: (_) => onChanged(v),
            ),
          );
        },
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.log});

  final AuditLog log;

  static const Map<String, IconData> _icons = {
    AuditEntity.group: Icons.folder_rounded,
    AuditEntity.member: Icons.person_rounded,
    AuditEntity.expense: Icons.receipt_long_rounded,
    AuditEntity.settlement: Icons.balance_rounded,
    AuditEntity.fund: Icons.savings_rounded,
    AuditEntity.inbox: Icons.bolt_rounded,
    AuditEntity.category: Icons.sell_rounded,
    AuditEntity.backup: Icons.import_export_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fields = decodeAuditFields(log.changedFieldsJson);
    final summary = fields.entries
        .map((e) => '${e.key} ${e.value}')
        .take(4)
        .join(' · ');
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.buttonValue),
        ),
        child: Icon(_icons[log.entity] ?? Icons.circle_outlined,
            size: 19, color: scheme.primary),
      ),
      title: Text(
        '${AuditEntity.labelOf(log.entity)} · ${AuditAction.labelOf(log.action)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.isNotEmpty)
            Text(summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppFontSizes.caption)),
          const SizedBox(height: 2),
          Text(
            '${_fmtTime(log.atMs)} · ${_actorLabel(log.actorMemberId)}',
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      isThreeLine: summary.isNotEmpty,
    );
  }

  /// actor 缺失时降级显示（S12.3-6：不得崩溃）。
  String _actorLabel(String? actor) =>
      (actor == null || actor.isEmpty) ? '未知成员' : actor;

  static String _fmtTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// 体积策略说明（单团保留最近 2000 条，S12.3-5）。
class _RetentionHint extends StatelessWidget {
  const _RetentionHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.xl, Spacing.xl, Spacing.xl),
      child: Text(
        '仅保留最近 $kAuditRetentionPerGroup 条；变更记录只存在本机，不上云、不进备份。',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppFontSizes.caption,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
