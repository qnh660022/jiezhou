import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collection/collection.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart';
import '../../../data/db/database.dart' show SubBudget;
import '../../../data/providers.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/category_icon_box.dart';
import '../widgets/count_up_text.dart';

/// V2.8.1 S8：子预算流（文件私有 provider，避免与同步层重名）。
final _subBudgetsProvider = StreamProvider<List<SubBudget>>((ref) {
  final gid = ref.watch(activeGroupIdProvider).value;
  if (gid == null) return const Stream.empty();
  return ref.watch(ledgerRepoProvider).watchSubBudgets(gid);
});

/// 🎯 预算管理：开关 + 总额 + 四张实时卡。
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final _amountController = TextEditingController();
  bool _enabled = false;
  String? _syncedGroupId;

  @override
  void initState() {
    super.initState();
    // 首帧从当前团加载预算：build 之前直接回填，避免在 build 中 setState。
    _applyGroup(ref.read(activeGroupProvider).value);
    // 团状态可能异步才就绪，或在别处被切换：变化时再同步表单。
    ref.listen<AsyncValue<LedgerGroupView?>>(activeGroupProvider, (prev, next) {
      final g = next.value;
      if (g != null) setState(() => _applyGroup(g));
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// 把已保存的团预算回填到表单；仅在團 id 变化时执行一次。
  void _applyGroup(LedgerGroupView? g) {
    if (g == null || _syncedGroupId == g.id) return;
    _syncedGroupId = g.id;
    _enabled = g.budgetEnabled;
    final c = g.budgetCents ?? 0;
    _amountController.text =
        c <= 0 ? '' : (c % 100 == 0 ? (c ~/ 100).toString() : (c ~/ 100).toString() + '.' + (c % 100).toString().padLeft(2, '0'));
  }

  Future<void> _save() async {
    final g = ref.read(activeGroupProvider).value;
    if (g == null) return;
    HapticFeedback.lightImpact();
    int? cents;
    var ok = true;
    if (_enabled) {
      cents = parseMoney(_amountController.text);
      ok = cents != null && cents > 0;
    }
    await saveBudget(ref, g.id, _enabled, _enabled ? cents : null);
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok ? '预算已保存 ✅' : '预算金额格式不对，没存上',
      tone: ok ? SnackTone.info : SnackTone.destructive,
    );
    if (ok && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusAsync = ref.watch(budgetStatusProvider);
    final membersCount = (ref.watch(membersProvider).value ?? const <LedgerMemberView>[]).length;
    final status = statusAsync.value ??
        const BudgetStatusView(enabled: false, totalCents: 0, spentCents: 0, remainingCents: 0, percent: 0);
    final over = status.overBudget;
    final accent = over ? scheme.error : scheme.primary;
    final perPerson = membersCount > 0 ? status.spentCents ~/ membersCount : 0;

    final parsedInput = parseMoney(_amountController.text);

    return Scaffold(
      appBar: GlassAppBar(title: '预算'),
      body: ref.watch(activeGroupProvider).value == null
          ? Center(child: Text('先选一个团再来定预算', style: Theme.of(context).textTheme.bodyMedium))
          : ListView(
              // 底部留白统一 120：分支子页同样被悬浮胶囊底栏覆盖，32 不够
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.md, Spacing.xl, Spacing.huge * 2 + Spacing.xxl),
              children: [
                // ---- 开关与金额 ----
                Material(
                  color: scheme.brightness == Brightness.dark
                      ? scheme.surfaceContainerHigh
                      : scheme.surfaceContainerLowest,
                  borderRadius: AppRadius.card,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          activeColor: scheme.primary,
                          title: const Text('开启预算'),
                          subtitle: Text('超支时全 App 变红提醒',
                              style: Theme.of(context).textTheme.bodySmall),
                          value: _enabled,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _enabled = v);
                          },
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 220),
                          crossFadeState: _enabled
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: Spacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _amountController,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: AppTextStyles.money(context, fontSize: AppFontSizes.headline),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  decoration: const InputDecoration(
                                    prefixText: '¥ ',
                                    hintText: '总预算多少元？',
                                  ),
                                ),
                                const SizedBox(height: Spacing.md),
                                PrimaryButton(
                                  label: '保存预算',
                                  expanded: true,
                                  onPressed: _enabled && parsedInput != null && parsedInput > 0 ? _save : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                // ---- 四张实时卡 ----
                Row(
                  children: [
                    Expanded(child: _StatCard(label: '已花', value: status.spentCents, color: scheme.onSurface)),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: _StatCard(
                        label: over ? '已超支' : '剩余',
                        value: status.remainingCents,
                        color: over ? scheme.error : SemanticColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    Expanded(child: _StatCard(label: '人均', value: perPerson, color: scheme.onSurface)),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: over ? scheme.error.withValues(alpha: 0.08) : scheme.surfaceContainerLowest,
                          borderRadius: AppRadius.card,
                          border: Border.all(color: over ? scheme.error : scheme.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('进度', style: Theme.of(context).textTheme.labelSmall),
                            const SizedBox(height: 6),
                            CountUpText(
                              value: status.enabled && status.totalCents > 0
                                  ? (status.percent * 100).round()
                                  : 0,
                              formatter: (v) => v.toString() + '%',
                              style: AppTextStyles.money(context, fontSize: AppFontSizes.title, color: accent),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: status.percent.clamp(0.0, 1.0)),
                                duration: const Duration(milliseconds: 650),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, _) => LinearProgressIndicator(
                                  value: t,
                                  minHeight: 6,
                                  backgroundColor: scheme.surfaceContainerHighest,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  status.enabled
                      ? (over ? '已经花超了，接下来几顿吃泡面吧 🍜' : '预算内自由发挥，玩得开心 ✈️')
                      : '开启预算后，这里实时显示四项关键数字',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.lg),
                // ---- V2.8.1 S8：分类子预算（上限 5；独立口径，不计入总预算）----
                const _SubBudgetSection(),
              ],
            ),
    );
  }
}

/// V2.8.1 S8：分类子预算区。
/// 添加 = 分类选择抽屉（已选置灰，上限 5，超出禁用+提示）；
/// 每行 = 图标 + 进度条（80% amber / 100% red，暗色提亮 0.25）+ 编辑金额 + 删除（L2）。
class _SubBudgetSection extends ConsumerWidget {
  const _SubBudgetSection();

  static const _maxCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final subsAsync = ref.watch(_subBudgetsProvider);
    final subs = subsAsync.value ?? const <SubBudget>[];
    final expenses = ref.watch(expensesProvider).value ?? const <ExpenseRecord>[];
    final categories = ref.watch(categoriesProvider).value ?? const <CategoryView>[];
    final gid = ref.watch(activeGroupIdProvider).value;

    // 当月各分类支出（int 分；预付不计入）
    final now = DateTime.now();
    final monthStart = dateToEpochDay(DateTime(now.year, now.month, 1));
    final monthSpend = <String, int>{};
    for (final e in expenses) {
      if (e.type == ExpenseType.prepay) continue;
      if (e.dateEpochDay < monthStart) continue;
      monthSpend[e.categoryKey] =
          (monthSpend[e.categoryKey] ?? 0) + e.amountCents.abs();
    }
    final atCap = subs.length >= _maxCount;

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
                Text('分类子预算', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: Spacing.sm),
                Text('${subs.length}/$_maxCount',
                    style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: gid == null
                      ? null
                      : atCap
                          ? () => showAppSnackBar(
                              context, '子预算最多 $_maxCount 个，先删一个再添加')
                          : () => _addSubBudget(
                              context, ref, categories, subs, gid),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            Text('独立于总预算：单独盯某几类的月度开销',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.md),
            if (subs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                child: Text(
                    '还没选要盯的分类，点「添加」选一个（最多 $_maxCount 个）',
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              for (final sub in subs)
                _SubBudgetRow(
                  sub: sub,
                  spentCents: monthSpend[sub.categoryKey] ?? 0,
                  categoryName: categories
                          .where((c) => c.key == sub.categoryKey)
                          .firstOrNull
                          ?.name ??
                      sub.categoryKey,
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSubBudget(BuildContext context, WidgetRef ref,
      List<CategoryView> categories, List<SubBudget> subs, String gid) async {
    HapticFeedback.selectionClick();
    final taken = subs.map((e) => e.categoryKey).toSet();
    final picked = await showDraggableSheet<String>(
      context: context,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      builder: (sheetContext, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Text('选一个要盯的分类',
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final c in categories)
            ListTile(
              leading:
                  CategoryIconBox(categoryKey: c.key, icon: c.icon, size: 36),
              title: Text(c.name),
              enabled: !taken.contains(c.key),
              trailing: taken.contains(c.key)
                  ? const Icon(Icons.check_rounded, size: 18)
                  : null,
              onTap: taken.contains(c.key)
                  ? null
                  : () => Navigator.of(sheetContext).pop(c.key),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final amount = await _askAmount(context, '每月上限多少元？');
    if (amount == null || amount <= 0 || !context.mounted) return;
    await ref.read(ledgerRepoProvider).addSubBudget(gid, picked, amount);
    if (context.mounted) showAppSnackBar(context, '子预算已添加');
  }

  Future<int?> _askAmount(BuildContext context, String title,
      {int? initial}) async {
    final controller = TextEditingController(
        text: initial == null || initial <= 0
            ? ''
            : initial % 100 == 0
                ? (initial ~/ 100).toString()
                : (initial ~/ 100).toString() +
                    '.' +
                    (initial % 100).toString().padLeft(2, '0'));
    final result = await showDraggableSheet<int>(
      context: context,
      initialChildSize: 0.4,
      minChildSize: 0.3,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) => setSheetState(() {}),
              decoration: const InputDecoration(prefixText: '¥ '),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (parseMoney(controller.text) ?? 0) <= 0
                  ? null
                  : () =>
                      Navigator.of(sheetContext).pop(parseMoney(controller.text)),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    return result;
  }
}

/// 子预算单行：图标 + 分类名 + 双阈值进度条 + 编辑/删除。
class _SubBudgetRow extends ConsumerWidget {
  const _SubBudgetRow({
    required this.sub,
    required this.spentCents,
    required this.categoryName,
  });

  final SubBudget sub;
  final int spentCents;
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final fraction =
        sub.amount <= 0 ? 0.0 : (spentCents / sub.amount).clamp(0.0, 1.0);
    // 双阈值：80% amber / 100% red；暗色变体提亮 0.25
    Color bar = scheme.primary;
    if (fraction >= 1.0) {
      bar = scheme.error;
    } else if (fraction >= 0.8) {
      bar = SemanticColors.warning;
    }
    final barColor = dark ? Color.lerp(bar, Colors.white, 0.25)! : bar;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIconBox(categoryKey: sub.categoryKey, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(categoryName,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              IconButton(
                tooltip: '改金额',
                onPressed: () async {
                  final amount =
                      await _SubBudgetSection()._askAmount(context, '改金额', initial: sub.amount);
                  if (amount != null && amount > 0) {
                    await ref
                        .read(ledgerRepoProvider)
                        .updateSubBudget(sub.id, amount);
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: '删除子预算',
                onPressed: () async {
                  final ok = await showDangerConfirm(
                    context: context,
                    title: '删除这条子预算？',
                    body: '删除「$categoryName」的子预算？共 1 条，不影响账单数据。',
                    confirmLabel: '删除',
                  );
                  if (ok) {
                    await ref.read(ledgerRepoProvider).deleteSubBudget(sub.id);
                  }
                },
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: scheme.error),
              ),
            ],
          ),
          Row(
            children: [
              Text('¥${spentCents ~/ 100}',
                  style: Theme.of(context).textTheme.labelSmall),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: barColor,
                    ),
                  ),
                ),
              ),
              Text('¥${sub.amount ~/ 100}',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          CountUpText(
            value: value,
            formatter: (v) {
              final neg = v < 0;
              final abs = v.abs();
              final yuan = abs ~/ 100;
              final fen = (abs % 100).toString().padLeft(2, '0');
              return (neg ? '-' : '') + '¥' + yuan.toString() + '.' + fen;
            },
            style: AppTextStyles.money(context, fontSize: AppFontSizes.bodyLarge, color: color),
          ),
        ],
      ),
    );
  }
}
