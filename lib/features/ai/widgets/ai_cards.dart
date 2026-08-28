/// AI 查询结果的原生卡片：由工具直出的结构化数据渲染，
/// 模型不再复述列表，回答只做解读——省 token 且信息密度更高。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/seed/item_types.dart';
import '../../../theme/tokens.dart';
import '../ai_tools.dart' show commitExpenseDraft, commitTravelPack;

/// 卡片入口：按 type 分发到具体卡片。
class AiCardView extends StatelessWidget {
  const AiCardView({super.key, required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'expense_list':
        return _ExpenseListCard(data: data);
      case 'balances':
        return _BalancesCard(data: data);
      case 'budget':
        return _BudgetCard(data: data);
      case 'settlements':
        return _SettlementsCard(data: data);
      case 'trip_list':
        return _TripListCard(data: data);
      case 'schedule':
        return _ScheduleCard(data: data);
      case 'checklist':
        return _ChecklistCard(data: data);
      case 'expense_confirm':
        return ExpenseConfirmCard(args: (data['args'] as Map?)?.cast<String, dynamic>() ?? const {});
      case 'travel_pack':
        return TravelPackCard(
            plan: (data['plan'] as Map?)?.cast<String, dynamic>() ?? const {});
      default:
        return _CardShell(
          child: Text('（不支持的数据卡片）', style: TextStyle(fontSize: AppFontSizes.caption)),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// 通用骨架与小部件
// ---------------------------------------------------------------------------

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.title, this.trailing});

  final String? title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.85),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Text(title!,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: AppFontSizes.body)),
                  const Spacer(),
                  if (trailing != null)
                    Text(trailing!,
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            color: scheme.primary,
                            fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: Spacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

double _d(Object? v) => v is num ? v.toDouble() : 0;

String _money(Object? yuan, {bool signed = false}) {
  final v = _d(yuan);
  final s = v.abs().toStringAsFixed(2);
  if (signed) return v > 0 ? '+¥$s' : v < 0 ? '-¥${v.abs().toStringAsFixed(2)}' : '¥0.00';
  return '¥$s';
}

String _mmdd(String iso) => iso.length >= 10 ? iso.substring(5).replaceAll('-', '/') : iso;

Widget _kvRow(BuildContext context, String label, String value, {Color? valueColor}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 账单明细卡
// ---------------------------------------------------------------------------

class _ExpenseListCard extends StatelessWidget {
  const _ExpenseListCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = (data['items'] as List?)?.cast<Map>() ?? const [];
    final shown = items.take(20).toList();
    return _CardShell(
      title: '消费明细',
      trailing: '${items.length} 笔 · 合计 ${_money(data['totalYuan'])}',
      child: items.isEmpty
          ? Text('没有符合条件的账单',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(_mmdd(e['date'] as String? ?? ''),
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text('${e['title']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: AppFontSizes.caption)),
                        ),
                        Text(_money(e['yuan'], signed: true),
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                fontWeight: FontWeight.w700,
                                color: _d(e['yuan']) < 0
                                    ? SemanticColors.income
                                    : SemanticColors.expense)),
                      ],
                    ),
                  ),
                if (items.length > shown.length)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Text('还有 ${items.length - shown.length} 条…',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                  ),
                if (_d(data['prepayYuan']) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Text('预付另计 ${_money(data['prepayYuan'])}',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 余额榜卡
// ---------------------------------------------------------------------------

class _BalancesCard extends StatelessWidget {
  const _BalancesCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final board = (data['board'] as List?)?.cast<Map>() ?? const [];
    final transfers = (data['suggestTransfers'] as List?)?.cast<Map>() ?? const [];
    return _CardShell(
      title: '成员余额',
      trailing: '正数=应收',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in board)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${b['member']}',
                        style: const TextStyle(fontSize: AppFontSizes.caption)),
                  ),
                  Text(
                    '${_money(b['balanceYuan'], signed: true)}',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        fontWeight: FontWeight.w700,
                        color: _d(b['balanceYuan']) >= 0
                            ? SemanticColors.income
                            : SemanticColors.expense),
                  ),
                ],
              ),
            ),
          if (transfers.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Text('建议转账', style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w800, color: scheme.primary)),
            for (final t in transfers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                    '${t['from']} → ${t['to']}  ${_money(t['yuan'])}',
                    style: TextStyle(fontSize: AppFontSizes.caption)),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 预算卡
// ---------------------------------------------------------------------------

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = data['enabled'] == true;
    final percent = _d(data['percent']).clamp(0.0, 1.0);
    final over = _d(data['spentYuan']) > _d(data['totalYuan']);
    return _CardShell(
      title: '预算',
      trailing: enabled ? '${(percent * 100).toStringAsFixed(0)}%' : '未开启',
      child: enabled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
                    color: over ? scheme.error : scheme.primary,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                _kvRow(context, '总额', _money(data['totalYuan'])),
                _kvRow(context, '已花', _money(data['spentYuan']),
                    valueColor: over ? scheme.error : null),
                _kvRow(context, '剩余', _money(data['remainingYuan']),
                    valueColor: over ? scheme.error : SemanticColors.income),
              ],
            )
          : Text('当前团未开启预算，可以让我帮你设置。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
    );
  }
}

// ---------------------------------------------------------------------------
// 结算卡
// ---------------------------------------------------------------------------

class _SettlementsCard extends StatelessWidget {
  const _SettlementsCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rounds = (data['rounds'] as List?)?.cast<Map>() ?? const [];
    if (data['hasActive'] != true) {
      return _CardShell(
        title: 'AA 结算',
        child: Text('当前没有进行中的结算轮。',
            style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
      );
    }
    return _CardShell(
      title: 'AA 结算',
      trailing: '进行中',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rounds) ...[
            for (final t in (r['transfers'] as List?)?.cast<Map>() ?? const <Map>[])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      t['confirmed'] == true
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: t['confirmed'] == true ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text('${t['from']} → ${t['to']}',
                          style: const TextStyle(fontSize: AppFontSizes.caption)),
                    ),
                    Text(_money(t['yuan']),
                        style: const TextStyle(
                            fontSize: AppFontSizes.caption, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
          Text('逐笔确认请到「账本 → AA 结算」页操作。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 行程列表卡
// ---------------------------------------------------------------------------

class _TripListCard extends StatelessWidget {
  const _TripListCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trips = (data['trips'] as List?)?.cast<Map>() ?? const [];
    return _CardShell(
      title: '行程',
      trailing: '${trips.length} 个',
      child: trips.isEmpty
          ? Text('还没有行程，可以让我帮你创建。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in trips)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('${t['emoji']}', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t['name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: AppFontSizes.caption,
                                      fontWeight: FontWeight.w700)),
                              Text('${_mmdd(t['start'] as String? ?? '')} ~ ${_mmdd(t['end'] as String? ?? '')} · ${t['destination']}',
                                  style: TextStyle(
                                      fontSize: AppFontSizes.caption,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 日程卡
// ---------------------------------------------------------------------------

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = (data['items'] as List?)?.cast<Map>() ?? const [];
    final rows = <Widget>[];
    String? lastDate;
    for (final i in items) {
      final date = i['date'] as String? ?? '';
      if (date != lastDate) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: Spacing.xs));
        rows.add(Text(_mmdd(date),
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary)));
        lastDate = date;
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(findTripItemType(i['type'] as String? ?? 'note').icon,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                  '${i['time'] == null ? '' : '${i['time']}  '}'
                  '${i['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppFontSizes.caption)),
            ),
            if (i['costYuan'] != null)
              Text(_money(i['costYuan']),
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ));
    }
    return _CardShell(
      title: '日程 · ${data['trip'] ?? ''}',
      trailing: '${items.length} 项',
      child: rows.isEmpty
          ? Text('还没有安排，可以让我帮你排。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

// ---------------------------------------------------------------------------
// 清单卡
// ---------------------------------------------------------------------------

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = (data['items'] as List?)?.cast<Map>() ?? const [];
    final done = items.where((i) => i['done'] == true).length;
    return _CardShell(
      title: '清单',
      trailing: '$done/${items.length} 已备好',
      child: items.isEmpty
          ? Text('清单是空的，可以让我帮你加几项。',
              style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in items.take(20))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          i['done'] == true
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 16,
                          color: i['done'] == true ? scheme.primary : scheme.outline,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text('${i['label']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption,
                                  decoration: i['done'] == true
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: i['done'] == true
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface)),
                        ),
                      ],
                    ),
                  ),
                if (items.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Text('还有 ${items.length - 20} 项…',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 记账确认卡（可交互）：点确认本地落库，零 AI 消耗
// ---------------------------------------------------------------------------

/// AI 记账确认卡：展示待记账单全部要素，确认后由 [commitExpenseDraft]
/// 在本地落库——不发任何网络请求、不消耗 token。
class ExpenseConfirmCard extends ConsumerStatefulWidget {
  const ExpenseConfirmCard({super.key, required this.args});

  final Map<String, dynamic> args;

  @override
  ConsumerState<ExpenseConfirmCard> createState() => _ExpenseConfirmCardState();
}

class _ExpenseConfirmCardState extends ConsumerState<ExpenseConfirmCard> {
  bool _committing = false;
  String? _error;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final args = widget.args;
    final isRefund = args['expenseType'] == 'refund';
    final yuan = (args['amountYuan'] as num?)?.toDouble() ?? 0;
    final share = (args['shareMembers'] as List?)?.cast<Object>() ?? const [];
    final currency = args['currencyCode'] as String? ?? 'CNY';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.85),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(
              color: scheme.primary.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(isRefund ? Icons.replay_rounded : Icons.receipt_long_rounded,
                  size: 18, color: scheme.primary),
              const SizedBox(width: Spacing.sm),
              Text('确认记账',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: AppFontSizes.body)),
              const Spacer(),
              Text('${args['date'] ?? ''}',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${isRefund ? '-' : ''}$currency',
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: FontWeight.w700,
                      color: isRefund ? SemanticColors.income : scheme.onSurface),
                ),
                const SizedBox(width: 4),
                Text(
                  yuan.abs().toStringAsFixed(yuan.abs() % 1 == 0 ? 0 : 2),
                  style: AppTextStyles.money(context,
                      fontSize: AppFontSizes.headline,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text('${args['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            _kvRow(context, '付款人', '${args['payerName'] ?? '-'}'),
            _kvRow(context, '分摊',
                share.isEmpty ? '全体成员' : share.join('、') + '（均摊）'),
            _kvRow(context, '分类', '${args['categoryName'] ?? args['categoryKey'] ?? '其他'}'),
            if ((args['note'] as String? ?? '').isNotEmpty)
              _kvRow(context, '备注', '${args['note']}'),
            const SizedBox(height: Spacing.lg),
            if (_done)
              Row(children: [
                Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Text('已记账，可在账本中查看',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700)),
              ])
            else if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.error)),
              const SizedBox(height: Spacing.sm),
              _buildConfirmButton(scheme),
            ] else
              _buildConfirmButton(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _committing ? null : () => setState(() => _error = '已取消，未记账'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: FilledButton.icon(
            onPressed: _committing ? null : _confirm,
            icon: _committing
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('确认记账'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _committing = true;
      _error = null;
    });
    final err = await commitExpenseDraft(ref, widget.args);
    if (!mounted) return;
    if (err == null) {
      setState(() {
        _committing = false;
        _done = true;
      });
    } else {
      setState(() {
        _committing = false;
        _error = err;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// 一键旅行包卡（可交互）：预览完整方案，点「一键生成」全部本地落库
// ---------------------------------------------------------------------------

/// AI 一键旅行包预览卡：展示 建团+成员+预算+行程+日程+清单+样例账单，
/// 确认后由 [commitTravelPack] 在本地一次性落库——零 token、零 AI 请求。
class TravelPackCard extends ConsumerStatefulWidget {
  const TravelPackCard({super.key, required this.plan});

  final Map<String, dynamic> plan;

  @override
  ConsumerState<TravelPackCard> createState() => _TravelPackCardState();
}

class _TravelPackCardState extends ConsumerState<TravelPackCard> {
  bool _committing = false;
  String? _error;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.plan;
    final members = (p['memberNames'] as List?)?.cast<Object>() ?? const [];
    final budgetYuan = (p['budgetYuan'] as num?)?.toDouble();
    final days = (p['days'] as List?)?.cast<Map>() ?? const [];
    final checklist = (p['checklist'] as List?) ?? const [];
    final bills = (p['sampleExpenses'] as List?) ?? const [];
    var billTotal = 0.0;
    for (final b in bills) {
      billTotal += _d((b as Map)['amountYuan']);
    }

    String mmdd(String iso) => _mmdd(iso);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.85),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.luggage_rounded, size: 18, color: _primary),
              const SizedBox(width: Spacing.sm),
              const Text('一键旅行包',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppFontSizes.body)),
              const Spacer(),
              Text('🧳 ${mmdd(p['startDate'] as String? ?? '')}~${mmdd(p['endDate'] as String? ?? '')}',
                  style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: Spacing.md),
            _kvRow(context, '旅行团', '${p['groupName'] ?? ''} · ${members.length} 人'),
            _kvRow(context, '行程', '${p['tripName'] ?? ''}'),
            _kvRow(context, '目的地', '${p['destination'] ?? ''}'),
            if (budgetYuan != null && budgetYuan > 0)
              _kvRow(context, '预算', _money(budgetYuan)),
            const SizedBox(height: Spacing.sm),
            Text('每日安排',
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary)),
            const SizedBox(height: 4),
            for (final d in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'D${d['day']} · ${(d['items'] as List?)?.length ?? 0} 个安排',
                  style:
                      TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant),
                ),
              ),
            _kvRow(context, '行李清单', '${checklist.length} 项'),
            if (bills.isNotEmpty)
              _kvRow(context, '样例账单', '${bills.length} 笔 · ${_money(billTotal)}'),
            const SizedBox(height: Spacing.lg),
            if (_done)
              Row(children: [
                Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Text('已一键生成，去「账本 / 行程」查看',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700)),
              ])
            else if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.error)),
              const SizedBox(height: Spacing.sm),
              _buildButton(scheme),
            ] else
              _buildButton(scheme),
          ],
        ),
      ),
    );
  }

  static const Color _primary = Color(0xFF2E7D5B);

  Widget _buildButton(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _committing ? null : () => setState(() => _error = '已取消，未生成'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: FilledButton.icon(
            onPressed: _committing ? null : _apply,
            icon: _committing
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('一键生成'),
          ),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    setState(() {
      _committing = true;
      _error = null;
    });
    final err = await commitTravelPack(ref, widget.plan);
    if (!mounted) return;
    if (err == null) {
      setState(() {
        _committing = false;
        _done = true;
      });
    } else {
      setState(() {
        _committing = false;
        _error = err;
      });
    }
  }
}
