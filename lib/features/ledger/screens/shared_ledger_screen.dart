/// 共享账本（受邀端，V2.6 §3.13 / §3.17.5）：
/// - 首页「共享账本」分组卡（数据源 shared_groups 镜像）；
/// - 团详情：成员 + 账单（镜像只读展示）；
/// - 在线直写：加账单/成员/结算 → upsert 对应 *_sync（owner_user_id 保持团 owner），
///   成功后立即用写回结果刷新本地 shared_*；失败 toast，不落本地业务表；
/// - 离线：全部写入口隐藏，卡片显示「离线仅可查看」；
/// - 管理操作（团名/图标/预算/归档/邀请/移除/删团）仅 owner 可见，member 端隐藏。
library;
import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart';
import '../../../core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/tokens.dart';

/// 首页「共享账本」分组（空态不显示）。
class SharedLedgerSection extends ConsumerWidget {
  const SharedLedgerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = ref.watch(sharedGroupsStreamProvider);
    return shared.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title: copy('share.sectionTitle')),
          for (final g in groups)
            Card(
              margin: const EdgeInsets.only(bottom: Spacing.md),
              child: ListTile(
                leading: Text(g.icon, style: const TextStyle(fontSize: 26)),
                title: Text(g.name),
                subtitle: Text(copy('share.collabBadge'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: AppFontSizes.caption)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/ledger/shared/${g.id}'),
              ),
            ),
        ]);
      },
    );
  }
}

/// 共享团详情（镜像 + 在线直写）。
class SharedGroupScreen extends ConsumerStatefulWidget {
  const SharedGroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<SharedGroupScreen> createState() => _SharedGroupScreenState();
}

class _SharedGroupScreenState extends ConsumerState<SharedGroupScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final scheme = Theme.of(context).colorScheme;
    final online = ref.watch(cloudClientProvider) != null;
    return Scaffold(
      appBar: AppBar(title: FutureBuilder<String>(
        future: _groupName(db),
        builder: (_, snap) => Text(snap.data ?? copy('share.sectionTitle')),
      )),
      body: ListView(padding: const EdgeInsets.all(Spacing.lg), children: [
        if (!online)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Chip(label: Text(copy('share.offlineBadge'))),
          ),
        SectionHeader(title: '成员'),
        FutureBuilder<List<SharedMember>>(
          future: (db.select(db.sharedMembers)..where((m) => m.groupId.equals(widget.groupId))).get(),
          builder: (_, snap) => Card(
            margin: EdgeInsets.zero,
            child: Column(children: [
              for (final m in snap.data ?? const <SharedMember>[])
                ListTile(dense: true, leading: const Icon(Icons.person_rounded), title: Text(m.name)),
            ]),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        SectionHeader(title: '账单'),
        StreamBuilder<List<SharedExpense>>(
          stream: (db.select(db.sharedExpenses)
                ..where((e) => e.groupId.equals(widget.groupId))
                ..orderBy([(e) => OrderingTerm.desc(e.dateEpochDay)]))
              .watch(),
          builder: (_, snap) {
            final expenses = snap.data ?? const <SharedExpense>[];
            return Column(children: [
              for (final e in expenses)
                Card(
                  margin: const EdgeInsets.only(bottom: Spacing.sm),
                  child: ListTile(
                    dense: true,
                    title: Text(e.title),
                    subtitle: Text(e.categoryKey, style: const TextStyle(fontSize: AppFontSizes.caption)),
                    trailing: Text(formatMoney(e.amountCents),
                        style: TextStyle(
                            color: e.amountCents < 0 ? SemanticColors.income : scheme.onSurface,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ]);
          },
        ),
      ]),
      floatingActionButton: online ? FloatingActionButton(
        heroTag: 'shared_add_expense',
        onPressed: _addExpenseOnline,
        child: const Icon(Icons.add_rounded),
      ) : null,
    );
  }

  Future<String> _groupName(AppDatabase db) async {
    final rows = await (db.select(db.sharedGroups)..where((g) => g.id.equals(widget.groupId))).get();
    return rows.isEmpty ? copy('share.sectionTitle') : rows.first.name;
  }

  /// 在线直写账单（§3.13.2）：成功 → 用写回结果刷新镜像；失败 → toast 不落库。
  Future<void> _addExpenseOnline() async {
    final client = ref.read(cloudClientProvider);
    final engine = ref.read(syncEngineProvider);
    if (client == null || engine == null) return;
    final owner = engine.sharedOwnerUserIdOf(widget.groupId);
    if (owner == null) return;

    final form = await showDialog<_ExpenseForm?>(
      context: context,
      builder: (ctx) => const _ExpenseFormDialog(),
    );
    if (form == null) return;

    final members = await (ref.read(dbProvider).select(ref.read(dbProvider).sharedMembers)
          ..where((m) => m.groupId.equals(widget.groupId)))
        .get();
    final shareIds = members.map((m) => m.id).toList();
    final cents = form.cents;
    final per = shareIds.isEmpty ? 0 : cents ~/ shareIds.length;

    final id = newId('expense');
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = {
      'id': id,
      'owner_user_id': owner, // 共享写入不改 owner
      'group_id': widget.groupId,
      'date_epoch_day': form.dateEpochDay,
      'title': form.title,
      'category_key': form.categoryKey,
      'type': 'normal',
      'amount_cents': cents,
      'currency': 'CNY',
      'rate': 1.0,
      'payers_json': jsonEncode([for (final m in members) {'memberId': m.id, 'cents': per}]),
      'shares_json': jsonEncode([for (final m in members) {'memberId': m.id, 'cents': per}]),
      'share_mode': 'equal',
      'note': '',
      'created_ms': now,
      'updated_ms': now,
      'deleted': false,
    };
    try {
      await client.from('expenses_sync').upsert(row, onConflict: 'id');
      // 写回结果刷新本地镜像
      await ref.read(dbProvider).into(ref.read(dbProvider).sharedExpenses).insertOnConflictUpdate(
            SharedExpensesCompanion.insert(
              id: id,
              groupId: widget.groupId,
              dateEpochDay: Value(form.dateEpochDay),
              title: Value(form.title),
              categoryKey: Value(form.categoryKey),
              amountCents: Value(cents),
              payersJson: Value(row['payers_json'] as String),
              sharesJson: Value(row['shares_json'] as String),
              createdAt: now,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已写入云端')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(copy('cloud.errNetwork'))));
      }
    }
  }
}

class _ExpenseForm {
  _ExpenseForm(this.title, this.cents, this.dateEpochDay, this.categoryKey);
  final String title;
  final int cents;
  final int dateEpochDay;
  final String categoryKey;
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog();

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'other';

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记一笔'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: '名目')),
        TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '金额（元）')),
        const SizedBox(height: Spacing.md),
        Row(children: [
          Text('日期：${_date.month}/${_date.day}'),
          const Spacer(),
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (d != null) setState(() => _date = d);
            },
            child: const Text('选择'),
          ),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final cents = parseMoney(_amount.text);
            if (_title.text.trim().isEmpty || cents == null) return;
            final epochDay = dateToEpochDay(_date);
            Navigator.pop(
                context,
                _ExpenseForm(_title.text.trim(), cents, epochDay, _category));
          },
          child: const Text('记入'),
        ),
      ],
    );
  }
}
