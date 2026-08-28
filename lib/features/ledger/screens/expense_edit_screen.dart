import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../../../data/providers.dart';
import '../widgets/category_icon_box.dart';
import '../widgets/member_avatar.dart';

/// 💸 记一笔 / 编辑账单：全 App 录入体验的门面，务必精致。
class ExpenseEditScreen extends ConsumerStatefulWidget {
  const ExpenseEditScreen({super.key});

  @override
  ConsumerState<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends ConsumerState<ExpenseEditScreen> {
  // ---- 表单状态 ----
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _currencyCode = 'CNY';
  double _rate = 1.0;
  ExpenseType _type = ExpenseType.normal;
  ShareMode _shareMode = ShareMode.equal;
  int _dateEpochDay = 0;
  String? _categoryKey;
  String? _tripId;
  String? _tripItemId;

  /// 选中的付款人与每人金额（分）
  final Set<String> _payerIds = {};
  final Map<String, TextEditingController> _payerAmounts = {};

  /// 按份数模式的份数表
  final Map<String, int> _portions = {};

  /// 按份数模式：勾选参与分摊的成员（默认全部，可取消）
  final Set<String> _portionParticipants = {};

  /// 自定义分摊的每人口径（分，来自文本框实时解析）
  final Map<String, int> _customShares = {};

  /// 每成员的自定义金额控制器（必须持久持有，避免重建打断输入）
  final Map<String, TextEditingController> _customCtrls = {};

  String? _editingId;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _dateEpochDay = todayEpochDay();
    // 后台同步真实汇率（12h 节流，失败静默），成功后刷新汇率缓存
    Future(() async {
      final updated = await ref.read(exchangeRateServiceProvider).refreshIfStale();
      if (updated && mounted) ref.invalidate(currencyRatesProvider);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // 编辑模式：/expenses/edit?id=xxx
    final uri = GoRouterState.of(context).uri;
    final editId = uri.queryParameters['id'];
    if (editId == null || editId.isEmpty) {
      _categoryKey = 'food';
      return;
    }
    final expenses = ref.read(expensesProvider).value ?? const <ExpenseRecord>[];
    for (final e in expenses) {
      if (e.id == editId) {
        _editingId = e.id;
        _titleController.text = e.title;
        _noteController.text = e.note ?? '';
        _type = e.type;
        _shareMode = e.shareMode;
        _currencyCode = e.currency;
        _rate = e.rate;
        _dateEpochDay = e.dateEpochDay <= 0 ? todayEpochDay() : e.dateEpochDay;
        _categoryKey = e.categoryKey;
        _tripId = e.tripId;
        _tripItemId = e.tripItemId;
        // 输入框回填「原始口径」：非 CNY 回填外币原额，否则回填折算额
        final sourceCents =
            (_currencyCode == 'CNY' || e.amountForeignCents == null) ? e.amountCents.abs() : e.amountForeignCents!.abs();
        _amountController.text = sourceCents % 100 == 0
            ? (sourceCents ~/ 100).toString()
            : (sourceCents ~/ 100).toString() + '.' + (sourceCents % 100).toString().padLeft(2, '0');
        for (final p in e.payers) {
          _payerIds.add(p.memberId);
          _payerAmounts
              .putIfAbsent(p.memberId, () => TextEditingController())
              .text = p.cents.abs() % 100 == 0
                  ? (p.cents.abs() ~/ 100).toString()
                  : (p.cents.abs() ~/ 100).toString() +
                      '.' +
                      (p.cents.abs() % 100).toString().padLeft(2, '0');
        }
        if (e.portions != null) _portions.addAll(e.portions!);
        for (final s in e.shares) {
          // 参与分摊的成员：按份数/平均模式下即 shares 中出现的人
          if (e.shareMode == ShareMode.equal || e.shareMode == ShareMode.portions) {
            _portionParticipants.add(s.memberId);
          }
          _customShares[s.memberId] = s.cents.abs();
        }
        break;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (final c in _payerAmounts.values) {
      c.dispose();
    }
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- 派生数值 ----

  CurrencyView get _currency {
    final list = ref.read(currenciesProvider).value ?? const <CurrencyView>[];
    for (final c in list) {
      if (c.code == _currencyCode) return c;
    }
    return const CurrencyView(code: 'CNY', symbol: '¥', name: '人民币', defaultRate: 1);
  }

  /// 用户输入的外币口径总额（分）；非法输入返回 null
  int? get _inputCents => parseMoney(_amountController.text);

  /// 折算人民币后的总额（分，正数口径）
  int get _cnyTotalAbs {
    final raw = _inputCents;
    if (raw == null) return 0;
    return (_currencyCode == 'CNY') ? raw : (raw * _rate).round();
  }

  /// 落库金额：退款/预付/普通一律存正数；正向性由 type 区分（退款=退款收入/收款）
  int get _signedTotal => _cnyTotalAbs;

  List<LedgerMemberView> get _members =>
      ref.watch(membersProvider).value ?? const <LedgerMemberView>[];

  List<String> get _memberIds => _members.map((m) => m.id).toList();

  String memberNameOf(String id) {
    for (final m in _members) {
      if (m.id == id) return m.name;
    }
    return '?';
  }

  /// 预览分摊结果（equal/portions 引擎算，custom 用矩阵值）
  List<ShareEntry>? get _previewShares {
    final ids = _memberIds;
    if (ids.isEmpty || _cnyTotalAbs <= 0) return null;
    switch (_shareMode) {
      case ShareMode.equal:
      case ShareMode.portions:
        // 支持只勾选部分成员参与分摊；默认全员参与
        final participants = _shareMode == ShareMode.portions
            ? ids.where(_portionParticipants.contains).toList()
            : ids.toList();
        if (participants.isEmpty) return null;
        try {
          return computeSplit(
            totalCents: _cnyTotalAbs,
            memberIds: participants,
            mode: _shareMode,
            portions: _shareMode == ShareMode.portions ? _portions : null,
          );
        } on ArgumentError {
          return null;
        }
      case ShareMode.custom:
        var sum = 0;
        for (final v in _customShares.values) {
          sum += v;
        }
        if (sum != _cnyTotalAbs) return null;
        return [
          for (final id in ids)
            if (_customShares[id] != null && _customShares[id]! > 0)
              ShareEntry(memberId: id, cents: _customShares[id]!)
        ];
    }
  }

  /// 付款合计与总额的差（分）：0 为平衡
  int get _payerDiff {
    // 付款人金额统一按人民币元输入，直接与折算总额比较
    var sum = 0;
    for (final id in _payerIds) {
      sum += parseMoney(_payerAmounts[id]?.text ?? '') ?? 0;
    }
    return _cnyTotalAbs - sum;
  }

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) return false;
    if (_inputCents == null || _cnyTotalAbs <= 0) return false;
    if (_categoryKey == null) return false;
    if (_payerIds.isEmpty) return false;
    if (_payerDiff != 0) return false;
    if (_previewShares == null || _previewShares!.isEmpty) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) {
      HapticFeedback.selectionClick();
      final message = _titleController.text.trim().isEmpty
          ? '请填写账单名称'
          : _inputCents == null || _cnyTotalAbs <= 0
              ? '请填写有效金额'
              : _payerIds.isEmpty
                  ? '请选择付款人'
                  : _payerDiff != 0
                      ? '请让付款合计与账单金额一致'
                      : '请完善账单分类和分摊信息';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    HapticFeedback.lightImpact();
    final shares = _previewShares!;
    const sign = 1; // 退/预付/普通统一正向入账，方向由 type 与 payers（收款人）决定
    // 激活团必须存在：否则落到空 groupId 的「幽灵账单」，任何列表都查不到，
    // 表现为「记账成功却不显示」。宁可拦截保存并提示，也不写脏数据。
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null || gid.isEmpty) {
      HapticFeedback.selectionClick();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('还没有激活的旅行团，请先在「我的」里新建或切换团'),
          ));
      }
      return;
    }
    final draft = ExpenseDraft(
      id: _editingId,
      groupId: gid,
      dateEpochDay: _dateEpochDay,
      title: _titleController.text.trim(),
      categoryKey: _categoryKey!,
      type: _type,
      amountCents: _signedTotal,
      currency: _currencyCode,
      rate: _rate,
      amountForeignCents: _currencyCode == 'CNY'
          ? null
          : sign * (_inputCents ?? 0),
      payers: [
        for (final id in _payerIds)
          ShareEntry(
            memberId: id,
            cents: sign * (parseMoney(_payerAmounts[id]?.text ?? '') ?? 0),
          ),
      ],
      shares: [for (final s in shares) ShareEntry(memberId: s.memberId, cents: s.cents * sign)],
      shareMode: _shareMode,
      portions: _shareMode == ShareMode.portions ? Map.of(_portions) : null,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      tripId: _tripId,
      tripItemId: _tripItemId,
    );
    try {
      await saveExpense(ref, draft);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
      return;
    }
    if (!mounted) return;
    // 显式刷新账单相关流：落库后保证返回列表/账本立即显示这条新记录，
    // 避免个别环境下 StreamProvider 未及时推送导致「显示成功却看不到」。
    ref.invalidate(expensesProvider);
    ref.invalidate(settlementsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_editingId == null ? '已记下这一笔 ✅' : '已更新这笔账 ✅'),
    ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = _type == ExpenseType.refund;
    final amountColor = isRefund ? SemanticColors.income : scheme.onSurface;
    final members = _members;

    return Scaffold(
      appBar: GlassAppBar(
        title: _editingId == null ? '记一笔' : '编辑账单',
        leading: BackButton(onPressed: () => context.pop()),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: Spacing.xl, right: Spacing.xl,
            bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.md,
          ),
          child: PrimaryButton(
            label: _editingId == null ? '记下这一笔' : '保存修改',
            expanded: true,
            // 保持按钮可点击，在校验失败时给出原因，避免用户误以为点击无效。
            onPressed: _save,
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: members.isEmpty
          ? EmptyState(
              emoji: '👥',
              title: '先拉人再记账',
              message: '当前团还没有成员，去成员管理里添加吧',
              actionLabel: '去加成员',
              onAction: () => context.pushNamed('members'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxl),
              children: [
                _amountHeader(color: amountColor),
                const SizedBox(height: Spacing.lg),
                _currencyChips(),
                const SizedBox(height: Spacing.md),
                _typeToggles(),
                const SizedBox(height: Spacing.md),
                _metaCard(),
                const SizedBox(height: Spacing.md),
                _payerSection(members: members),
                const SizedBox(height: Spacing.md),
                _splitSection(members: members),
                const SizedBox(height: Spacing.md),
                _categoryGrid(),
                const SizedBox(height: Spacing.md),
                _linkTripCard(),
                const SizedBox(height: Spacing.md),
                _TextFieldCard(
                  controller: _titleController,
                  hint: '这一笔是花在哪儿？（必填）',
                  maxLines: 1,
                  icon: Icons.edit_rounded,
                  maxLength: 30,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Spacing.sm),
                _TextFieldCard(
                  controller: _noteController,
                  hint: '备注（选填）',
                  maxLines: 3,
                  icon: Icons.sticky_note_2_outlined,
                  maxLength: 200,
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：大金额输入
  // ---------------------------------------------------------------------------

  Widget _amountHeader({required Color color}) {
    final scheme = Theme.of(context).colorScheme;
    final cnyPreview = _cnyTotalAbs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xl, Spacing.xl, Spacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.08),
            scheme.primary.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_currency.symbol,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  autofocus: _editingId == null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  cursorColor: scheme.primary,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: AppTextStyles.tabularFigures,
                    letterSpacing: -0.5,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: '0',
                    hintStyle: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: scheme.outlineVariant),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              if (_currencyCode != 'CNY')
                Text('按 1 ' + _currencyCode + ' = ' + _rate.toStringAsFixed(4) + ' 元折合约 ¥' +
                    (cnyPreview ~/ 100).toString() + '.' + ((cnyPreview % 100)).toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.bodySmall)
              else
                Text('单位：人民币元', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(parseMoney(_amountController.text) == null ? '金额格式不对哦' : '',
                  style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.error)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：币种 chips + 汇率抽屉
  // ---------------------------------------------------------------------------

  Widget _currencyChips() {
    final currencies = ref.watch(currenciesProvider).value ?? const <CurrencyView>[];
    return SizedBox(
      height: 40,
      child: currencies.isEmpty
          ? SkeletonBox(height: 36, radius: AppRadius.buttonValue)
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: currencies.length,
              separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
              itemBuilder: (context, i) {
                final c = currencies[i];
                final selected = c.code == _currencyCode;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _currencyCode = c.code;
                    });
                    if (c.code != 'CNY') await _openRateSheet(c);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? _primary : _containerLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      c.symbol + ' ' + c.code,
                      style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _containerLow => Theme.of(context).colorScheme.surfaceContainerLow;

  /// 汇率小抽屉：预填记忆值，实时显示折合 CNY
  Future<void> _openRateSheet(CurrencyView c) async {
    final rates = ref.read(currencyRatesProvider).value ?? const <String, double>{};
    final remembered = rates[c.code];
    _rate = remembered ?? _rate;
    final controller = TextEditingController(
        text: (remembered ?? c.defaultRate).toStringAsFixed(4));
    await showDraggableSheet<void>(
      context: context,
      initialChildSize: 0.42,
      minChildSize: 0.32,
      builder: (sheetContext, scrollController) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xxl),
          children: [
            Text('设置 ' + c.code + ' 汇率', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text('1 ' + c.code + ' = ? 人民币元 · 会记住下次直接用',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTextStyles.money(context, fontSize: AppFontSizes.headline),
              decoration: InputDecoration(suffixText: '元'),
              onChanged: (_) => setSheetState(() {}),
            ),
            const SizedBox(height: Spacing.lg),
            Builder(builder: (context) {
              final r = double.tryParse(controller.text) ?? 0;
              final raw = _inputCents ?? 0;
              final converted = (raw * r).round();
              return Container(
                padding: const EdgeInsets.all(Spacing.lg),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _containerLow,
                  borderRadius: AppRadius.input,
                ),
                child: Text(
                  '≈ ¥' + (converted ~/ 100).toString() + '.' + (converted % 100).toString().padLeft(2, '0'),
                  style: AppTextStyles.money(context, fontSize: AppFontSizes.title),
                ),
              );
            }),
            const SizedBox(height: Spacing.xl),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: '拉取最新汇率',
                    icon: Icons.currency_exchange_rounded,
                    onPressed: () async {
                      final ok = await ref
                          .read(exchangeRateServiceProvider)
                          .refreshIfStale(force: true);
                      final rates = ok
                          ? await ref.read(prefsRepoProvider).getCurrencyRates()
                          : null;
                      final fresh = rates?[c.code];
                      if (fresh != null && sheetContext.mounted) {
                        controller.text = fresh.toStringAsFixed(4);
                        setSheetState(() {});
                      }
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                          content: Text(ok
                              ? '已更新为最新汇率'
                              : '拉取失败，检查网络后重试或手动输入'),
                        ));
                      }
                      if (ok && mounted) ref.invalidate(currencyRatesProvider);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            PrimaryButton(
              label: '用这个汇率',
              expanded: true,
              onPressed: () async {
                HapticFeedback.lightImpact();
                final r = double.tryParse(controller.text) ?? 0;
                if (r > 0) {
                  await rememberRate(ref, c.code, r);
                  if (mounted) setState(() => _rate = r);
                }
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：退款 / 预付 互斥开关
  // ---------------------------------------------------------------------------

  Widget _typeToggles() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _TypeToggleCard(
            emoji: '↩️',
            title: '退款',
            active: _type == ExpenseType.refund,
            activeColor: scheme.error,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _type = _type == ExpenseType.refund ? ExpenseType.normal : ExpenseType.refund;
              });
            },
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _TypeToggleCard(
            emoji: '🛫',
            title: '预付款',
            active: _type == ExpenseType.prepay,
            activeColor: scheme.secondary,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _type = _type == ExpenseType.prepay ? ExpenseType.normal : ExpenseType.prepay;
              });
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：标题 / 日期 / 类型说明
  // ---------------------------------------------------------------------------

  Widget _metaCard() {
    final scheme = Theme.of(context).colorScheme;
    final hint = _type == ExpenseType.refund
        ? '退款是「收到的钱」：由实际收款人拿到，并平摊回给各位成员'
        : _type == ExpenseType.prepay
            ? '预付款不计入日常支出，结算时单独算'
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(hint, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        Material(
          color: _containerLow,
          borderRadius: AppRadius.card,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(fmtFullDateOfEpoch(_dateEpochDay),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: epochDayToDate(_dateEpochDay),
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2045),
                    );
                    if (picked != null) {
                      setState(() => _dateEpochDay = dateToEpochDay(picked));
                    }
                  },
                  child: const Text('改日期'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：多人付款
  // ---------------------------------------------------------------------------

  Widget _payerSection({required List<LedgerMemberView> members}) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = _type == ExpenseType.refund;
    return _SectionCard(
      title: isRefund ? '谁收到了退款' : '谁付的钱',
      subtitle: isRefund ? '退款由收款人收到，再平摊给各位' : '可多选，金额默认垫全额',
      child: Column(
        children: [
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final m in members)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePayer(m.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 2, vertical: Spacing.xs + 2),
                    decoration: BoxDecoration(
                      color: _payerIds.contains(m.id)
                          ? scheme.primary.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _payerIds.contains(m.id) ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MemberAvatar(member: m, size: 24),
                        const SizedBox(width: 6),
                        Text(m.name, style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_payerIds.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            for (final id in _payerIds)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(
                  children: [
                    MemberAvatar(member: _memberById(id), size: 28),
                    const SizedBox(width: Spacing.sm),
                    Expanded(child: Text(memberNameOf(id), style: Theme.of(context).textTheme.bodyMedium)),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _payerAmounts[id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.money(context),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          prefixText: '¥ ',
                          hintText: '0',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            Builder(builder: (context) {
              final diff = _payerDiff;
              final balanced = diff == 0;
              return Row(
                children: [
                  Icon(
                    balanced ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    size: 15,
                    color: balanced ? SemanticColors.income : scheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    balanced
                        ? '付款合计对上了'
                        : '付款合计还差 ¥' + (diff.abs() ~/ 100).toString() + '.' + (diff.abs() % 100).toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      fontWeight: FontWeight.w600,
                      color: balanced ? SemanticColors.income : scheme.error,
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  LedgerMemberView _memberById(String id) {
    for (final m in _members) {
      if (m.id == id) return m;
    }
    return LedgerMemberView(id: id, name: '?', colorIndex: 0);
  }

  void _togglePayer(String memberId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_payerIds.contains(memberId)) {
        _payerIds.remove(memberId);
      } else {
        _payerIds.add(memberId);
        _payerAmounts.putIfAbsent(memberId, () => TextEditingController());
        // 单一付款人默认垫全额
        if (_payerIds.length == 1) {
          _fillAllToFirst(memberId);
        }
      }
    });
  }

  void _fillAllToFirst(String memberId) {
    final cny = _cnyTotalAbs;
    if (cny <= 0) return;
    _payerAmounts[memberId]?.text = (cny / 100).toStringAsFixed(2);
  }

  // ---------------------------------------------------------------------------
  // 区块：分摊方式
  // ---------------------------------------------------------------------------

  Widget _splitSection({required List<LedgerMemberView> members}) {
    return _SectionCard(
      title: '怎么摊',
      subtitle: '平均 / 按份数 / 各认各的',
      child: Column(
        children: [
          SegmentedButton<ShareMode>(
            showSelectedIcon: false,
            style: ButtonStyle(
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonValue))),
            ),
            segments: const [
              ButtonSegment(value: ShareMode.equal, label: Text('平均')),
              ButtonSegment(value: ShareMode.portions, label: Text('按份数')),
              ButtonSegment(value: ShareMode.custom, label: Text('自定义')),
            ],
            selected: {_shareMode},
            onSelectionChanged: (selection) {
              HapticFeedback.selectionClick();
              setState(() {
                _shareMode = selection.first;
                if (_shareMode == ShareMode.portions) {
                  for (final id in _memberIds) {
                    _portions.putIfAbsent(id, () => 1);
                    _portionParticipants.add(id);
                  }
                }
              });
            },
          ),
          const SizedBox(height: Spacing.md),
          ...switch (_shareMode) {
            ShareMode.equal => [
                Text('共 ' + members.length.toString() + ' 人平摊，余数按顺序自动补齐到人头',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ShareMode.portions => [
                Text('勾选参与分摊的人，再填每人份数（默认全部参与）',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Spacing.xs),
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _portionParticipants.contains(m.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _portionParticipants.add(m.id);
                            } else {
                              _portionParticipants.remove(m.id);
                            }
                          }),
                        ),
                        MemberAvatar(member: m, size: 28),
                        const SizedBox(width: Spacing.sm),
                        Expanded(child: Text(m.name, style: Theme.of(context).textTheme.bodyMedium)),
                        _Stepper(
                          value: _portions[m.id] ?? 1,
                          onChanged: (v) => setState(() => _portions[m.id] = v),
                        ),
                      ],
                    ),
                  ),
              ],
            ShareMode.custom => [
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Row(
                      children: [
                        MemberAvatar(member: m, size: 28),
                        const SizedBox(width: Spacing.sm),
                        Expanded(child: Text(m.name, style: Theme.of(context).textTheme.bodyMedium)),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _customCtrlFor(m.id),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            style: AppTextStyles.money(context),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(prefixText: '¥ ', hintText: '0'),
                            onChanged: (text) {
                              setState(() {
                                final v = parseMoney(text);
                                if (v == null) {
                                  _customShares.remove(m.id);
                                } else {
                                  _customShares[m.id] = v;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                _CustomBalanceHint(),
              ],
          },
          const SizedBox(height: Spacing.sm),
          _SharesPreview(members: members),
        ],
      ),
    );
  }

  TextEditingController _customCtrlFor(String id) => _customCtrls
      .putIfAbsent(id, () => TextEditingController(text: _customSharesText(id)));

  String _customSharesText(String id) {
    final v = _customShares[id];
    if (v == null || v == 0) return '';
    return v % 100 == 0 ? (v ~/ 100).toString() : (v ~/ 100).toString() + '.' + (v % 100).toString().padLeft(2, '0');
  }

  /// 自定义守恒校验：差额红字提示
  Widget _CustomBalanceHint() {
    final scheme = Theme.of(context).colorScheme;
    var sum = 0;
    for (final v in _customShares.values) {
      sum += v;
    }
    final diff = _cnyTotalAbs - sum;
    final ok = diff == 0 && _cnyTotalAbs > 0;
    return Row(
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 15, color: ok ? SemanticColors.income : scheme.error),
        const SizedBox(width: 4),
        Text(
          ok ? '各认金额守恒 ✅'
              : diff > 0
                  ? '还有 ¥' + (diff ~/ 100).toString() + '.' + (diff % 100).toString().padLeft(2, '0') + ' 没认领'
                  : '超认领 ¥' + (-diff ~/ 100).toString() + '.' + ((-diff) % 100).toString().padLeft(2, '0'),
          style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: FontWeight.w600,
              color: ok ? SemanticColors.income : scheme.error),
        ),
      ],
    );
  }

  Widget _SharesPreview({required List<LedgerMemberView> members}) {
    final shares = _previewShares;
    if (shares == null || shares.isEmpty) {
      return Text('填好金额后这里实时显示每人应摊', style: Theme.of(context).textTheme.bodySmall);
    }
    final names = {for (final m in members) m.id: m};
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        for (final s in shares)
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (names[s.memberId] != null) MemberAvatar(member: names[s.memberId]!, size: 20),
            const SizedBox(width: 4),
            MoneyText(s.cents, fontSize: AppFontSizes.caption),
            const SizedBox(width: 6),
          ]),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：分类九宫格
  // ---------------------------------------------------------------------------

  Widget _categoryGrid() {
    final categories = ref.watch(categoriesProvider).value ?? const <CategoryView>[];
    return _SectionCard(
      title: '分类',
      subtitle: '内置分类之外，可在「分类管理」自定义',
      action: TextButton.icon(
        onPressed: () => context.pushNamed('categories'),
        icon: const Icon(Icons.tune_rounded, size: 16),
        label: const Text('管理'),
      ),
      child: categories.isEmpty
          ? SkeletonBox(height: 120, radius: AppRadius.inputValue)
          : GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              childAspectRatio: 0.92,
              children: [
                for (final c in categories)
                  _CategoryTile(
                    category: c,
                    selected: c.key == _categoryKey,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _categoryKey = c.key);
                    },
                  ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：关联行程 → 安排 二级联动
  // ---------------------------------------------------------------------------

  Widget _linkTripCard() {
    final scheme = Theme.of(context).colorScheme;
    final trips = ref.watch(tripsInGroupProvider).value ?? const <TripCardView>[];
    final items = _tripId == null
        ? const <TripItemOption>[]
        : (ref.watch(tripItemsProvider(_tripId!)).value ?? const <TripItemOption>[]);

    // 行程被删时清空选择
    if (_tripId != null && !trips.any((t) => t.id == _tripId)) {
      _tripId = null;
      _tripItemId = null;
    }
    if (_tripItemId != null && !items.any((i) => i.id == _tripItemId)) {
      _tripItemId = null;
    }

    return _SectionCard(
      title: '关联行程（选填）',
      subtitle: '选中安排后自动同步记账日期',
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            value: _tripId,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.travel_explore_rounded, size: 20),
              suffixIcon: _tripId == null ? null : IconButton(icon: Icon(Icons.close_rounded,size:18), onPressed: () => setState(() {
                    _tripId = null;
                    _tripItemId = null;
                  })),
            ),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('不关联行程')),
              for (final t in trips)
                DropdownMenuItem<String?>(value: t.id, child: Text(t.emoji + ' ' + t.name)),
            ],
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() {
                _tripId = v;
                _tripItemId = null;
              });
            },
          ),
          if (_tripId != null) ...[
            const SizedBox(height: Spacing.sm),
            DropdownButtonFormField<String?>(
              value: _tripItemId,
              isExpanded: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.place_rounded, size: 20)),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('不关联具体安排')),
                for (final i in items)
                  DropdownMenuItem<String?>(
                    value: i.id,
                    child: Text(i.name + ' · ' + fmtMonthDayOfEpoch(i.dateEpochDay)),
                  ),
              ],
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() {
                  _tripItemId = v;
                  for (final i in items) {
                    if (i.id == v) {
                      _dateEpochDay = i.dateEpochDay;
                    }
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 私有小组件
// ---------------------------------------------------------------------------

/// 大区块卡容器
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child, this.action});

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (action != null) action!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: Spacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// 通用文本输入卡
class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.icon,
    required this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final IconData icon;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        child: Row(
          crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? Spacing.md + 6 : 0),
              child: Icon(icon, size: 19, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                maxLength: maxLength,
                style: maxLines == 1
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  filled: false,
                  hintText: hint,
                  border: InputBorder.none,
                  counterText: '',
                  counterStyle: const TextStyle(fontSize: 10),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 退款 / 预付 切换卡
class _TypeToggleCard extends StatelessWidget {
  const _TypeToggleCard({
    required this.emoji,
    required this.title,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active
          ? activeColor.withValues(alpha: 0.12)
          : (scheme.brightness == Brightness.dark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest),
      borderRadius: AppRadius.button,
      child: InkWell(
        borderRadius: AppRadius.button,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.button,
            border: Border.all(
              color: active ? activeColor : scheme.outlineVariant.withValues(alpha: 0.7),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? activeColor : scheme.onSurface)),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_rounded, size: 15, color: activeColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 份数步进器
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.buttonValue),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 0 ? () { HapticFeedback.selectionClick(); onChanged(value - 1); } : null,
            icon: const Icon(Icons.remove_rounded, size: 17),
          ),
          SizedBox(
            width: 22,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppFontSizes.body,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTextStyles.tabularFigures),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () { HapticFeedback.selectionClick(); onChanged(value + 1); },
            icon: const Icon(Icons.add_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

/// 分类九宫格瓦片
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CategoryView category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer
          : (scheme.brightness == Brightness.dark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow),
      borderRadius: AppRadius.input,
      child: InkWell(
        borderRadius: AppRadius.input,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CategoryIconBox(categoryKey: category.key, icon: category.icon, size: 34),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? scheme.onPrimaryContainer : scheme.onSurface))),
                if (category.builtin) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.lock_outline_rounded, size: 9, color: scheme.onSurfaceVariant),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
