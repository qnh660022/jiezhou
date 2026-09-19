import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../domain/models.dart';
import '../../../data/providers.dart';
import '../../../export/share_helper.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/swipeable_bill_tile.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_access.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/bill_detail_sheet.dart';
import '../widgets/category_icon_box.dart';
import '../widgets/conflict_badge.dart';
import '../widgets/stagger_in.dart';
import 'expense_csv_import_screen.dart';

/// 🧾 消费 Tab：粘性日期分组账单流 + 多维筛选 + 合计栏 + CSV 导出。
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _categoryFilter = ''; // '' = 全部
  String _memberFilter = ''; // '' = 全部

  /// S11 支付方式筛选（多选；空集 = 全部；`''` 代表「未标记」）。
  final Set<String> _payFilter = {};
  bool _showSearch = false;
  final _searchController = TextEditingController();

  /// V2.8.1 S6：时间筛选（📅 pill → showDateRangePicker；参与 URL 参数）。
  int? _fromEpochDay;
  int? _toEpochDay;

  /// V2.8.1 S6：批量多选态（空集 = 未进入批量）。
  final Set<String> _selected = {};

  bool _paramsApplied = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// V2.8.1 S6：`/expenses` query 参数解析（category/member/payMethods/from/to）。
  /// 供 S8 统计下钻跳转；无参时保持既有默认行为。
  void _applyQueryParams() {
    if (_paramsApplied) return;
    _paramsApplied = true;
    Map<String, String> q;
    try {
      q = GoRouterState.of(context).uri.queryParameters;
    } catch (_) {
      return; // 非 go_router 子树（如桌面工作台）无 query
    }
    final category = q['category'];
    if (category != null && category.isNotEmpty) _categoryFilter = category;
    final member = q['member'];
    if (member != null && member.isNotEmpty) _memberFilter = member;
    final pays = q['payMethods'];
    if (pays != null && pays.isNotEmpty) {
      _payFilter.addAll(pays.split(','));
    }
    final from = int.tryParse(q['from'] ?? '');
    final to = int.tryParse(q['to'] ?? '');
    if (from != null && to != null && to >= from) {
      _fromEpochDay = from;
      _toEpochDay = to;
    }
  }

  List<ExpenseRecord> _applyFilters(List<ExpenseRecord> all, List<LedgerMemberView> members) {
    final query = _searchController.text.trim().toLowerCase();
    return all.where((e) {
      if (_categoryFilter.isNotEmpty && e.categoryKey != _categoryFilter) return false;
      if (_payFilter.isNotEmpty && !_payFilter.contains(e.payMethod ?? '')) return false;
      if (_fromEpochDay != null && _toEpochDay != null &&
          (e.dateEpochDay < _fromEpochDay! || e.dateEpochDay > _toEpochDay!)) {
        return false;
      }
      if (_memberFilter.isNotEmpty &&
          !e.payers.any((p) => p.memberId == _memberFilter) &&
          !e.shares.any((s) => s.memberId == _memberFilter)) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = (e.title + ' ' + (e.note ?? '')).toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final byDate = b.dateEpochDay - a.dateEpochDay;
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
  }

  Future<void> _exportCsv(List<ExpenseRecord> expenses) async {
    if (expenses.isEmpty) {
      showAppSnackBar(context, '还没有可导出的账单');
      return;
    }
    try {
      final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
      final trips = ref.read(tripsInGroupProvider).value ?? const <TripCardView>[];
      final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];

      final memberNames = {for (final m in members) m.id: m.name};
      final tripNames = {for (final t in trips) t.id: t.name};
      final categoryNames = {for (final c in categories) c.key: c.name};

      // 反查关联安排标题（按出现的行程逐个取一次）
      final itemTitles = <String, String>{};
      final tripIds = expenses.map((e) => e.tripId).whereType<String>().toSet();
      for (final tid in tripIds) {
        final items = await ref.read(tripItemsProvider(tid).future);
        for (final i in items) {
          itemTitles[i.id] = i.name;
        }
      }

      final csv = buildCsvText(
        expenses: expenses,
        memberNames: memberNames,
        tripNames: tripNames,
        itemTitles: itemTitles,
        categoryNames: categoryNames,
      );

      final groupName = ref.read(activeGroupProvider).value?.name ?? '旅行团';
      final filename =
          '旅途账单-' + groupName + '-' + fmtIsoDate(DateTime.now()) + '.csv';
      await shareFile(utf8.encode(csv), filename, 'text/csv; charset=utf-8');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, '导出失败了，再试一次？', tone: SnackTone.destructive);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _applyQueryParams();
    final scheme = Theme.of(context).colorScheme;
    final gid = ref.watch(activeGroupIdProvider).value;
    final canWrite = gid == null
        ? true
        : (ref.watch(ledgerAccessProvider(gid)).value?.canWrite ?? true);
    final expensesAsync = ref.watch(expensesProvider);
    final membersAsync = ref.watch(membersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final unsettledAsync = ref.watch(unsettledCountProvider);

    final loading = expensesAsync.isLoading || membersAsync.isLoading;
    final members = membersAsync.value ?? const <LedgerMemberView>[];
    final categories = categoriesAsync.value ?? const <CategoryView>[];
    final filtered = _applyFilters(expensesAsync.value ?? const <ExpenseRecord>[], members);

    // 合计（不含预付）
    var totalCents = 0;
    var prepayTotal = 0;
    for (final e in filtered) {
      if (e.type == ExpenseType.prepay) {
        prepayTotal += e.amountCents;
      } else {
        totalCents += e.amountCents;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerLargeHeader(title: '消费', actions: [
          if (context.canPop())
            HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: '返回',
              onTap: () => context.pop(),
            ),
          HeaderIconButton(
            icon: Icons.donut_small_rounded,
            tooltip: '统计图表',
            onTap: () => context.push('/expenses/stats'),
          ),
          HeaderIconButton(
            icon: Icons.balance_rounded,
            tooltip: 'AA 结算',
            badgeCount: unsettledAsync.value ?? 0,
            onTap: () => context.push('/expenses/settle'),
          ),
          HeaderIconButton(
            icon: Icons.ios_share_rounded,
            tooltip: '导出 CSV',
            onTap: () => _exportCsv(filtered),
          ),
          HeaderIconButton(
            icon: Icons.file_upload_outlined,
            tooltip: 'CSV 导入',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpenseCsvImportScreen())),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xs, Spacing.xl, Spacing.sm),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showSearch
                ? TextField(
                    key: const ValueKey('search'),
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _searchController.clear();
                          setState(() => _showSearch = false);
                        },
                      ),
                      hintText: '搜标题或备注…',
                      isDense: true,
                    ),
                  )
                : Row(
                    key: const ValueKey('filters'),
                    children: [
                      Expanded(child: _buildFilterRow(categories, members)),
                      IconButton(
                        tooltip: '搜索',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showSearch = true);
                        },
                        icon: Icon(Icons.search_rounded, size: 21, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
        ),
        Expanded(
          child: loading
              ? ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                  children: const [SkeletonListTile(), SkeletonListTile(), SkeletonListTile(), SkeletonListTile()],
                )
              : Stack(
                  children: [
                    _buildBody(filtered, canWrite: canWrite),
                    Positioned(
                      left: Spacing.xl,
                      right: Spacing.xl,
                      // 合计栏下移贴近底部（避开悬浮胶囊栏即可），减少对滚动账单的遮挡。
                      // V2.8.1 S6：批量态用玻璃批量条替代合计栏。
                      bottom: AppBottomLayout.withSafeArea(
                        context,
                        AppBottomLayout.actionButtonOffset,
                      ),
                      child: canWrite && _selected.isNotEmpty
                          ? _BatchBar(
                              count: _selected.length,
                              totalCents: filtered
                                  .where((e) => _selected.contains(e.id))
                                  .fold(0, (a, e) => a + e.amountCents),
                              onDelete: _deleteSelected,
                              onChangeCategory: _changeCategoryOfSelected,
                              onCancel: () => setState(_selected.clear),
                            )
                          : _TotalBar(
                              totalCents: totalCents,
                              count: filtered.length,
                              prepayTotalCents: prepayTotal,
                            ),
                    ),
                    Positioned(
                      right: Spacing.xl,
                      // 记一笔按钮浮在合计栏正上方，二者不重叠。
                      bottom: AppBottomLayout.withSafeArea(
                        context,
                        AppBottomLayout.totalBarOffset,
                      ),
                      child: FloatingActionButton.extended(
                        heroTag: 'fab-expense-add',
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/expenses/edit');
                        },
                        icon: const Icon(Icons.add_card_rounded),
                        label: const Text('记一笔'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // S11：支付方式筛选小胶囊（多选；'' = 未标记）
  // ---------------------------------------------------------------------------

  List<Widget> _buildPayFilterPills() {
    final out = <Widget>[];
    if (_payFilter.isNotEmpty) {
      out.add(_FilterPill(
        label: '清空',
        selected: false,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _payFilter.clear());
        },
      ));
      out.add(const SizedBox(width: Spacing.sm));
    }
    for (final e in kPayMethodLabels.entries) {
      out.add(_FilterPill(
        label: e.value,
        selected: _payFilter.contains(e.key),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _payFilter.contains(e.key)
              ? _payFilter.remove(e.key)
              : _payFilter.add(e.key));
        },
      ));
      out.add(const SizedBox(width: Spacing.sm));
    }
    out.add(_FilterPill(
      label: '未标记',
      selected: _payFilter.contains(''),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _payFilter.contains('')
            ? _payFilter.remove('')
            : _payFilter.add(''));
      },
    ));
    return out;
  }

  // ---------------------------------------------------------------------------
  // 筛选行：全部 / 分类 / 成员
  // ---------------------------------------------------------------------------

  Widget _buildFilterRow(List<CategoryView> categories, List<LedgerMemberView> members) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _FilterPill(
            label: '全部',
            selected: _categoryFilter.isEmpty && _memberFilter.isEmpty,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _categoryFilter = '';
                _memberFilter = '';
              });
            },
          ),
          const SizedBox(width: Spacing.sm),
          for (final c in categories) ...[
            _FilterPill(
              label: c.icon + ' ' + c.name,
              selected: _categoryFilter == c.key,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _categoryFilter = _categoryFilter == c.key ? '' : c.key);
              },
            ),
            const SizedBox(width: Spacing.sm),
          ],
          for (final m in members) ...[
            _FilterPill(
              label: m.name,
              leading: m.colorIndex,
              selected: _memberFilter == m.id,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _memberFilter = _memberFilter == m.id ? '' : m.id);
              },
            ),
            const SizedBox(width: Spacing.sm),
          ],
          // V2.8.1 S6：📅 时间筛选（showDateRangePicker；激活后 pill 显示区间）
          _FilterPill(
            label: _fromEpochDay != null && _toEpochDay != null
                ? '${epochDayToDate(_fromEpochDay!).month}/${epochDayToDate(_fromEpochDay!).day}'
                    '-${epochDayToDate(_toEpochDay!).month}/${epochDayToDate(_toEpochDay!).day}'
                : '\u{1F4C5} 时间',
            selected: _fromEpochDay != null && _toEpochDay != null,
            onTap: _pickDateRange,
          ),
          const SizedBox(width: Spacing.sm),
          // V2.8.1 S6：⚙ 更多筛选抽屉；有激活筛选时显示数字徽章
          _FilterPill(
            label: _payFilter.isNotEmpty ? '\u2699 ${_payFilter.length}' : '\u2699 更多',
            selected: _payFilter.isNotEmpty,
            onTap: _openMoreFilterSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2045, 12, 31),
      initialDateRange: _fromEpochDay != null && _toEpochDay != null
          ? DateTimeRange(
              start: epochDayToDate(_fromEpochDay!),
              end: epochDayToDate(_toEpochDay!))
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked == null) return;
    setState(() {
      _fromEpochDay = dateToEpochDay(picked.start);
      _toEpochDay = dateToEpochDay(picked.end);
    });
  }

  /// V2.8.1 S6：⚙ 更多筛选抽屉（支付方式多选 + 清空）。
  Future<void> _openMoreFilterSheet() async {
    HapticFeedback.selectionClick();
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.35,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
          children: [
            Text('更多筛选', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            Text('支付方式（可多选）', style: Theme.of(sheetContext).textTheme.bodySmall),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final e in kPayMethodLabels.entries)
                  _FilterPill(
                    label: e.value,
                    selected: _payFilter.contains(e.key),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setSheetState(() => _payFilter.contains(e.key)
                          ? _payFilter.remove(e.key)
                          : _payFilter.add(e.key));
                      setState(() {});
                    },
                  ),
                _FilterPill(
                  label: '未标记',
                  selected: _payFilter.contains(''),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setSheetState(() => _payFilter.contains('')
                        ? _payFilter.remove('')
                        : _payFilter.add(''));
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            OutlinedButton.icon(
              onPressed: () {
                _payFilter.clear();
                setState(() {});
                setSheetState(() {});
              },
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('清空支付方式筛选'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 列表主体：按日分组 + 吸顶日期头
  // ---------------------------------------------------------------------------

  /// V2.8.1 S6：列表主体 —— 双级吸顶（月度头玻璃 navBar 档 + 日头）+ 批量多选。
  Widget _buildBody(List<ExpenseRecord> expenses, {required bool canWrite}) {
    if (expenses.isEmpty) {
      // V2.8.1 S6：修正空态双分支的判定反转（原实现 isEmpty 误作 anyAtAll，
      // 空库会误显「没找到匹配的账单」）。规格 §9.2-7：空态双分支沿用。
      final hasAnyBills =
          (ref.read(expensesProvider).value ?? const <ExpenseRecord>[]).isNotEmpty;
      return EmptyState(
        emoji: hasAnyBills ? '🔍' : '🧾',
        title: hasAnyBills ? '没找到匹配的账单' : '一笔都还没记',
        message: hasAnyBills ? '换个筛选条件试试' : '点「记一笔」，花销从此有迹可循',
        actionLabel: hasAnyBills ? null : '记一笔',
        onAction: hasAnyBills ? null : () => context.push('/expenses/edit'),
      );
    }

    final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];
    final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
    // 月 → 日 两级分组（日序号降序 = 时间倒序）
    final byMonth = <int, List<ExpenseRecord>>{};
    for (final e in expenses) {
      (byMonth[epochDayToDate(e.dateEpochDay).year * 100 + epochDayToDate(e.dateEpochDay).month] ??= [])
          .add(e);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    final batchMode = _selected.isNotEmpty && canWrite;

    return CustomScrollView(
      slivers: [
        for (final monthKey in months) ...[
          // 月度头：玻璃 navBar 档吸顶（2026年10月 · 共 ¥9,214）
          SliverPersistentHeader(
            pinned: true,
            delegate: _MonthHeaderDelegate(
              monthKey: monthKey,
              subtotal: _monthSubtotal(byMonth[monthKey]!),
            ),
          ),
          for (final day in byMonth[monthKey]!
              .map((e) => e.dateEpochDay)
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a))) ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                child: _DateHeader(
                    epochDay: day,
                    subtotal: _daySubtotal(
                        byMonth[monthKey]!.where((e) => e.dateEpochDay == day).toList())),
              ),
            ),
            SliverList.builder(
              itemCount:
                  byMonth[monthKey]!.where((e) => e.dateEpochDay == day).length,
              itemBuilder: (context, i) {
                final expense =
                    byMonth[monthKey]!.where((e) => e.dateEpochDay == day).toList()[i];
                final selected = _selected.contains(expense.id);
                final tile = _ExpenseTile(
                  expense: expense,
                  memberName: (id) =>
                      members.where((m) => m.id == id).firstOrNull?.name ?? '已移除成员',
                  categoryIcon:
                      categories.where((c) => c.key == expense.categoryKey).firstOrNull?.icon ?? '🏷️',
                  selected: batchMode || selected,
                  checkVisible: batchMode,
                  onToggleSelect: canWrite && batchMode
                      ? () => setState(() => _selected.contains(expense.id)
                          ? _selected.remove(expense.id)
                          : _selected.add(expense.id))
                      : null,
                );
                // viewer/只读不进入批量与滑动动作（隐藏不置灰）
                if (!canWrite) return StaggerIn(index: i, child: tile);
                return StaggerIn(
                  index: i,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () => _enterBatchMode(expense.id),
                    child: SwipeableBillTile(
                      onEdit: () {
                        HapticFeedback.selectionClick();
                        context.push('/expenses/edit?id=${expense.id}');
                      },
                      onDelete: () => _deleteOne(expense),
                      child: tile,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppBottomLayout.withSafeArea(
              context,
              AppBottomLayout.contentTail,
            ),
          ),
        ),
      ],
    );
  }

  void _enterBatchMode(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selected.add(id));
  }

  /// 单笔删除：L2 危险确认（含数量）→ repo 删 + 墓碑。
  Future<void> _deleteOne(ExpenseRecord e) async {
    final ok = await showDangerConfirm(
      context: context,
      title: '删除这笔账单？',
      body: '删除「${e.title}」？共 1 笔，云端共享成员都会看到该账单被删除。',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    await ref.read(ledgerRepoProvider).deleteExpense(e.id);
    ref.invalidate(expensesProvider);
    if (mounted) {
      showAppSnackBar(context, '已删除「${e.title}」', tone: SnackTone.destructive);
    }
  }

  /// 批量删除：L2 强确认（含数量）→ 单事务 + 逐行墓碑。
  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    final ok = await showDangerConfirm(
      context: context,
      title: '删除所选 ${ids.length} 笔账单？',
      body: '将删除 ${ids.length} 笔账单，此操作不可恢复，云端同步成员均可见删除记录。',
      confirmLabel: '全部删除',
    );
    if (!ok || !mounted) return;
    await ref.read(ledgerRepoProvider).deleteExpensesBatch(ids);
    ref.invalidate(expensesProvider);
    if (mounted) setState(_selected.clear);
    if (mounted) {
      showAppSnackBar(context, '已删除 ${ids.length} 笔账单', tone: SnackTone.destructive);
    }
  }

  /// 批量改分类：分类选择抽屉 → 单事务逐行更新 + notifyWrite。
  Future<void> _changeCategoryOfSelected() async {
    final ids = _selected.toList();
    final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];
    String? picked;
    await showDraggableSheet<String>(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.35,
      builder: (sheetContext, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        children: [
          Text('改分类（${ids.length} 笔）',
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: Spacing.sm),
          for (final c in categories)
            ListTile(
              leading: CategoryIconBox(categoryKey: c.key, icon: c.icon, size: 36),
              title: Text(c.name),
              onTap: () => Navigator.of(sheetContext).pop(c.key),
            ),
        ],
      ),
    ).then((v) => picked = v);
    if (picked == null || !mounted) return;
    await ref.read(ledgerRepoProvider).updateExpensesCategoryBatch(ids, picked!);
    ref.invalidate(expensesProvider);
    if (mounted) setState(_selected.clear);
    if (mounted) showAppSnackBar(context, '已把 ${ids.length} 笔账单改了分类');
  }

  int _monthSubtotal(List<ExpenseRecord> list) {
    var sum = 0;
    for (final e in list) {
      if (e.type != ExpenseType.prepay) sum += e.amountCents;
    }
    return sum;
  }

  int _daySubtotal(List<ExpenseRecord> list) {
    var sum = 0;
    for (final e in list) {
      if (e.type != ExpenseType.prepay) sum += e.amountCents;
    }
    return sum;
  }
}

// ---------------------------------------------------------------------------
// 筛选小胶囊
// ---------------------------------------------------------------------------

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 成员色索引（可选的左侧圆点）
  final int? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AvatarPalette.colors[leading! % AvatarPalette.colors.length],
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 吸顶日期分组头
// ---------------------------------------------------------------------------

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.epochDay, required this.subtotal});

  final int epochDay;
  final int subtotal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.sm + 2),
        child: Row(
          children: [
            Text(
              fmtFullDateOfEpoch(epochDay),
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '当日 ',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            MoneyText(subtotal, fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 账单行
// ---------------------------------------------------------------------------

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({
    required this.expense,
    required this.memberName,
    required this.categoryIcon,
    this.selected = false,
    this.checkVisible = false,
    this.onToggleSelect,
  });

  final ExpenseRecord expense;
  final String Function(String memberId) memberName;
  final String categoryIcon;

  /// V2.8.1 S6：批量多选态（勾选圈 + 顶部批量条）。
  final bool selected;
  final bool checkVisible;
  final VoidCallback? onToggleSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = expense.type == ExpenseType.refund;
    final isPrepay = expense.type == ExpenseType.prepay;
    final payerName = expense.payers.isEmpty ? '-' : memberName(expense.payers.first.memberId);

    return InkWell(
      onTap: onToggleSelect ??
          () {
            HapticFeedback.selectionClick();
            showDraggableSheet<void>(
              context: context,
              initialChildSize: 0.62,
              builder: (sheetContext, scrollController) => BillDetailSheet(
                scrollController: scrollController,
                expense: expense,
                memberName: memberName,
                icon: categoryIcon,
              ),
            );
          },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.sm + 3),
        child: Row(
          children: [
            if (checkVisible) ...[
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
            ],
            CategoryIconBox(categoryKey: expense.categoryKey, icon: categoryIcon),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expense.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (isPrepay) ...[
                        const SizedBox(width: 6),
                        ExpenseTypeChip(
                          label: '预付',
                          background: scheme.secondary.withValues(alpha: 0.14),
                          foreground: scheme.secondary,
                        ),
                      ] else if (isRefund) ...[
                        const SizedBox(width: 6),
                        ExpenseTypeChip(
                          label: '退款',
                          background: scheme.errorContainer,
                          foreground: scheme.error,
                        ),
                      ],
                      // S11：支付方式小标签（未标记不占位）。
                      if ((expense.payMethod ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ExpenseTypeChip(
                          label: payMethodLabel(expense.payMethod),
                          background: scheme.surfaceContainerHighest,
                          foreground: scheme.onSurfaceVariant,
                        ),
                      ],
                      // V2.7.1 S12.2：该账单存在未确认冲突时显示小标记（仅提示）。
                      ConflictDot(entityId: expense.id),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    (isRefund ? payerName + ' 收款' : payerName + ' 付款') + ' · 摊 ' +
                        expense.shares.map((s) => s.memberId).toSet().length.toString() +
                        ' 人',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // 退款显示为正（拿回的钱），逻辑层统一按负数参与统计/结算
            MoneyText(isRefund ? -expense.amountCents : expense.amountCents,
                fontSize: AppFontSizes.bodyLarge, semanticColor: true),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 底部合计栏（毛玻璃）
// ---------------------------------------------------------------------------

class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.totalCents,
    required this.count,
    required this.prepayTotalCents,
  });

  final int totalCents;
  final int count;
  final int prepayTotalCents;

  @override
  Widget build(BuildContext context) {
    // V2.8.1 S2：手写毛玻璃收编为 GlassSurface(overlay)。
    return GlassSurface(
      level: GlassLevel.overlay,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
        child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('当前筛选总支出', style: Theme.of(context).textTheme.labelSmall),
                  MoneyText(totalCents, fontSize: AppFontSizes.bodyLarge),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(count.toString() + ' 笔',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTextStyles.tabularFigures)),
                  if (prepayTotalCents != 0)
                    Text('预付另计 ¥' + formatPlain(prepayTotalCents),
                        style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
        ),
      ),
    );
  }

  String formatPlain(int cents) {
    final abs = cents.abs();
    return (cents < 0 ? '-' : '') + (abs ~/ 100).toString() + '.' + (abs % 100).toString().padLeft(2, '0');
  }
}
/// 吸顶日期头的持久化委托
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({required this.child});

  final Widget child;

  static const double _extent = 38;

  @override
  double get maxExtent => _extent;

  @override
  double get minExtent => _extent;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(height: _extent, child: child);
  }
}


/// V2.8.1 S6：月度吸顶头（玻璃 navBar 档）——`2026年10月 · 共 ¥9,214`。
class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate({required this.monthKey, required this.subtotal});

  final int monthKey; // yyyyMM
  final int subtotal;

  static const double _extent = 42;

  @override
  double get maxExtent => _extent;

  @override
  double get minExtent => _extent;

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate oldDelegate) =>
      oldDelegate.monthKey != monthKey || oldDelegate.subtotal != subtotal;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _extent,
      child: GlassSurface(
        level: GlassLevel.navBar,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, 0),
          child: Row(
            children: [
              Text(
                '${monthKey ~/ 100}年${monthKey % 100}月',
              style: TextStyle(
                fontSize: AppFontSizes.body,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
              Text('共 ', style: Theme.of(context).textTheme.labelSmall),
              MoneyText(subtotal,
                  fontSize: AppFontSizes.body, color: scheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}

/// V2.8.1 S6：批量操作条（玻璃 overlay 替代合计栏）。
class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.count,
    required this.totalCents,
    required this.onDelete,
    required this.onChangeCategory,
    required this.onCancel,
  });

  final int count;
  final int totalCents;
  final VoidCallback onDelete;
  final VoidCallback onChangeCategory;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      level: GlassLevel.overlay,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
        child: Row(
          children: [
            GestureDetector(
              onTap: onCancel,
              child: Icon(Icons.close_rounded, size: 20, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                '已选 $count 笔 · ¥${(totalCents.abs() ~/ 100)}.${(totalCents.abs() % 100).toString().padLeft(2, '0')}',
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTextStyles.tabularFigures),
              ),
            ),
            TextButton.icon(
              onPressed: onChangeCategory,
              icon: const Icon(Icons.category_rounded, size: 17),
              label: const Text('改分类'),
              style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
            const SizedBox(width: 2),
            FilledButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('删除'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
