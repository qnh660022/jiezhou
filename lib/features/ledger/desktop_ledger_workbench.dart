// 💰 桌面账本工作台：左团/账单列表 → 右详情，快速记一笔/编辑/结算跳转。
// 仅 Web 大屏由 router 分支接入；安卓/窄屏不受影响。
import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart' show parseMoney, formatMoney;
import '../../../data/db/database.dart' hide Settlement;
import '../../../data/providers.dart' show ledgerRepoProvider;
import '../../../domain/models.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/tokens.dart';
import 'screens/expense_edit_screen.dart';
import 'screens/expense_csv_import_screen.dart';
import 'ledger_models.dart';
import 'ledger_providers.dart';
import 'widgets/category_icon_box.dart';
import 'screens/settle_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/members_screen.dart';
import '../desktop/desktop_context_menu.dart';
import '../desktop/desktop_utils.dart';

/// 账本分支在桌面态的首屏（替代 LedgerHomeScreen）。
class DesktopLedgerWorkbench extends ConsumerStatefulWidget {
  const DesktopLedgerWorkbench({super.key});

  @override
  ConsumerState<DesktopLedgerWorkbench> createState() =>
      _DesktopLedgerWorkbenchState();
}

class _DesktopLedgerWorkbenchState extends ConsumerState<DesktopLedgerWorkbench> {
  final _search = TextEditingController();

  // 表格化：排序 + 多选
  String _sortKey = 'date'; // date | amount | title
  bool _sortAsc = false;
  bool _multi = false;
  final Set<String> _picked = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = key == 'title';
      }
    });
  }

  Future<void> _newExpense() =>
      openAsDialog(context, const ExpenseEditScreen(initialId: null), width: 800);

  Future<void> _editExpense(String id) =>
      openAsDialog(context, ExpenseEditScreen(initialId: id), width: 800);

  Future<void> _deletePicked() async {
    if (_picked.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除所选 ${_picked.length} 笔账单？'),
        content: const Text('此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in _picked) {
      await deleteExpense(ref, id);
    }
    _picked.clear();
    setState(() => _multi = false);
    _toast('已删除');
  }

  @override
  Widget build(BuildContext context) {
    final gid = ref.watch(activeGroupIdProvider).value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: DesktopLayout.masterPanelWidth + 40,
          child: _buildMaster(gid),
        ),
        Container(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(child: _buildDetail(gid)),
      ],
    );
  }

  Widget _buildMaster(String? gid) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
          child: Row(
            children: [
              Expanded(child: _GroupSelector(gid: gid)),
              const SizedBox(width: Spacing.sm),
              IconButton(
                tooltip: '新建旅行团',
                onPressed: () => context.push('/ledger/groups/edit'),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      hintText: '搜索账单', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              ElevatedButton.icon(
                onPressed: _newExpense,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('记一笔'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
            children: [
              for (final (k, v) in [
                ('', '全部'), ('csv', '导入账单'), ('settle', '结算'), ('stats', '统计'), ('budget', '预算'), ('members', '成员'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: ActionChip(
                    label: Text(v),
                    avatar: const SizedBox.shrink(),
                    onPressed: () {
                      switch (k) {
                        case 'csv':
                          openAsDialog(
                              context, const ExpenseCsvImportScreen(), width: 920);
                        case 'settle':
                          openAsDialog(context, const SettleScreen(), width: 840);
                        case 'stats':
                          openAsDialog(context, const StatsScreen(), width: 840);
                        case 'budget':
                          openAsDialog(context, const BudgetScreen(), width: 840);
                        case 'members':
                          openAsDialog(context, const MembersScreen(), width: 840);
                        default:
                          setState(() {});
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        _OverviewStrip(gid: gid),
        const Divider(height: 1),
        _BillColumnHeader(
          sortKey: _sortKey,
          sortAsc: _sortAsc,
          onSort: _toggleSort,
          multi: _multi,
          onToggleMulti: () => setState(() {
            _multi = !_multi;
            if (!_multi) _picked.clear();
          }),
        ),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        Expanded(
          child: _ExpenseList(
            gid: gid,
            sortKey: _sortKey,
            sortAsc: _sortAsc,
            multi: _multi,
            picked: _picked,
            onPick: _togglePick,
          ),
        ),
        if (_multi)
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            color: scheme.surfaceContainer,
            child: Row(
              children: [
                Text('已选 ${_picked.length} 笔',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: _deletePicked,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('删除所选'),
                ),
                const SizedBox(width: Spacing.xs),
                TextButton(
                  onPressed: () => setState(() {
                    _multi = false;
                    _picked.clear();
                  }),
                  child: const Text('退出多选'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _togglePick(String id, bool? v) {
    setState(() {
      if (v == true) {
        _picked.add(id);
      } else {
        _picked.remove(id);
      }
    });
  }

  Widget _buildDetail(String? gid) {
    if (gid == null) {
      return EmptyState(
          emoji: '💰',
          title: '还没有旅行团',
          message: '先新建一个团，拉上同行伙伴开始 AA 记账',
          actionLabel: '新建旅行团',
          onAction: () => context.push('/ledger/groups/edit'));
    }
    final id = ref.watch(_ExpenseSelection.provider);
    if (id == null) {
      return const EmptyState(
          emoji: '🧾', title: '选择左侧账单', message: '点选一笔消费即可查看详情、快速修改；右上「记一笔」录入新账单');
    }
    return _ExpenseDetailPane(expenseId: id, onEdit: _editExpense);
  }
}

class _OverviewStrip extends ConsumerWidget {
  const _OverviewStrip({this.gid});
  final String? gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];
    final now = DateTime.now();
    final monthStart = dateToEpochDay(DateTime(now.year, now.month, 1));
    var monthTotal = 0;
    var unsettled = 0;
    for (final e in expenses) {
      if (e.dateEpochDay >= monthStart) monthTotal += e.amountCents;
      if (e.settledRoundId == null) unsettled++;
    }
    final s = TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text('本月支出 ¥${formatMoney(monthTotal)}', style: s),
          const SizedBox(width: 14),
          Text('未结算 $unsettled 笔',
              style: s.copyWith(
                  color: unsettled > 0 ? scheme.error : scheme.onSurfaceVariant)),
          const Spacer(),
          Text(gid == null ? '未选团' : '已选团', style: s.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _BillColumnHeader extends StatelessWidget {
  const _BillColumnHeader({
    required this.sortKey,
    required this.sortAsc,
    required this.onSort,
    required this.multi,
    required this.onToggleMulti,
  });

  final String sortKey;
  final bool sortAsc;
  final void Function(String key) onSort;
  final bool multi;
  final VoidCallback onToggleMulti;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant);
    Widget sortable(String key, String label, {TextAlign? align}) {
      final active = sortKey == key;
      return InkWell(
        onTap: () => onSort(key),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: align == TextAlign.right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(label, style: active ? s.copyWith(color: scheme.primary) : s),
            const SizedBox(width: 3),
            Icon(
              active
                  ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 12,
              color: active ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.only(right: Spacing.md),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: IconButton(
              tooltip: multi ? '退出多选' : '多选',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: onToggleMulti,
              icon: Icon(multi
                  ? Icons.check_box_rounded
                  : Icons.checklist_rounded),
            ),
          ),
          Expanded(child: sortable('title', '标题')),
          SizedBox(width: 150, child: sortable('date', '记账人 · 日期')),
          SizedBox(width: 110, child: sortable('amount', '金额', align: TextAlign.right)),
        ],
      ),
    );
  }
}

/// 团切换下拉（当前团置顶，选择即激活）。
class _GroupSelector extends ConsumerWidget {
  const _GroupSelector({this.gid});
  final String? gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider).value ?? const <LedgerGroupView>[];
    final active = groups.where((g) => g.id == gid).firstOrNull;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: active?.id,
        hint: const Text('选择旅行团'),
        items: [
          for (final g in groups)
            DropdownMenuItem(
                value: g.id,
                child: Text('${g.icon} ${g.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (id) async {
          if (id == null) return;
          await activateGroup(ref, id);
        },
      ),
    );
  }
}

class _ExpenseList extends ConsumerWidget {
  const _ExpenseList({
    this.gid,
    required this.sortKey,
    required this.sortAsc,
    required this.multi,
    required this.picked,
    required this.onPick,
  });

  final String? gid;
  final String sortKey;
  final bool sortAsc;
  final bool multi;
  final Set<String> picked;
  final void Function(String id, bool? v) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expensesAsync = ref.watch(expensesProvider);
    if (gid == null) {
      return const Center(child: Text('请先选择旅行团'));
    }
    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const EmptyState(emoji: '🧾', title: '还没有账单', message: '点右上「记一笔」开始记账');
        }
        final sorted = [...expenses]
          ..sort((a, b) {
            var cmp = 0;
            switch (sortKey) {
              case 'amount':
                cmp = a.amountCents.compareTo(b.amountCents);
              case 'title':
                cmp = a.title.compareTo(b.title);
              default:
                cmp = a.dateEpochDay.compareTo(b.dateEpochDay);
            }
            if (cmp == 0) cmp = a.id.compareTo(b.id);
            return sortAsc ? cmp : -cmp;
          });
        final state = ref.watch(_ExpenseSelection.provider);
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: sorted.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, indent: 56, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          itemBuilder: (context, i) {
            final e = sorted[i];
            final sel = state == e.id;
            return _ExpenseRow(
              expense: e,
              selected: sel,
              multi: multi,
              checked: picked.contains(e.id),
              onChecked: (v) => onPick(e.id, v),
            );
          },
        );
      },
    );
  }
}

/// 账单选中态（跨 master/detail 共享）。
class _ExpenseSelection {
  static final provider = StateProvider<String?>((_) => null);
}

class _ExpenseRow extends ConsumerStatefulWidget {
  const _ExpenseRow({
    required this.expense,
    required this.selected,
    required this.multi,
    required this.checked,
    required this.onChecked,
  });

  final ExpenseRecord expense;
  final bool selected;
  final bool multi;
  final bool checked;
  final ValueChanged<bool?> onChecked;

  @override
  ConsumerState<_ExpenseRow> createState() => _ExpenseRowState();
}

class _ExpenseRowState extends ConsumerState<_ExpenseRow> {
  bool _hover = false;
  String? _editing; // null | title | amount
  late final TextEditingController _c = TextEditingController();

  ExpenseRecord get e => widget.expense;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _startEdit(String field) {
    _c.text = field == 'amount'
        ? (e.amountCents.abs() / 100).toStringAsFixed(2)
        : e.title;
    setState(() => _editing = field);
  }

  Future<void> _saveEdit() async {
    final field = _editing;
    if (field == null) return;
    setState(() => _editing = null);
    final repo = ref.read(ledgerRepoProvider);
    if (field == 'title') {
      final t = _c.text.trim();
      if (t.isEmpty || t == e.title) return;
      await repo.updateExpense(e.id, ExpensesCompanion(title: Value(t)));
    } else {
      final parsed = parseMoney(_c.text.trim());
      if (parsed == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('金额格式不正确')));
        return;
      }
      final stored = e.type == ExpenseType.refund ? -parsed.abs() : parsed;
      if (stored == e.amountCents) return;
      await repo.updateExpense(e.id, ExpensesCompanion(amountCents: Value(stored)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).value ?? const <CategoryView>[];
    String icon = '🏷️';
    for (final c in categories) {
      if (c.key == e.categoryKey) { icon = c.icon; break; }
    }
    final isRefund = e.type == ExpenseType.refund;
    final members = ref.watch(_MembersLite.provider);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: () => ref.read(_ExpenseSelection.provider.notifier).state = e.id,
        onDoubleTap: () => _startEdit(_editing == 'title' ? 'amount' : 'title'),
        onSecondaryTapDown: (d) => showDesktopContextMenu(context,
            globalPosition: d.globalPosition,
            actions: [
              DesktopAction(label: '编辑账单', icon: Icons.edit_rounded,
                  onTap: () => openAsDialog(context, ExpenseEditScreen(initialId: e.id), width: 800)),
              DesktopAction(label: '重命名', icon: Icons.drive_file_rename_outline_rounded,
                  onTap: () => _startEdit('title')),
              DesktopAction(label: '改金额', icon: Icons.payments_outlined,
                  onTap: () => _startEdit('amount')),
              DesktopAction(label: '删除账单', icon: Icons.delete_outline_rounded, danger: true,
                  onTap: () async {
                    await deleteExpense(ref, e.id);
                  }),
            ]),
        child: Container(
          color: widget.selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 7),
          child: Row(
            children: [
              if (widget.multi)
                Checkbox(
                  value: widget.checked,
                  onChanged: widget.onChecked,
                  visualDensity: VisualDensity.compact,
                )
              else
                CategoryIconBox(categoryKey: e.categoryKey, icon: icon, size: 36),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: _editing == 'title'
                            ? TextField(
                                controller: _c,
                                autofocus: true,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(isDense: true),
                                onSubmitted: (_) => _saveEdit(),
                                onTapOutside: (_) => setState(() => _editing = null),
                              )
                            : InkWell(
                                onTap: () =>
                                    ref.read(_ExpenseSelection.provider.notifier).state = e.id,
                                child: Text(e.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                      ),
                      if (isRefund) ...[
                        const SizedBox(width: 4),
                        Text('退款', style: TextStyle(fontSize: 10, color: scheme.error)),
                      ] else if (e.type == ExpenseType.prepay) ...[
                        const SizedBox(width: 4),
                        Text('预付', style: TextStyle(fontSize: 10, color: scheme.secondary)),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text('${_payerName(e, members)} · ${fmtMonthDayOfEpoch(e.dateEpochDay)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              if (_hover && !widget.multi) ...[
                IconButton(
                  tooltip: '编辑',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  onPressed: () =>
                      openAsDialog(context, ExpenseEditScreen(initialId: e.id), width: 800),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  onPressed: () async => deleteExpense(ref, e.id),
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
                const SizedBox(width: Spacing.xs),
              ],
              if (_editing == 'amount')
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _c,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(isDense: true),
                    onSubmitted: (_) => _saveEdit(),
                    onTapOutside: (_) => setState(() => _editing = null),
                  ),
                )
              else
                MoneyText(isRefund ? -e.amountCents : e.amountCents,
                    fontSize: 14, semanticColor: true),
            ],
          ),
        ),
      ),
    );
  }

  String _payerName(ExpenseRecord e, List<LedgerMemberView> members) {
    if (e.payers.isEmpty) return '—';
    final id = e.payers.first.memberId;
    for (final m in members) {
      if (m.id == id) return m.name;
    }
    return '已移除成员';
  }
}

class _MembersLite {
  static final provider = Provider<List<LedgerMemberView>>(
      (ref) => ref.watch(membersProvider).value ?? const <LedgerMemberView>[]);
}

/// 账单详情主从右栏：标题/金额/类别/日期/付款与摊分 + 快捷编辑删除。
class _ExpenseDetailPane extends ConsumerWidget {
  const _ExpenseDetailPane({required this.expenseId, required this.onEdit});
  final String expenseId;
  final void Function(String id) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];
    final e = expenses.where((x) => x.id == expenseId).firstOrNull;
    if (e == null) {
      return const EmptyState(emoji: '🗂️', title: '账单不存在', message: '可能已被删除');
    }
    final members = ref.watch(_MembersLite.provider);
    final categories = ref.watch(categoriesProvider).value ?? const <CategoryView>[];
    String icon = '🏷️';
    for (final c in categories) {
      if (c.key == e.categoryKey) { icon = c.icon; break; }
    }
    String catName = e.categoryKey;
    for (final c in categories) {
      if (c.key == e.categoryKey) { catName = c.name; break; }
    }
    String nm(String id) {
      for (final m in members) { if (m.id == id) return m.name; }
      return '已移除成员';
    }

    return ListView(
      padding: const EdgeInsets.all(Spacing.xl),
      children: [
        Row(
          children: [
            CategoryIconBox(categoryKey: e.categoryKey, icon: icon, size: 46),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('$catName · ${fmtMenuDate(e.dateEpochDay)}', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(e.type == ExpenseType.refund ? -e.amountCents : e.amountCents,
                    fontSize: 22, semanticColor: true),
                if (e.type == ExpenseType.refund)
                  Text('退款', style: TextStyle(fontSize: 11, color: scheme.error)),
              ],
            ),
          ],
        ),
        const SizedBox(height: Spacing.xl),
        Wrap(
          spacing: Spacing.sm,
          children: [
            ActionChip(avatar: const Icon(Icons.edit_rounded, size: 16), label: const Text('编辑'),
                onPressed: () => onEdit(e.id)),
            ActionChip(avatar: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('删除'), backgroundColor: scheme.errorContainer,
                labelStyle: TextStyle(color: scheme.onErrorContainer),
                onPressed: () async {
                  await deleteExpense(ref, e.id);
                }),
            ActionChip(avatar: const Icon(Icons.add_rounded, size: 16), label: const Text('新增一笔'),
                onPressed: () =>
                    openAsDialog(context, const ExpenseEditScreen(initialId: null), width: 800)),
          ],
        ),
        const SizedBox(height: Spacing.xl),
        if ((e.note ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Text('备注：${e.note}', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        _DetailBlock(title: '付款人', rows: [
          for (final p in e.payers)
            '${nm(p.memberId)}  ·  ¥${(p.cents / 100).toStringAsFixed(0)}',
        ]),
        const SizedBox(height: Spacing.lg),
        _DetailBlock(title: '分摊', rows: [
          for (final s in e.shares)
            '${nm(s.memberId)}  ·  ¥${(s.cents / 100).toStringAsFixed(0)}',
        ]),
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.rows});
  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        for (final r in rows) Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(r, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

String fmtMenuDate(int day) {
  final d = epochDayToDate(day);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}