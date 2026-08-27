import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/date_utils.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/bill_detail_sheet.dart';
import '../widgets/category_icon_box.dart';
import '../widgets/stagger_in.dart';

/// 🧾 消费 Tab：粘性日期分组账单流 + 多维筛选 + 合计栏 + CSV 导出。
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _categoryFilter = ''; // '' = 全部
  String _memberFilter = ''; // '' = 全部
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseRecord> _applyFilters(List<ExpenseRecord> all, List<LedgerMemberView> members) {
    final query = _searchController.text.trim().toLowerCase();
    return all.where((e) {
      if (_categoryFilter.isNotEmpty && e.categoryKey != _categoryFilter) return false;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('还没有可导出的账单')));
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

      final dir = await getTemporaryDirectory();
      final groupName = ref.read(activeGroupProvider).value?.name ?? '旅行团';
      final file = File(dir.path + '/旅途账单-' + groupName + '-' + fmtIsoDate(DateTime.now()) + '.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], subject: '旅途账单 CSV');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('导出失败了，再试一次？')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    _buildBody(filtered),
                    Positioned(
                      left: Spacing.xl,
                      right: Spacing.xl,
                      // 合计栏下移贴近底部（避开悬浮胶囊栏即可），减少对滚动账单的遮挡。
                      bottom: AppBottomLayout.withSafeArea(
                        context,
                        AppBottomLayout.actionButtonOffset,
                      ),
                      child: _TotalBar(
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 列表主体：按日分组 + 吸顶日期头
  // ---------------------------------------------------------------------------

  Widget _buildBody(List<ExpenseRecord> expenses) {
    if (expenses.isEmpty) {
      final anyAtAll = (ref.read(expensesProvider).value ?? const <ExpenseRecord>[]).isEmpty;
      return EmptyState(
        emoji: anyAtAll ? '🔍' : '🧾',
        title: anyAtAll ? '没找到匹配的账单' : '一笔都还没记',
        message: anyAtAll ? '换个筛选条件试试' : '点「记一笔」，花销从此有迹可循',
        actionLabel: anyAtAll ? null : '记一笔',
        onAction: anyAtAll ? null : () => context.push('/expenses/edit'),
      );
    }

    final categories = ref.read(categoriesProvider).value ?? const <CategoryView>[];
    final members = ref.read(membersProvider).value ?? const <LedgerMemberView>[];
    final groups = expenses.groupListsBy((e) => e.dateEpochDay);
    final days = groups.keys.toList();

    return CustomScrollView(
      slivers: [
        for (final day in days) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              child: _DateHeader(epochDay: day, subtotal: _daySubtotal(groups[day]!)),
            ),
          ),
          SliverList.builder(
            itemCount: groups[day]!.length,
            itemBuilder: (context, i) => StaggerIn(
              index: i,
              child: _ExpenseTile(
                expense: groups[day]![i],
                memberName: (id) => members.where((m) => m.id == id).firstOrNull?.name ?? '?',
                categoryIcon: categories.where((c) => c.key == groups[day]![i].categoryKey).firstOrNull?.icon ?? '🏷️',
              ),
            ),
          ),
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
  });

  final ExpenseRecord expense;
  final String Function(String memberId) memberName;
  final String categoryIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = expense.type == ExpenseType.refund;
    final isPrepay = expense.type == ExpenseType.prepay;
    final payerName = expense.payers.isEmpty ? '-' : memberName(expense.payers.first.memberId);

    return InkWell(
      onTap: () {
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
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    payerName + ' 付款 · 摊 ' +
                        expense.shares.map((s) => s.memberId).toSet().length.toString() +
                        ' 人',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            MoneyText(expense.amountCents, fontSize: AppFontSizes.bodyLarge, semanticColor: true),
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
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: scheme.brightness == Brightness.dark ? 0.3 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
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

