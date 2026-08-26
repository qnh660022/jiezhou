// ✏️ 行程安排编辑：类型五分段 + POI搜索 + 地图选点 + 航班号 + 费用 + 备注
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

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../trip_utils.dart';
import '../trip_widgets.dart';

/// 安排编辑页（路由 extra 传 {tripId, item?}）
class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.tripId, this.item});

  final String? tripId;
  final TripItem? item;

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
  Trip? _trip;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final it = widget.item!;
      _editId = it.id;
      _type = it.type;
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
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
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final costYuan = double.tryParse(_costCtrl.text.trim());
      final costCents = costYuan != null ? (costYuan * 100).round() : null;
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
          sortOrder: 0, createdAt: now, updatedAt: now,
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
    final scheme = Theme.of(context).colorScheme;
    final isTransport = _type == 'transport';
    final types = allTripTypes();
    return Scaffold(
      appBar: GlassAppBar(title: _editId == null ? '添加安排' : '编辑安排'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Type selector
            SectionCard(
              child: Row(
                children: [
                  for (final t in types)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _type = t.key);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                          decoration: BoxDecoration(
                            color: _type == t.key ? t.color.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: AppRadius.button,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t.icon, style: TextStyle(fontSize: 20, color: _type == t.key ? t.color : scheme.onSurfaceVariant)),
                              const SizedBox(height: 2),
                              Text(t.name, style: TextStyle(fontSize: AppFontSizes.caption - 1, fontWeight: _type == t.key ? FontWeight.w700 : FontWeight.w500, color: _type == t.key ? t.color : scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // Name + Address
            SectionCard(
              child: Column(
                children: [
                  LabeledField(
                    label: '名称',
                    child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: '例如：浅草寺')),
                  ),
                  const SizedBox(height: Spacing.lg),
                  LabeledField(
                    label: '地址',
                    child: TextField(controller: _addrCtrl, decoration: const InputDecoration(hintText: '选填')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // POI Search
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledField(
                    label: '搜索地点 (POI)',
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '输入关键字搜索…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _poiLoading
                            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width:20,height:20,child: CircularProgressIndicator(strokeWidth: 2)))
                            : null,
                      ),
                      onChanged: _onPoiChanged,
                    ),
                  ),
                  if (_poiResults.isNotEmpty) ...[
                    const SizedBox(height: Spacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _poiResults.length,
                        itemBuilder: (ctx, i) {
                          final poi = _poiResults[i];
                          return ListTile(
                            dense: true,
                            leading: Text(poi.icon, style: const TextStyle(fontSize: 18)),
                            title: Text(poi.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(poi.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFontSizes.caption - 1)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: AppRadius.capsule),
                              child: Text(poi.source == PoiSource.offline ? '离线' : '在线', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                            ),
                            onTap: () => _selectPoi(poi),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // Day selector: an arrangement must belong to one of the trip days.
            if (_trip != null) ...[
              SectionCard(
                child: LabeledField(
                  label: '安排日期',
                  child: InkWell(
                    borderRadius: AppRadius.input,
                    onTap: _pickDay,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: AppRadius.input,
                      ),
                      child: Text(
                        _dateEpochDay == null
                            ? '请选择日期'
                            : '第 ${_dateEpochDay! - _trip!.startEpochDay + 1} 天 · ${fmtMonthDayOfEpoch(_dateEpochDay!)}',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],

            // Transport: from/to
            if (isTransport) ...[
              SectionCard(
                child: Column(
                  children: [
                    LabeledField(
                      label: '出发地',
                      child: TextField(controller: _fromNameCtrl, decoration: const InputDecoration(hintText: '出发地名称')),
                    ),
                    const SizedBox(height: Spacing.lg),
                    LabeledField(
                      label: '到达地',
                      child: TextField(controller: _toNameCtrl, decoration: const InputDecoration(hintText: '到达地名称')),
                    ),
                    const SizedBox(height: Spacing.lg),
                    LabeledField(
                      label: '航班号 (选填)',
                      child: TextField(
                        controller: _flightCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: '例如 MU5137',
                          suffixIcon: _flightLoading
                              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width:18,height:18,child: CircularProgressIndicator(strokeWidth: 2)))
                              : IconButton(icon: const Icon(Icons.search_rounded, size: 20), onPressed: _lookupFlight),
                        ),
                        onEditingComplete: _lookupFlight,
                      ),
                    ),
                    if (_flightInfo != null) ...[
                      const SizedBox(height: Spacing.sm),
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: AppRadius.input,
                        ),
                        child: Row(
                          children: [
                            const Text('✈️', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_flightInfo!.airlineName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('${_flightInfo!.fromAirport} → ${_flightInfo!.toAirport}',
                                      style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],

            // Time + Duration
            SectionCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: '开始时间',
                          child: GestureDetector(
                            onTap: _pickTime,
                            child: Container(
                              height: 48,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                              decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: AppRadius.input),
                              child: Text(_startTimeMin != null ? hhmm(_startTimeMin!) : '点击选择',
                                  style: TextStyle(color: _startTimeMin != null ? scheme.onSurface : scheme.onSurfaceVariant)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.lg),
                      Expanded(
                        child: LabeledField(
                          label: '时长 (分钟)',
                          child: MiniStepper(
                            valueText: _durationMin != null ? '${_durationMin}分钟' : '未设',
                            onMinus: () => setState(() { _durationMin = (_durationMin ?? 0) - 15; if (_durationMin! < 0) _durationMin = 0; }),
                            onPlus: () => setState(() => _durationMin = (_durationMin ?? 0) + 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // Cost
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledField(
                    label: '费用',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _costCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '金额 (元)'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        // Currency chip selector
                        GestureDetector(
                          onTap: () => _showCurrencySheet(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: AppRadius.capsule),
                            child: Text('${_currency}', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // Note
            SectionCard(
              child: LabeledField(
                label: '备注 (选填)',
                child: TextField(controller: _noteCtrl, maxLines: 3, minLines: 2, decoration: const InputDecoration(hintText: '添加备注…')),
              ),
            ),
            const SizedBox(height: Spacing.xxl),

            PrimaryButton(
              label: _editId == null ? '保存安排' : '更新安排',
              loading: _saving,
              expanded: true,
              onPressed: _save,
            ),
            const SizedBox(height: Spacing.huge),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final trip = _trip;
    if (trip == null) return;
    final current = (_dateEpochDay ?? trip.startEpochDay)
        .clamp(trip.startEpochDay, trip.endEpochDay);
    final selected = await showDatePicker(
      context: context,
      initialDate: epochDayToDate(current),
      firstDate: epochDayToDate(trip.startEpochDay),
      lastDate: epochDayToDate(trip.endEpochDay),
      helpText: '选择安排日期',
    );
    if (selected != null) setState(() => _dateEpochDay = dateToEpochDay(selected));
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
