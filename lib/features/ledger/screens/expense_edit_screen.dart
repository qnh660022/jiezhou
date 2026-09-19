import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/date_utils.dart';
import '../../../core/money.dart';
import '../../../domain/models.dart';
import '../../../domain/money_expression.dart';
import '../../../domain/share_splitter.dart' show normalizePercentToBp;
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../ledger_models.dart';
import '../ledger_providers.dart';
import '../../../data/providers.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/category_icon_box.dart';
import '../../checklist/widgets/confetti_burst.dart';
import '../widgets/count_up_text.dart';
import '../widgets/member_avatar.dart';

/// V2.8.1 S5：会话级草稿仓库（不持久化到磁盘）。
/// key = 'new' 或 'edit:{id}'；保存成功 / 明确放弃后清除。
class ExpenseFormDraft {
  const ExpenseFormDraft({
    this.moneyDisplay,
    this.title,
    this.note,
    this.categoryKey,
    this.currencyCode,
    this.rate,
    this.type,
    this.shareMode,
    this.dateEpochDay,
    this.payMethod,
    this.payerIds,
    this.tripId,
    this.tripItemId,
  });

  factory ExpenseFormDraft.fromMap(Map<String, Object?> m) => ExpenseFormDraft(
        moneyDisplay: m['money'] as String?,
        title: m['title'] as String?,
        note: m['note'] as String?,
        categoryKey: m['categoryKey'] as String?,
        currencyCode: m['currencyCode'] as String?,
        rate: (m['rate'] as num?)?.toDouble(),
        type: m['type'] as String?,
        shareMode: m['shareMode'] as String?,
        dateEpochDay: m['dateEpochDay'] as int?,
        payMethod: m['payMethod'] as String?,
        payerIds: (m['payerIds'] as List?)?.cast<String>().toSet(),
        tripId: m['tripId'] as String?,
        tripItemId: m['tripItemId'] as String?,
      );

  final String? moneyDisplay;
  final String? title;
  final String? note;
  final String? categoryKey;
  final String? currencyCode;
  final double? rate;
  final String? type;
  final String? shareMode;
  final int? dateEpochDay;
  final String? payMethod;
  final Set<String>? payerIds;
  final String? tripId;
  final String? tripItemId;

  Map<String, Object?> toMap() => {
        if (moneyDisplay != null) 'money': moneyDisplay,
        if (title != null) 'title': title,
        if (note != null) 'note': note,
        if (categoryKey != null) 'categoryKey': categoryKey,
        if (currencyCode != null) 'currencyCode': currencyCode,
        if (rate != null) 'rate': rate,
        if (type != null) 'type': type,
        if (shareMode != null) 'shareMode': shareMode,
        if (dateEpochDay != null) 'dateEpochDay': dateEpochDay,
        if (payMethod != null) 'payMethod': payMethod,
        if (payerIds != null) 'payerIds': payerIds!.toList(),
        if (tripId != null) 'tripId': tripId,
        if (tripItemId != null) 'tripItemId': tripItemId,
      };
}

/// 会话级草稿存取（纯内存，进程结束即失）。
class ExpenseDraftStore {
  ExpenseDraftStore._();
  static final Map<String, ExpenseFormDraft> _drafts = {};

  static const _dirtyKeys = {'money', 'title', 'note'};

  static ExpenseFormDraft? take(String key) => _drafts[key];

  static void put(String key, ExpenseFormDraft d) => _drafts[key] = d;

  static void remove(String key) => _drafts.remove(key);

  /// 是否有「值得拦截」的脏数据（金额/标题/备注任一非空）。
  static bool isDirty(ExpenseFormDraft d) =>
      d.toMap().keys.any(_dirtyKeys.contains);
}

/// 💸 记一笔 / 编辑账单：全 App 录入体验的门面，务必精致。
class ExpenseEditScreen extends ConsumerStatefulWidget {
  const ExpenseEditScreen({super.key, this.initialId});

  /// 编辑模式下待编辑的账单 id。桌面工作台在 Dialog 内复用；移动端/整页跳转
  /// 仍从路由 query `id` 读取（传 null 不影响原逻辑）。
  final String? initialId;

  @override
  ConsumerState<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends ConsumerState<ExpenseEditScreen> {
  // ---- 表单状态 ----
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  /// V2.8.1 S5：金额连算表达式（键盘输入唯一来源，int 分域运算）
  final _money = MoneyExpression();

  String _currencyCode = 'CNY';
  double _rate = 1.0;
  ExpenseType _type = ExpenseType.normal;
  ShareMode _shareMode = ShareMode.equal;
  int _dateEpochDay = 0;
  String? _categoryKey;
  String? _tripId;
  String? _tripItemId;

  /// V2.8.1 S5：「更多选项」当前展开组（页内 AnimatedCrossFade，一次一组；
  /// 空串 = 全部折叠）。组名：currency/type/pay/date/payer/split/trip/note
  String _expandedGroup = '';

  /// V2.8.1 S5：保存成功蒙层（全屏玻璃 + CountUp + 800ms 自动 pop）
  bool _showSavedOverlay = false;
  int _savedAmountForOverlay = 0;
  bool _savedBurst = false;

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

  /// 按百分比模式（S3）：每成员的百分比输入控制器（值 = 百分数，如 33.33）
  final Map<String, TextEditingController> _percentCtrls = {};

  /// 个人账本模式（S4）：隐藏付款人/分摊控件，固定 equal + owner 单人全额。
  bool _personal = false;

  /// 支付方式纯标签（S11）：null = 未标记。
  String? _payMethod;

  /// 内置支付方式（允许自定义串，长度 ≤ 20）。
  static const _payMethods = <String, String>{
    'cash': '现金',
    'credit': '信用卡',
    'debit': '储蓄卡',
    'ewallet': '电子钱包',
    'fund': '公费池',
    'other': '其他',
  };

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

    // 编辑模式：桌面工作台经 initialId 传入；移动端/整页跳转走 /expenses/edit?id=xxx
    String? editId;
    if (widget.initialId != null) {
      editId = widget.initialId;
    } else {
      try {
        editId = GoRouterState.of(context).uri.queryParameters['id'];
      } catch (_) {
        // 桌面工作台以 Dialog 打开（非 go_router 子树）时无 GoRouterState → 按新建。
        editId = null;
      }
    }
    if (editId == null || editId.isEmpty) {
      _categoryKey = 'food';
      // 新建模式支持 query `date`（epochDay）：今日驾驶舱「记一笔」直达当日。
      _applyQueryDate();
      _restoreDraftOrRecent();
      return;
    }    final expenses = ref.read(expensesProvider).value ?? const <ExpenseRecord>[];
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
        _payMethod = e.payMethod;
        // 输入框回填「原始口径」：非 CNY 回填外币原额，否则回填折算额
        final sourceCents =
            (_currencyCode == 'CNY' || e.amountForeignCents == null) ? e.amountCents.abs() : e.amountForeignCents!.abs();
        _money.setText(sourceCents % 100 == 0
            ? (sourceCents ~/ 100).toString()
            : (sourceCents ~/ 100).toString() + '.' + (sourceCents % 100).toString().padLeft(2, '0'));
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
        // percent 模式：portions 存 bp，回填百分比输入框（bp/100 两位小数）。
        if (e.shareMode == ShareMode.percent && e.portions != null) {
          e.portions!.forEach((id, bp) {
            if (bp > 0) {
              _percentCtrls
                  .putIfAbsent(id, () => TextEditingController())
                  .text = (bp / 100).toStringAsFixed(2);
            }
          });
        }
        break;
      }
    }
  }

  /// 新建模式：读路由 query `date`（epochDay）作为初始记账日期。
  ///
  /// 用途：今日驾驶舱「记一笔」直达「行程今日」（可能是目的地当地日期，
  /// 与设备日期不同），因此不能在驾驶舱侧改本地状态，只能把日期传进来。
  /// 解析失败/缺省时保持 [initState] 里的 `todayEpochDay()`。
  void _applyQueryDate() {
    String? raw;
    try {
      raw = GoRouterState.of(context).uri.queryParameters['date'];
    } catch (_) {
      raw = null; // 桌面工作台以 Dialog 打开，无 GoRouterState
    }
    if (raw == null || raw.isEmpty) return;
    final day = int.tryParse(raw);
    if (day == null || day <= 0) return;
    _dateEpochDay = day;
  }

  /// V2.8.1 S5：新建模式优先回填会话草稿；无草稿则套用上次记忆
  ///（SharedPreferences `app.exp.recent`：categoryKey/payMethod/currency）。
  void _restoreDraftOrRecent() {
    final draft = ExpenseDraftStore.take('new');
    if (draft != null) {
      if (draft.moneyDisplay != null) _money.setText(draft.moneyDisplay!);
      if (draft.title != null) _titleController.text = draft.title!;
      if (draft.note != null) _noteController.text = draft.note!;
      if (draft.categoryKey != null) _categoryKey = draft.categoryKey;
      if (draft.currencyCode != null) _currencyCode = draft.currencyCode!;
      if (draft.rate != null) _rate = draft.rate!;
      if (draft.dateEpochDay != null) _dateEpochDay = draft.dateEpochDay!;
      if (draft.payMethod != null) _payMethod = draft.payMethod;
      if (draft.tripId != null) _tripId = draft.tripId;
      if (draft.tripItemId != null) _tripItemId = draft.tripItemId;
      if (draft.type == 'refund') _type = ExpenseType.refund;
      if (draft.type == 'prepay') _type = ExpenseType.prepay;
      if (draft.type == 'normal') _type = ExpenseType.normal;
      if (draft.payerIds != null) _payerIds.addAll(draft.payerIds!);
      return;
    }
    Future(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('app.exp.recent');
      if (raw == null || !mounted) return;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          if (m['categoryKey'] is String && _categoryKey == 'food') {
            _categoryKey = m['categoryKey'] as String;
          }
          if (m['payMethod'] is String) _payMethod = m['payMethod'] as String;
          if (m['currency'] is String && _currencyCode == 'CNY') {
            _currencyCode = m['currency'] as String;
          }
        });
      } catch (_) {
        // 记忆损坏静默忽略
      }
    });
  }

  String get _draftKey => _editingId == null ? 'new' : 'edit:$_editingId';

  /// 抓取当前表单快照（PopScope 离场时存会话草稿）。
  ExpenseFormDraft _captureDraft() => ExpenseFormDraft(
        moneyDisplay: _money.display.isEmpty ? null : _money.display,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        categoryKey: _categoryKey,
        currencyCode: _currencyCode,
        rate: _rate,
        type: _type.name,
        shareMode: _shareMode.name,
        dateEpochDay: _dateEpochDay,
        payMethod: _payMethod,
        payerIds: _payerIds,
        tripId: _tripId,
        tripItemId: _tripItemId,
      );

  /// 草稿是否值得拦截（金额/标题/备注任一非空）。
  bool get _hasDirtyDraft => ExpenseDraftStore.isDirty(_captureDraft());

  /// V2.8.1 S5：保存成功后记忆本次口径（编辑模式不覆盖记忆）。
  Future<void> _rememberRecent() async {
    if (_editingId != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'app.exp.recent',
        jsonEncode({
          'categoryKey': _categoryKey,
          'payMethod': _payMethod,
          'currency': _currencyCode,
        }),
      );
    } catch (_) {
      // 记忆失败不影响保存主流程
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    for (final c in _payerAmounts.values) {
      c.dispose();
    }
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    for (final c in _percentCtrls.values) {
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

  /// 用户输入的外币口径总额（分）；非法输入返回 null。
  /// V2.8.1 S5：来源 = 连算表达式（int 分域），不再走 TextField。
  int? get _inputCents => _money.totalFen;

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
    // S2 G1：悬空 memberId（仅存量物理删除数据）兜底为「已移除成员」。
    return '已移除成员';
  }

  /// 百分比原始输入 → bp（hundredths→bp，即百分数×100）；仅取 >0。
  Map<String, int> get _rawPercentBp {
    final out = <String, int>{};
    for (final id in _memberIds) {
      final text = _percentCtrls[id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final v = double.tryParse(text);
      if (v != null && v > 0) out[id] = (v * 100).round();
    }
    return out;
  }

  /// 归一后的 bp 表（Σ==10000）；空表示未填，回退 equal。
  Map<String, int> get _normalizedPercentBp => normalizePercentToBp(_rawPercentBp);

  /// 百分比合计（百分数），用于实时守恒提示。
  double get _percentSum =>
      _percentCtrls.values.fold<double>(0, (a, c) {
        final v = double.tryParse(c.text.trim());
        return a + (v ?? 0);
      });

  /// percent 模式是否因「全空」回退 equal（落库时把 shareMode 归为 equal）。
  bool get _percentFallsBackToEqual =>
      _shareMode == ShareMode.percent && _rawPercentBp.isEmpty;

  /// 预览分摊结果（equal/portions/percent 引擎算，custom 用矩阵值）
  List<ShareEntry>? get _previewShares {
    final ids = _memberIds;
    if (ids.isEmpty || _cnyTotalAbs <= 0) return null;
    // S4：个人账本固定 owner 单人全额（不提供分摊编辑）。
    if (_personal) {
      return [ShareEntry(memberId: ids.first, cents: _cnyTotalAbs)];
    }
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
      case ShareMode.percent:
        // 未填/全空 → 回退 equal（引擎内同为该口径）
        if (_rawPercentBp.isEmpty) {
          try {
            return computeSplit(
                totalCents: _cnyTotalAbs, memberIds: ids, mode: ShareMode.equal);
          } on ArgumentError {
            return null;
          }
        }
        try {
          return computeSplit(
            totalCents: _cnyTotalAbs,
            memberIds: ids,
            mode: ShareMode.percent,
            portions: _normalizedPercentBp,
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
    // S4：个人账本无付款人/分摊编辑，跳过这两项校验。
    if (!_personal) {
      if (_payerIds.isEmpty) return false;
      if (_payerDiff != 0) return false;
    }
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
              : (!_personal && _payerIds.isEmpty)
                  ? '请选择付款人'
                  : (!_personal && _payerDiff != 0)
                      ? '请让付款合计与账单金额一致'
                      : '请完善账单分类和分摊信息';
      if (mounted) showAppSnackBar(context, message);
      return;
    }
    HapticFeedback.lightImpact();
    final shares = _previewShares!;
    // 退款 = 收到退回的钱（收款人在 payers 内），落库统一取负号，
    // 与 core/money.dart「refund 为负」约定一致，结算/统计才会正确冲减。
    final sign = _type == ExpenseType.refund ? -1 : 1;
    // 激活团必须存在：否则落到空 groupId 的「幽灵账单」，任何列表都查不到，
    // 表现为「记账成功却不显示」。宁可拦截保存并提示，也不写脏数据。
    final gid = ref.read(activeGroupIdProvider).value;
    if (gid == null || gid.isEmpty) {
      HapticFeedback.selectionClick();
      if (mounted) {
        showAppSnackBar(context, '还没有激活的旅行团，请先在「我的」里新建或切换团',
            tone: SnackTone.destructive);
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
      // S4：个人账本付款人固定 owner、金额全额（与 shares 同为单人）。
      payers: _personal
          ? [ShareEntry(memberId: shares.first.memberId, cents: sign * _cnyTotalAbs)]
          : [
              for (final id in _payerIds)
                ShareEntry(
                  memberId: id,
                  cents: sign * (parseMoney(_payerAmounts[id]?.text ?? '') ?? 0),
                ),
            ],
      shares: [for (final s in shares) ShareEntry(memberId: s.memberId, cents: s.cents * sign)],
      shareMode:
          _personal ? ShareMode.equal : (_percentFallsBackToEqual ? ShareMode.equal : _shareMode),
      // percent 模式落库为归一后 bp（Σ==10000）；全空回退 equal（portions 传 null）。
      portions: _shareMode == ShareMode.portions
          ? Map.of(_portions)
          : _shareMode == ShareMode.percent && !_percentFallsBackToEqual
              ? _normalizedPercentBp
              : null,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      tripId: _tripId,
      tripItemId: _tripItemId,
      payMethod: _payMethod,
    );
    try {
      await saveExpense(ref, draft);
    } catch (error) {
      if (mounted) showAppSnackBar(context, '保存失败，请重试', tone: SnackTone.destructive);
      return;
    }
    if (!mounted) return;
    // 显式刷新账单相关流：落库后保证返回列表/账本立即显示这条新记录，
    // 避免个别环境下 StreamProvider 未及时推送导致「显示成功却看不到」。
    ref.invalidate(expensesProvider);
    ref.invalidate(settlementsProvider);
    // V2.8.1 S5：草稿清除 + 默认值记忆 + 保存成功蒙层（键盘即保存的收尾反馈）
    ExpenseDraftStore.remove(_draftKey);
    await _rememberRecent();
    if (!mounted) return;
    // 今日第 N 笔（用于蒙层彩带）：先读后加
    final now = DateTime.now();
    final dayKey =
        'app.exp.count.${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    final todayCount = (prefs.getInt(dayKey) ?? 0) + 1;
    setState(() {
      _savedAmountForOverlay = _signedTotal;
      _savedBurst = _editingId == null && {3, 5, 10}.contains(todayCount);
      _showSavedOverlay = true;
    });
    await prefs.setInt(dayKey, todayCount);
    // 800ms 后自动 pop（「再记一笔」可点跳过等待）
    Timer(const Duration(milliseconds: 800), () {
      if (mounted && _showSavedOverlay) _finishAfterOverlay();
    });
  }

  /// 蒙层 800ms 后自动 pop（编辑模式直接 pop；新建模式经「再记一笔」跳过等待）。
  void _finishAfterOverlay() {
    if (!mounted) return;
    if (_editingId != null) {
      context.pop();
    } else {
      // 新建模式：蒙层期结束自动收场（pop 到来源页）
      context.pop();
    }
  }

  /// V2.8.1 S5：再记一笔 —— 金额/标题/备注清零，保留分类/支付方式/币种/日期；
  /// 连续计数徽章「今日第 N 笔」（第 3/5/10 笔触发彩带）。
  Future<void> _anotherOne() async {
    setState(() {
      _money.clear();
      _titleController.clear();
      _showSavedOverlay = false;
    });
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dayKey =
        'app.exp.count.${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final n = (prefs.getInt(dayKey) ?? 0) + 1;
    await prefs.setInt(dayKey, n);
    if (!mounted) return;
    showAppSnackBar(context, '今日第 $n 笔，继续保持 ✍️');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = _type == ExpenseType.refund;
    final amountColor = isRefund ? SemanticColors.income : scheme.onSurface;
    final members = _members;
    // S4：个人账本隐藏付款人/分摊控件（内部固定 equal + owner 单人全额）。
    _personal = ref.watch(activeGroupProvider).value?.isPersonal ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handlePop(didPop),
      child: Scaffold(
        appBar: GlassAppBar(
          title: _editingId == null ? '记一笔' : '编辑账单',
          leading: BackButton(onPressed: () => context.pop()),
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
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.md),
                          children: [
                            _amountCard(color: amountColor),
                            const SizedBox(height: Spacing.md),
                            _summaryChips(),
                            const SizedBox(height: Spacing.md),
                            _categoryGrid(),
                            const SizedBox(height: Spacing.md),
                            _titleRow(),
                            const SizedBox(height: Spacing.md),
                            _moreOptions(members: members),
                          ],
                        ),
                      ),
                      AmountKeypad(
                        onDigit: (d) => setState(() => _money.pushDigit(d)),
                        onBackspace: () => setState(() => _money.backspace()),
                        onOp: (op) => setState(() => _money.pushOp(op)),
                        onDot: () => setState(() => _money.pushDot()),
                        onNote: () => _toggleGroup('note'),
                        hasNote: _noteController.text.trim().isNotEmpty,
                        doneEnabled: _money.totalFen != null,
                        onDone: _save,
                      ),
                    ],
                  ),
                  if (_showSavedOverlay)
                    _SavedOverlay(
                      amountCents: _savedAmountForOverlay,
                      isEdit: _editingId != null,
                      burst: _savedBurst,
                      onSkip: _anotherOne,
                    ),
                ],
              ),
      ),
    );
  }

  /// V2.8.1 S5：PopScope 草稿拦截 —— 有脏数据 → L2 确认弹层「放弃这笔账？」。
  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    final context = this.context;
    if (!_hasDirtyDraft) {
      Navigator.of(context).pop();
      return;
    }
    final amountLine = _money.totalFen;
    final amountText = amountLine == null ? '' : '当前金额 ¥${(amountLine / 100).toStringAsFixed(amountLine % 100 == 0 ? 0 : 2)}，';
    final leave = await showConfirmSheet(
      context: context,
      title: '放弃这笔账？',
      body: '$amountText离开本页会暂存为草稿，再次进入可自动恢复；关闭本弹层 = 留在本页。',
      confirmLabel: '离开并保留草稿',
      cancelLabel: '放弃并返回',
    );
    // 「离开并保留草稿」= 写入会话草稿并返回；「放弃并返回」= 清除草稿并返回；
    // 关闭弹层（dismiss → false→…）与「放弃」同路径，均视为明确放弃。
    if (leave) {
      ExpenseDraftStore.put(_draftKey, _captureDraft());
      if (context.mounted) Navigator.of(context).pop();
    } else {
      ExpenseDraftStore.remove(_draftKey);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // 区块：金额卡（V2.8.1 S5 玻璃 floatingCard）
  // ---------------------------------------------------------------------------

  Widget _amountCard({required Color color}) {
    final scheme = Theme.of(context).colorScheme;
    final isRefund = _type == ExpenseType.refund;
    final cnyPreview = _cnyTotalAbs;
    final invalid = _money.display.isNotEmpty && _inputCents == null;
    return GlassSurface(
      level: GlassLevel.floatingCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.xl, Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 分类语义色 icon 底座
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.primary.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    isRefund
                        ? Icons.replay_rounded
                        : _type == ExpenseType.prepay
                            ? Icons.flight_takeoff_rounded
                            : Icons.payments_rounded,
                    size: 21,
                    color: isRefund ? SemanticColors.income : scheme.primary,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                // 类型 / 币种 / 日期 三 chip（点按展开对应组）
                _miniChip(
                  label: _type == ExpenseType.refund
                      ? '退款'
                      : _type == ExpenseType.prepay
                          ? '预付'
                          : '支出',
                  group: 'type',
                ),
                const SizedBox(width: 6),
                _miniChip(label: _currency.code, group: 'currency'),
                const SizedBox(width: 6),
                _miniChip(
                  label: '${epochDayToDate(_dateEpochDay).month}/${epochDayToDate(_dateEpochDay).day}',
                  group: 'date',
                ),
                const Spacer(),
                if (_money.display.isNotEmpty)
                  IconButton(
                    tooltip: '清空金额',
                    onPressed: () => setState(() => _money.clear()),
                    icon: Icon(Icons.backspace_outlined,
                        size: 20, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            // 大金额：整数 46 级、小数缩半；表达式实时合计
            _MoneyAmountView(
              expression: _money,
              symbol: _currency.symbol,
              color: invalid ? scheme.error : color,
            ),
            const SizedBox(height: Spacing.xs),
            Row(
              children: [
                if (_currencyCode != 'CNY')
                  Expanded(
                    child: Text(
                      '按 1 $_currencyCode = ${_rate.toStringAsFixed(4)} 元折合约 ¥${(cnyPreview ~/ 100)}.${(cnyPreview % 100).toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  Text('单位：人民币元 · 支持连算 58+32',
                      style: Theme.of(context).textTheme.bodySmall),
                if (invalid)
                  Text('金额格式不对哦',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption, color: scheme.error)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip({required String label, required String group}) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _toggleGroup(group);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          // V2.8.3.1：实色 chip —— 半透明 chip 叠在玻璃金额卡上会发灰。
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 区块：摘要 chips 行（折叠组已选值常驻）
  // ---------------------------------------------------------------------------

  Widget _summaryChips() {
    final scheme = Theme.of(context).colorScheme;
    String payerLabel() {
      if (_personal) return '个人账本';
      if (_payerIds.isEmpty) return '付款人';
      if (_payerIds.length == 1) return memberNameOf(_payerIds.first);
      return '付款人 ${_payerIds.length} 人 · ${_shareModeLabel}';
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SummaryChip(
            label: _payMethod == null
                ? '💳 支付方式'
                : '💳 ${_payMethods[_payMethod] ?? _payMethod!}',
            active: _payMethod != null,
            onTap: () => _toggleGroup('pay'),
          ),
          _SummaryChip(
            label: _type == ExpenseType.normal ? '↩ 退款/预付态' : (_type == ExpenseType.refund ? '↩ 已标退款' : '🛫 已标预付'),
            active: _type != ExpenseType.normal,
            onTap: () => _toggleGroup('type'),
          ),
          if (!_personal)
            _SummaryChip(
              label: '👥 ${payerLabel()}',
              active: _payerIds.isNotEmpty,
              onTap: () => _toggleGroup('payer'),
            ),
          _SummaryChip(
            label: _tripId == null ? '🔗 关联行程' : '🔗 行程已关联',
            active: _tripId != null,
            onTap: () => _toggleGroup('trip'),
          ),
          _SummaryChip(
            label: '📅 ${fmtFullDateOfEpoch(_dateEpochDay)}',
            active: false,
            onTap: () => _toggleGroup('date'),
          ),
          _SummaryChip(
            label: '${_expandedGroup.isEmpty ? '▾' : '▴'} 更多选项',
            active: _expandedGroup.isNotEmpty,
            onTap: () => _toggleGroup(_expandedGroup.isEmpty ? 'more' : ''),
            tone: scheme.primary,
          ),
        ],
      ),
    );
  }

  String get _shareModeLabel => switch (_shareMode) {
        ShareMode.equal => '平摊',
        ShareMode.portions => '按份',
        ShareMode.percent => '按比例',
        ShareMode.custom => '自定义',
      };

  void _toggleGroup(String group) {
    setState(() {
      if (group == 'more') {
        // 「更多选项」聚合入口：默认展开币种组
        _expandedGroup = _expandedGroup.isEmpty ? 'currency' : '';
      } else {
        _expandedGroup = _expandedGroup == group ? '' : group;
      }
    });
    if (_expandedGroup.isNotEmpty) {
      // 自动滚到可视区（展开内容位于标题行下方）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(context, alignment: 0.2);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // 区块：标题行 + 更多选项展开区（页内 AnimatedCrossFade，一次一组）
  // ---------------------------------------------------------------------------

  Widget _titleRow() {
    final scheme = Theme.of(context).colorScheme;
    final hint = _categoryHint(_categoryKey);
    return Row(
      children: [
        Expanded(
          child: _TextFieldCard(
            controller: _titleController,
            hint: hint,
            maxLines: 1,
            icon: Icons.edit_rounded,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        TextButton.icon(
          onPressed: _showSavedOverlay ? null : _saveAndAnother,
          icon: const Icon(Icons.skip_next_rounded, size: 18),
          label: const Text('再记一笔'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  /// 「再记一笔」= 保存并清空继续（蒙层可跳过的语义由 [提示语] 承担）。
  Future<void> _saveAndAnother() async {
    final before = _editingId;
    await _save();
    if (before == null && mounted && _showSavedOverlay) {
      // 保存成功已出蒙层：立即跳过等待进入下一笔
      await _anotherOne();
    }
  }

  Widget _moreOptions({required List<LedgerMemberView> members}) {
    final expanded = _expandedGroup;
    Widget? group;
    switch (expanded) {
      case 'currency':
        group = Column(children: [
          _currencyChips(),
          const SizedBox(height: Spacing.sm),
        ]);
      case 'type':
        group = _typeToggles();
      case 'pay':
        group = _payMethodChips();
      case 'date':
        group = _metaCard();
      case 'payer':
        group = !_personal
            ? _payerSection(members: members)
            : const SizedBox.shrink();
      case 'split':
        group = !_personal
            ? _splitSection(members: members)
            : const SizedBox.shrink();
      case 'trip':
        group = _linkTripCard();
      case 'note':
        group = Column(children: [
          _TextFieldCard(
            controller: _noteController,
            hint: '备注（选填）',
            maxLines: 3,
            icon: Icons.sticky_note_2_outlined,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
          ),
        ]);
      default:
        group = null;
    }
    // 付款人组展开时附带分摊组入口（同一卡内连续两组）
    final extra = expanded == 'payer' && !_personal ? _splitSection(members: members) : null;
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      sizeCurve: Curves.easeOutCubic,
      crossFadeState:
          expanded.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: const SizedBox(width: double.infinity),
      secondChild: Column(
        children: [
          if (group != null) group!,
          if (extra != null) ...[const SizedBox(height: Spacing.md), extra],
        ],
      ),
    );
  }

  /// 分类 → 标题占位提示映射表（规格 8.3-4）。
  static const _categoryHints = <String, String>{
    'food': '午餐 / 晚餐 / 零食',
    'transport': '打车 / 地铁 / 加油',
    'stay': '房费 / 押金',
    'ticket': '门票 / 演出',
    'shopping': '纪念品 / 特产',
    'fun': '娱乐 / 体验',
    'other': '这一笔是花在哪儿？（必填）',
  };

  static String _categoryHint(String? key) =>
      _categoryHints[key] ?? '这一笔是花在哪儿？（必填）';

  // ---------------------------------------------------------------------------
  // 区块：大金额输入
  // ---------------------------------------------------------------------------

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
                        showAppSnackBar(sheetContext, ok
                              ? '已更新为最新汇率'
                              : '拉取失败，检查网络后重试或手动输入', tone: SnackTone.destructive);
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
  // 区块：支付方式（S11 纯标签，可留空）
  // ---------------------------------------------------------------------------

  Widget _payMethodChips() {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: '支付方式（选填）',
      subtitle: '只是标签，不跟踪账户余额',
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          for (final e in _payMethods.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _payMethod == e.key,
              onSelected: (v) {
                HapticFeedback.selectionClick();
                setState(() => _payMethod = v ? e.key : null);
              },
            ),
          if (_payMethod != null && !_payMethods.containsKey(_payMethod))
            ChoiceChip(
              label: Text(_payMethod!),
              selected: true,
              onSelected: (_) => setState(() => _payMethod = null),
            ),
          ActionChip(
            avatar: Icon(Icons.clear_rounded, size: 16, color: scheme.onSurfaceVariant),
            label: const Text('未标记'),
            onPressed: () => setState(() => _payMethod = null),
          ),
        ],
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
              ButtonSegment(value: ShareMode.percent, label: Text('按百分比')),
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
            ShareMode.percent => [
                Text('填每人百分比，合计不必正好 100%，保存时按比例自动归一',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Spacing.xs),
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: (_percentCtrlFor(m.id).text.trim().isEmpty) ? 0.45 : 1,
                          child: MemberAvatar(member: m, size: 28),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                            child: Text(m.name, style: Theme.of(context).textTheme.bodyMedium)),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _percentCtrlFor(m.id),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d{0,3}(\.\d{0,2})?')),
                            ],
                            decoration: const InputDecoration(suffixText: '%', hintText: '0'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                _percentBalanceHint(),
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

  TextEditingController _percentCtrlFor(String id) =>
      _percentCtrls.putIfAbsent(id, () => TextEditingController());

  /// 百分比守恒提示（警告式，不禁用保存按钮）：
  /// Σ=100% → 守恒；Σ≠100% → 将自动归一；全空 → 按平均分摊。
  Widget _percentBalanceHint() {
    final scheme = Theme.of(context).colorScheme;
    final hasAny = _rawPercentBp.isNotEmpty;
    final sum = _percentSum;
    final ok = hasAny && (sum - 100).abs() < 0.005;
    final text = !hasAny
        ? '未填百分比，保存时按平均分摊'
        : ok
            ? '各认比例守恒 ✅'
            : '当前合计 ${sum.toStringAsFixed(2)}%，保存时将按比例自动归一';
    return Row(
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 15, color: ok ? SemanticColors.income : scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w600,
                color: ok ? SemanticColors.income : scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

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
    // percent 模式（未回退 equal）在每人金额前展示归一后占比，如「张三 33.34%」。
    final bp = _shareMode == ShareMode.percent && !_percentFallsBackToEqual
        ? _normalizedPercentBp
        : null;
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        for (final s in shares)
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (names[s.memberId] != null) MemberAvatar(member: names[s.memberId]!, size: 20),
            const SizedBox(width: 4),
            if (bp != null)
              Text(
                '${names[s.memberId]?.name ?? s.memberId} '
                '${((bp[s.memberId] ?? 0) / 100).toStringAsFixed(2)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (bp != null) const SizedBox(width: 6),
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
// V2.8.1 S5：大金额表达式视图（整数 46 级、小数缩半，tabularFigures）
// ---------------------------------------------------------------------------

class _MoneyAmountView extends StatelessWidget {
  const _MoneyAmountView({
    required this.expression,
    required this.symbol,
    required this.color,
  });

  final MoneyExpression expression;
  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = expression.totalFen;
    final showExpression = expression.display.contains('+') ||
        expression.display.contains('−');
    final yuan = total == null ? null : (total.abs() ~/ 100).toString();
    final dec = total == null ? null : (total.abs() % 100).toString().padLeft(2, '0');
    final negative = total != null && total < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(symbol, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 6),
            Text(
              total == null ? '0' : (negative ? '-' : '') + yuan!,
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: AppTextStyles.tabularFigures,
                letterSpacing: -0.5,
                height: 1.05,
              ),
            ),
            if (dec != null && total != null)
              Text('.$dec',
                  style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFeatures: AppTextStyles.tabularFigures)),
            const Spacer(),
            if (showExpression)
              Text(expression.display,
                  style: TextStyle(
                      fontSize: AppFontSizes.body,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFeatures: AppTextStyles.tabularFigures)),
          ],
        ),
      ],
    );
  }
}

/// 摘要 chips 行的单枚胶囊。
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.tone,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tone ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.13) : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.caption,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? color : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 保存成功蒙层：全屏玻璃 + 金额 CountUp + heavyImpact，800ms 后自动 pop；
/// 「再记一笔」可点跳过等待。
class _SavedOverlay extends StatefulWidget {
  const _SavedOverlay({
    required this.amountCents,
    required this.isEdit,
    required this.burst,
    required this.onSkip,
  });

  final int amountCents;
  final bool isEdit;
  final bool burst;
  final VoidCallback onSkip;

  @override
  State<_SavedOverlay> createState() => _SavedOverlayState();
}

class _SavedOverlayState extends State<_SavedOverlay> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: scheme.surface.withValues(alpha: 0.72),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.burst)
                ConfettiBurst(colors: [scheme.primary, scheme.secondary, SemanticColors.income]),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 56, color: scheme.primary),
                  const SizedBox(height: 10),
                  Text(
                    widget.isEdit ? '已更新这笔账' : '已记下这一笔',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  MoneyText(widget.amountCents,
                      fontSize: AppFontSizes.display,
                      fontWeight: FontWeight.w800),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: widget.onSkip,
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text('再记一笔'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
