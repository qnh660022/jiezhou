// ✏️ 行程安排编辑（V2.8.3.5 重设计：卡片 8 → 4）。
//
// 布局：紧凑类型 chip 条 → 主卡（名称无框输入 + POI 内联建议 + 地址 /
// 交通走出发-到达两段 + 「什么时候」实时摘要 + 时长快捷 chips）→ 航班卡
// （仅交通）→ 费用一行 → 备注折叠 → 底部停靠提交（编辑模式带删除）。
// 字段与落库逻辑不变；文件头原先写的「地图选点」是过期描述（build 里从无
// 该 UI），本次一并清掉。
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/date_utils.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_assistant/core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/services/poi_service.dart';
import '../../../data/services/flight_service.dart';
import '../../../domain/trip_bill_linker.dart';

import '../../../features/desktop/desktop_utils.dart' show isDesktopWeb;
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';
import '../widgets/range_calendar_sheet.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// 安排编辑页（路由 extra 传 {tripId, item?}）
class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.tripId, this.item, this.prefillNew = false});

  final String? tripId;
  final TripItem? item;

  /// 预填模式：[item] 只作表单初值（如攻略「加入安排」），保存时按新建处理。
  final bool prefillNew;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  String _type = 'attraction';
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _flightCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  double? _lat, _lng;
  int? _startTimeMin;
  int? _durationMin;
  String _currency = 'CNY';
  // Transport fields
  final _fromNameCtrl = TextEditingController();
  final _fromAddrCtrl = TextEditingController();
  double? _fromLat, _fromLng;
  final _toNameCtrl = TextEditingController();
  final _toAddrCtrl = TextEditingController();
  double? _toLat, _toLng;

  bool _saving = false;
  int? _dateEpochDay;
  String? _editId;
  // V2.9.0：编辑模式记住原 sortOrder —— saveItem 全字段写回，
  // 此前硬编码 0 会把用户拖拽排序重置。
  int _sortOrder = 0;
  Trip? _trip;
  // V2.8.3.5：备注默认折叠成一行。
  bool _noteOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null && !widget.prefillNew) {
      final it = widget.item!;
      _editId = it.id;
      _type = it.type;
      _sortOrder = it.sortOrder; // V2.9.0：透传原顺序，编辑不再重置拖拽排序
      _nameCtrl.text = it.name;
      _addrCtrl.text = it.address;
      _noteCtrl.text = it.note;
      _lat = it.lat;
      _lng = it.lng;
      _dateEpochDay = it.dateEpochDay;
      _startTimeMin = it.startTimeMin;
      _durationMin = it.durationMin;
      _currency = it.costCurrency;
      if (it.costCents != null && it.costCents! > 0) {
        final yuan = it.costCents! / 100;
        _costCtrl.text = yuan == yuan.roundToDouble() ? '${yuan.round()}' : yuan.toStringAsFixed(2);
      }
      _fromNameCtrl.text = it.fromName;
      _fromAddrCtrl.text = it.fromAddress;
      _fromLat = it.fromLat;
      _fromLng = it.fromLng;
      _toNameCtrl.text = it.toName;
      _toAddrCtrl.text = it.toAddress;
      _toLat = it.toLat;
      _toLng = it.toLng;
      _flightCtrl.text = it.flightNo ?? '';
    } else {
      _dateEpochDay = todayEpochDay();
    }
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final tripId = widget.tripId;
    if (tripId == null) return;
    final trip = await ref.read(tripsRepoProvider).watchTrip(tripId).first;
    if (mounted) setState(() => _trip = trip);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _noteCtrl.dispose();
    _flightCtrl.dispose();
    _costCtrl.dispose();
    _fromNameCtrl.dispose();
    _fromAddrCtrl.dispose();
    _toNameCtrl.dispose();
    _toAddrCtrl.dispose();
    _poiDebounce?.cancel(); // POI 防抖计时器随 State 销毁取消
    super.dispose();
  }

  void _toast(String msg) {
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, msg);
  }

  // ===== POI Search =====
  Timer? _poiDebounce;
  List<PoiResult> _poiResults = [];
  bool _poiLoading = false;

  void _onPoiChanged(String kw) {
    _poiDebounce?.cancel();
    if (kw.trim().length < 2) { setState(() => _poiResults = []); return; }
    _poiDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return; // 计时器触发时 State 可能已销毁
      setState(() => _poiLoading = true);
      final results = await ref.read(poiServiceProvider).search(kw);
      if (mounted) setState(() { _poiResults = results; _poiLoading = false; });
    });
  }

  void _selectPoi(PoiResult poi) {
    HapticFeedback.lightImpact();
    setState(() {
      _nameCtrl.text = poi.name;
      _addrCtrl.text = poi.address;
      _lat = poi.lat;
      _lng = poi.lng;
      _poiResults = [];
    });
  }

  // ===== Flight lookup =====
  FlightInfo? _flightInfo;
  bool _flightLoading = false;

  Future<void> _lookupFlight() async {
    final no = _flightCtrl.text.trim();
    if (no.isEmpty) return;
    setState(() => _flightLoading = true);
    final info = await ref.read(flightServiceProvider).lookup(no);
    if (mounted) setState(() { _flightInfo = info; _flightLoading = false; });
  }

  // ===== Time picker =====
  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final initial = _startTimeMin != null
        ? TimeOfDay(hour: _startTimeMin! ~/ 60, minute: _startTimeMin! % 60)
        : TimeOfDay.now();
    final result = await showTimePicker(context: context, initialTime: initial);
    if (result != null) {
      setState(() => _startTimeMin = result.hour * 60 + result.minute);
    }
  }

  // ===== Save =====
  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _toast('请填写名称'); return; }
    // V2.9.0：费用解析失败不再静默丢数据 —— 有非空输入但解析不出数值时
    // 给出明确提示并中止保存（空输入 = 未填费用，仍合法存 null）。
    final costInput = _costCtrl.text.trim();
    final costYuan = costInput.isEmpty ? null : double.tryParse(costInput);
    if (costInput.isNotEmpty && costYuan == null) {
      _toast('费用「$costInput」不是有效金额，请修正后再保存');
      return;
    }
    final costCents = costYuan != null ? (costYuan * 100).round() : null;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tripId = widget.tripId!;
      if (_editId != null) {
        final item = TripItem(
          id: _editId!, tripId: tripId,
          dateEpochDay: _dateEpochDay ?? todayEpochDay(),
          type: _type, name: name,
          address: _addrCtrl.text.trim(),
          lat: _lat, lng: _lng,
          photoUri: null,
          startTimeMin: _startTimeMin,
          durationMin: _durationMin,
          costCents: costCents,
          costCurrency: _currency,
          note: _noteCtrl.text.trim().isEmpty ? '' : _noteCtrl.text.trim(),
          fromName: _fromNameCtrl.text.trim().isEmpty ? '' : _fromNameCtrl.text.trim(),
          fromAddress: _fromAddrCtrl.text.trim().isEmpty ? '' : _fromAddrCtrl.text.trim(),
          fromLat: _fromLat, fromLng: _fromLng,
          toName: _toNameCtrl.text.trim().isEmpty ? '' : _toNameCtrl.text.trim(),
          toAddress: _toAddrCtrl.text.trim().isEmpty ? '' : _toAddrCtrl.text.trim(),
          toLat: _toLat, toLng: _toLng,
          flightNo: _flightCtrl.text.trim().isEmpty ? '' : _flightCtrl.text.trim().toUpperCase(),
          sortOrder: _sortOrder, createdAt: now, updatedAt: now,
        );
        await ref.read(tripsRepoProvider).saveItem(item);
        await _syncLinkedBillAmount(item, costCents);
      } else {
        final id = newId("item");
        await ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(id:Value(id),tripId:Value(tripId),dateEpochDay:Value(_dateEpochDay ?? todayEpochDay()),type:Value(_type),name:Value(name),address:Value(_addrCtrl.text.trim()),lat:Value(_lat),lng:Value(_lng),startTimeMin:Value(_startTimeMin),durationMin:Value(_durationMin),costCents:Value(costCents),costCurrency:Value(_currency),note:Value(_noteCtrl.text.trim().isEmpty ? '' : _noteCtrl.text.trim()),fromName:Value(_fromNameCtrl.text.trim().isEmpty ? '' : _fromNameCtrl.text.trim()),fromAddress:Value(_fromAddrCtrl.text.trim().isEmpty ? '' : _fromAddrCtrl.text.trim()),fromLat:Value(_fromLat),fromLng:Value(_fromLng),toName:Value(_toNameCtrl.text.trim().isEmpty ? '' : _toNameCtrl.text.trim()),toAddress:Value(_toAddrCtrl.text.trim().isEmpty ? '' : _toAddrCtrl.text.trim()),toLat:Value(_toLat),toLng:Value(_toLng),flightNo:Value(_flightCtrl.text.trim().isEmpty ? '' : _flightCtrl.text.trim().toUpperCase()),sortOrder:Value(0),createdAt:Value(now),updatedAt:Value(now)));
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        context.pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 双向联动（安排→账单）：编辑既有安排且填了计划费用时，
  /// 把金额同步到其最新一条「未结算」关联账单（后写生效）。
  /// 清空计划费是「暂不给价」，不同步清零账单——见 trip_bill_linker 约定。
  Future<void> _syncLinkedBillAmount(TripItem item, int? newCostCents) async {
    if (newCostCents == null) return;
    try {
      for (final bill in await ref.read(ledgerRepoProvider).getLinkedBills(item.id)) {
        if (bill.settledRoundId != null) continue; // 已结算不动，取最新未结算为目标
        final d = resolveAmountSync(
          expenseAmountCents: bill.amountCents,
          itemCostCents: newCostCents,
          source: SyncSource.itemEdit,
        );
        if (d.target == SyncTarget.updateExpense) {
          await ref
              .read(ledgerRepoProvider)
              .updateExpense(bill.id, ExpensesCompanion(amountCents: Value(d.newAmountCents)));
        }
        break; // 只同步最新一条未结算账单
      }
    } catch (_) {
      // 同步失败不阻塞保存主流程
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransport = _type == 'transport';
    final types = allTripTypes();
    return Scaffold(
      appBar: GlassAppBar(title: _editId == null ? '添加安排' : '编辑安排'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.md, Spacing.xl, Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // V2.8.3.5：类型由整卡 5 等宽格压成紧凑横滑 chip 条
                  _buildTypeStrip(types),
                  const SizedBox(height: Spacing.md),
                  _buildMainCard(isTransport),
                  const SizedBox(height: Spacing.md),
                  if (isTransport) ...[
                    _buildFlightCard(),
                    const SizedBox(height: Spacing.md),
                  ],
                  _buildCostCard(),
                  const SizedBox(height: Spacing.md),
                  _buildNoteCard(),
                ],
              ),
            ),
          ),
          _buildDockSave(),
        ],
      ),
    );
  }

  // ============ 新区块（V2.8.3.5 重设计） ============

  static const List<int> _quickDurations = [30, 60, 90, 120, 180];

  Widget _sectionLabel(String text, {String? hint}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 类型 chip 条：emoji 属内容岗位，类型色由 [TripTypeVisual.color] 提供。
  Widget _buildTypeStrip(List<TripTypeVisual> types) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, i) {
          final t = types[i];
          final selected = _type == t.key;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _type = t.key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md + 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.color : scheme.surfaceContainerLowest,
                borderRadius: AppRadius.capsule,
                border: Border.all(
                  color: selected
                      ? t.color
                      : scheme.outlineVariant.withValues(alpha: 0.75),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: t.color.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(t.icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 5),
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AvatarPalette.onColor
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 无框输入（名称 / 地址共用）。
  Widget _bareField({
    required TextEditingController controller,
    required String hint,
    double fontSize = AppFontSizes.body,
    FontWeight weight = FontWeight.w600,
    Color? color,
    int? maxLines = 1,
    ValueChanged<String>? onChanged,
    TextInputAction action = TextInputAction.next,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      textInputAction: action,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? scheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        hintStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  /// 主卡：非交通 = 名称 + 地址 + POI 建议 + 什么时候；
  /// 交通 = 名称 + 出发/到达两段 + 什么时候。
  Widget _buildMainCard(bool isTransport) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('安排内容'),
          const SizedBox(height: Spacing.xs),
          _bareField(
            controller: _nameCtrl,
            hint: isTransport ? '例如：轮渡往返' : '例如：浅草寺',
            fontSize: 21,
            weight: FontWeight.w800,
            action: TextInputAction.next,
            // V2.8.3.5：名称即 POI 搜索入口（原独立「搜索地点」卡并入此处）
            onChanged: isTransport ? null : _onPoiChanged,
          ),
          if (!isTransport) ...[
            const SizedBox(height: Spacing.xs),
            _bareField(
              controller: _addrCtrl,
              hint: '地址（选填，选 POI 会自动填入）',
              fontSize: AppFontSizes.caption,
              weight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
              action: TextInputAction.done,
            ),
            // POI 内联建议（最多 3 条，点一条即回填名称 + 地址 + 经纬度）
            if (_poiLoading || _poiResults.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              if (_poiLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: Row(children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text('正在搜索…',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            color: scheme.onSurfaceVariant)),
                  ]),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.input,
                    border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.8)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0;
                          i < _poiResults.length && i < 3;
                          i++)
                        InkWell(
                          onTap: () => _selectPoi(_poiResults[i]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.md,
                                vertical: Spacing.sm + 1),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLowest,
                              border: i == 0
                                  ? null
                                  : Border(
                                      top: BorderSide(
                                          color: scheme.outlineVariant
                                              .withValues(alpha: 0.7))),
                            ),
                            child: Row(
                              children: [
                                Text(_poiResults[i].icon,
                                    style: const TextStyle(fontSize: 15)),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_poiResults[i].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)),
                                      if (_poiResults[i]
                                          .address
                                          .isNotEmpty)
                                        Text(_poiResults[i].address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: scheme
                                                    .onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: AppRadius.capsule,
                                  ),
                                  child: Text(
                                    _poiResults[i].source ==
                                            PoiSource.offline
                                        ? '离线'
                                        : '在线',
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
          // 交通专属：出发 / 到达 两段（时间轴式，橙点起、绿点终）
          if (isTransport) ...[
            const SizedBox(height: Spacing.md),
            _sectionLabel('行程'),
            const SizedBox(height: Spacing.sm),
            _buildLeg(
              label: '出发',
              controller: _fromNameCtrl,
              hint: '出发地名称',
              dotColor: tripTypeVisual('transport').color,
            ),
            Container(
              width: 1.5,
              height: 16,
              margin: const EdgeInsets.only(left: 5, top: 2, bottom: 2),
              color: scheme.outlineVariant,
            ),
            _buildLeg(
              label: '到达',
              controller: _toNameCtrl,
              hint: '到达地名称',
              dotColor: scheme.primary,
            ),
          ],
          Divider(
              height: Spacing.xl + Spacing.sm,
              color: scheme.outlineVariant.withValues(alpha: 0.85)),
          // 什么时候
          _sectionLabel('什么时候'),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              GestureDetector(
                onTap: _trip == null ? null : _pickDay,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: AppRadius.capsule,
                  ),
                  child: Text(
                    _dateEpochDay == null || _trip == null
                        ? '选择日期'
                        : 'Day ${_dateEpochDay! - _trip!.startEpochDay + 1} · ${fmtMonthDayOfEpoch(_dateEpochDay!)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_trip != null)
                GestureDetector(
                  onTap: _pickDay,
                  child: Text('换一天',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // 实时时间摘要：点击左侧时间进系统时间选择器
          GestureDetector(
            onTap: _pickTime,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _startTimeMin == null ? '选择开始时间' : hhmm(_startTimeMin!),
                  style: TextStyle(
                    fontSize: _startTimeMin == null ? 19 : 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: _startTimeMin == null
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                        : scheme.onSurface,
                    fontFeatures: AppTextStyles.tabularFigures,
                  ),
                ),
                if (_startTimeMin != null) ...[
                  Text('  →  ',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                  Text(
                    hhmm((_startTimeMin! + (_durationMin ?? 0)) % 1440),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      fontFeatures: AppTextStyles.tabularFigures,
                    ),
                  ),
                  if ((_durationMin ?? 0) > 0)
                    Text(
                      '  · 共 ${_durLabel(_durationMin!)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          // 时长快捷 chips（原 MiniStepper 每次 ±15，设 2 小时要点 8 次）
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final m in _quickDurations)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _durationMin = m);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: _durationMin == m
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      borderRadius: AppRadius.capsule,
                      border: Border.all(
                          color: _durationMin == m
                              ? scheme.primary.withValues(alpha: 0.35)
                              : Colors.transparent),
                    ),
                    child: Text(
                      _durLabel(m),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _durationMin == m
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          // 精细微调（保留 ±15 步进，供非整档时长使用）
          MiniStepper(
            valueText:
                _durationMin != null ? '${_durationMin}分钟' : '未设时长',
            onMinus: () => setState(() {
              _durationMin = (_durationMin ?? 0) - 15;
              if (_durationMin! < 0) _durationMin = 0;
            }),
            onPlus: () => setState(() => _durationMin = (_durationMin ?? 0) + 15),
          ),
        ],
      ),
    );
  }

  String _durLabel(int minutes) {
    if (minutes < 60) return '$minutes分';
    final h = minutes / 60;
    return h == h.roundToDouble()
        ? '${h.round()}时'
        : '${h.toStringAsFixed(1)}时';
  }

  Widget _buildLeg({
    required String label,
    required TextEditingController controller,
    required String hint,
    required Color dotColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              _bareField(
                controller: controller,
                hint: hint,
                fontSize: 14.5,
                weight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 航班 / 车次：独立成卡，查询结果以浅绿底呈现。
  Widget _buildFlightCard() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('航班 / 车次', hint: '选填'),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: _bareField(
                  controller: _flightCtrl,
                  hint: '例如 MU5137',
                  fontSize: 16,
                  weight: FontWeight.w800,
                  action: TextInputAction.search,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              GestureDetector(
                onTap: _flightLoading ? null : _lookupFlight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md + 1, vertical: 7),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: AppRadius.capsule,
                  ),
                  child: _flightLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '查询',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
          if (_flightInfo != null) ...[
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.42),
                borderRadius: AppRadius.input,
              ),
              child: Row(
                children: [
                  const Text('✈️', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_flightInfo!.airlineName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 1),
                        Text(
                          '${_flightInfo!.fromAirport} → ${_flightInfo!.toAirport}',
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 费用：一张卡压成一行（币种符号 + 金额 + 币种胶囊）。
  Widget _buildCostCard() {
    final scheme = Theme.of(context).colorScheme;
    final symbol = findCurrencyOption(_currency)?.symbol ?? '¥';
    return SectionCard(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        children: [
          Text(
            symbol,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: TextField(
              controller: _costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: AppTextStyles.tabularFigures,
              ),
              decoration: InputDecoration(
                hintText: '费用金额',
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          GestureDetector(
            onTap: _showCurrencySheet,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: AppRadius.capsule,
              ),
              child: Text(
                '$_currency ▾',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 备注：默认折叠（与原「备注（选填）」卡内容一致，仅收起来）。
  Widget _buildNoteCard() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg,
          _noteOpen ? Spacing.lg : Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: AppRadius.input,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _noteOpen = !_noteOpen);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Row(
                children: [
                  const Text('备注',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('选填',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(width: Spacing.sm),
                  AnimatedRotation(
                    turns: _noteOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _noteOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: TextField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      minLines: 2,
                      decoration: const InputDecoration(hintText: '添加备注…'),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// 停靠的提交区：避让底部悬浮胶囊栏；编辑模式左侧给「删除」。
  Widget _buildDockSave() {
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = isDesktopWeb(context)
        ? Spacing.md
        : Spacing.sm +
            AppBottomLayout.withSafeArea(context, AppBottomLayout.navBarHeight);
    return Container(
      padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, bottomPad),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          if (_editId != null) ...[
            Tooltip(
              message: '删除这条安排',
              child: InkWell(
                borderRadius: AppRadius.input,
                onTap: _delete,
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: AppRadius.input,
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 20, color: scheme.error),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: PrimaryButton(
              label: _editId == null ? '保存安排' : '更新安排',
              loading: _saving,
              expanded: true,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }

  /// 删除当前安排（编辑模式）。危险确认必须带影响数量（强确认口径）。
  Future<void> _delete() async {
    final id = _editId;
    if (id == null) return;
    HapticFeedback.mediumImpact();
    final ok = await showDangerConfirm(
      context: context,
      title: '删除这条安排？',
      body: '将从行程中永久移除 1 条安排，相关账单关联也会一并解除，且无法恢复。',
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    await ref.read(tripsRepoProvider).deleteItem(id);
    if (!mounted) return;
    context.pop(true);
  }

  Future<void> _pickDay() async {
    final trip = _trip;
    if (trip == null) return;
    final current = (_dateEpochDay ?? trip.startEpochDay)
        .clamp(trip.startEpochDay, trip.endEpochDay);
    // V2.9.0：系统 showDatePicker 未本地化 → 统一走自绘月历（单日=起终同天）。
    final result = await showRangeCalendarSheet(
      context,
      initialMonth: epochDayToDate(current),
      startDay: current,
      endDay: current,
      mode: RangeCalendarMode.single,
      title: '选择安排日期',
    );
    if (result != null && mounted) {
      setState(() => _dateEpochDay = result.startDay);
    }
  }

  void _showCurrencySheet() {
    final scheme = Theme.of(context).colorScheme;
    showDraggableSheet(
      context: context,
      initialChildSize: 0.5,
      minChildSize: 0.35,
      builder: (sheetContext, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择币种', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                itemCount: kCurrencyOptions.length,
                itemBuilder: (ctx, i) {
                  final c = kCurrencyOptions[i];
                  final selected = c.code == _currency;
                  return ListTile(
                    dense: true,
                    leading: Text(c.symbol, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.primary)),
                    title: Text('${c.name} (${c.code})'),
                    trailing: selected ? Icon(Icons.check_rounded, color: scheme.primary) : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currency = c.code);
                      Navigator.of(sheetContext).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
