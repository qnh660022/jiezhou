import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../widgets/count_up_text.dart';

/// 🎯 预算管理：开关 + 总额 + 四张实时卡。
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final _amountController = TextEditingController();
  bool _enabled = false;
  bool _synced = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _syncFromGroup() {
    if (_synced) return;
    final g = ref.read(activeGroupProvider).value;
    if (g == null) return;
    _synced = true;
    setState(() {
      _enabled = g.budgetEnabled;
      final c = g.budgetCents ?? 0;
      _amountController.text =
          c <= 0 ? '' : (c % 100 == 0 ? (c ~/ 100).toString() : (c ~/ 100).toString() + '.' + (c % 100).toString().padLeft(2, '0'));
    });
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '预算已保存 ✅' : '预算金额格式不对，没存上'),
    ));
    if (ok && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    _syncFromGroup();
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
