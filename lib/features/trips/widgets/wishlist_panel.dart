/// 想去池面板（V2.7.2 S6，三宿主共用）。
///
/// - 三来源入池：攻略「先想去」（S5）/ 大纲纯标题行（S3）/ 手动表单（本面板）；
/// - 展示：按 cityKey 分组折叠（S11 接管分组头样式与城过滤）；
///   条目行 = 名称 + tag 角标 + 时长（`90 分钟`/「未估时」）+ 来源角标（攻略/手动）
///   +「排到第 N 天」快捷动作；
/// - 落卡即移出（收口规则 1）：任一落卡路径同事务建卡 + 删池行
///   （[WishlistRepository.placeToDay]）；
/// - 未估时：点击弹四档补时长 chips（1h/2h/半天/一天）+ 自定义 10–720 分钟；
/// - viewer（canEdit=false）：整个面板只读（无表单/无删除/无拖拽），列表可见。
library;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart'
    show WishlistItemsCompanion;
import '../../../data/providers.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../wishlist_providers.dart';
import 'day_pick_sheet.dart';
import '../../../theme/app_icons.dart';
import '../../../shared/widgets/app_snack_bar.dart';

const List<String> kWishlistTypes = [
  'attraction',
  'food',
  'transport',
  'stay',
  'note',
];

const Map<String, String> kWishlistTypeLabels = {
  'attraction': '景点',
  'food': '美食',
  'transport': '交通',
  'stay': '住宿',
  'note': '备注',
};

/// 自定义时长输入校验：10–720 分钟；越界/非法返回 null。
int? parseWishlistDuration(String input) {
  final v = int.tryParse(input.trim());
  if (v == null || v < 10 || v > 720) return null;
  return v;
}

/// 按 cityKey 分组（保持池内 sortOrder 序）；空 key → 「未分类」组。
/// 返回 Map 本身保序（按首次出现顺序）。
Map<String, List<WishlistRecord>> groupWishlistByCity(
    List<WishlistRecord> rows) {
  final out = <String, List<WishlistRecord>>{};
  for (final r in rows) {
    out.putIfAbsent(r.cityKey.isEmpty ? '' : r.cityKey, () => []).add(r);
  }
  return out;
}

String wishlistGroupLabel(String cityKey,
        String Function(String cityKey)? cityNameOf) =>
    cityKey.isEmpty ? '未分类' : (cityNameOf?.call(cityKey) ?? cityKey);

/// 公开补时长弹层（装配台 NeedDuration 流程复用）；取消返回 null。
/// V2.9.0：裸 showModalBottomSheet → 统一可拖拽抽屉（透明 sheet 主题下
/// 裸弹层内容会与底页重叠）。
Future<int?> showWishlistDurationSheet(BuildContext context) =>
    showDraggableSheet<int>(
      context: context,
      initialChildSize: 0.44,
      minChildSize: 0.3,
      builder: (sheetContext, _) => _WishDurationSheet(
        onDone: (v) => Navigator.of(sheetContext).pop(v),
      ),
    );

/// 想去池面板。
class WishlistPanel extends ConsumerStatefulWidget {
  const WishlistPanel({
    super.key,
    required this.tripId,
    required this.canEdit,
    this.compact = false,
    this.compare,
    this.onEntryTap,
    this.cityNameOf,
    this.isEntryDisabled,
    this.visibleCityKeys,
    this.padding = EdgeInsets.zero,
  });

  final String tripId;

  /// viewer 只读：无表单/无删除/无拖拽/无菜单（隐藏不置灰）。
  final bool canEdit;

  /// 紧凑模式（装配台左栏 / 大纲侧栏）：隐藏手动表单。
  final bool compact;

  /// 装配台注入的候选排序（§10.2 rankCandidates）；null = 池内 sortOrder 序。
  final int Function(WishlistRecord a, WishlistRecord b)? compare;

  /// 点击接管（装配台「点击即落点」）；返回 true 表示已处理。
  final Future<bool> Function(WishlistRecord record)? onEntryTap;

  /// 分组头城名反查（S11 注入）；null 直接显示 cityKey。
  final String Function(String cityKey)? cityNameOf;

  /// 条目置灰判定（装配台：类型窗与当天无交集的候选不可点）；null = 全部可点。
  final bool Function(WishlistRecord record)? isEntryDisabled;

  /// 城过滤（V2.7.2 S11）：只显示这些 cityKey 的分组；null = 全部。
  final Set<String>? visibleCityKeys;

  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<WishlistPanel> createState() => _WishlistPanelState();
}

class _WishlistPanelState extends ConsumerState<WishlistPanel> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  String _type = 'attraction';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    // V2.8.3.3：收口到全 App 唯一轻提示形态（L1）。
    showAppSnackBar(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final records =
        ref.watch(wishlistByTripProvider(widget.tripId)).valueOrNull ??
            const <WishlistRecord>[];
    final filtered = widget.visibleCityKeys == null
        ? records
        : records
            .where((r) => widget.visibleCityKeys!.contains(r.cityKey))
            .toList();
    final ordered = widget.compare == null
        ? filtered
        : (List<WishlistRecord>.of(filtered)..sort(widget.compare));

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ordered.isEmpty)
            const Expanded(
              child: Center(
                child: EmptyState(
                  icon: AppIcons.bookmark,
                  title: '想去池还是空的',
                  message: '在攻略里点「先想去」，或手动添加',
                ),
              ),
            )
          else
            Expanded(child: _buildGroups(ordered)),
          if (!widget.compact && widget.canEdit) _buildForm(context),
        ],
      ),
    );
  }

  Widget _buildGroups(List<WishlistRecord> records) {
    final grouped = groupWishlistByCity(records);
    return ListView(
      children: [
        for (final entry in grouped.entries)
          _WishGroup(
            cityKey: entry.key,
            label: wishlistGroupLabel(entry.key, widget.cityNameOf),
            records: entry.value,
            canEdit: widget.canEdit,
            isEntryDisabled: widget.isEntryDisabled,
            onPlace: _placeToDay,
            onPickDuration: (r) => _pickDuration(r, thenPlace: false),
            onDelete: _deleteEntry,
            onTapEntry: _onTapEntry,
            onReorder: widget.canEdit ? _onReorder : null,
          ),
      ],
    );
  }

  Future<void> _onTapEntry(WishlistRecord record) async {
    if (!widget.canEdit) return;
    if (widget.onEntryTap != null) {
      final handled = await widget.onEntryTap!(record);
      if (handled) return;
    }
    if (record.durationMin == null) {
      await _pickDuration(record, thenPlace: true);
    } else {
      await _placeToDay(record);
    }
  }

  Future<void> _deleteEntry(WishlistRecord record) async {
    await ref.read(wishlistRepoProvider).deleteItem(record.id);
  }

  /// 池内拖拽重排：组内新序 + 其余行原序 → 全池统一重编号（10 步长）。
  Future<void> _onReorder(List<WishlistRecord> groupRecords, int oldIndex,
      int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final newGroupIds = groupRecords.map((e) => e.id).toList();
    final moved = newGroupIds.removeAt(oldIndex);
    newGroupIds.insert(newIndex, moved);
    final all = ref.read(wishlistByTripProvider(widget.tripId)).valueOrNull ??
        const <WishlistRecord>[];
    final oldGroupIds = groupRecords.map((e) => e.id).toSet();
    final out = <String>[];
    for (final r in all) {
      if (oldGroupIds.contains(r.id)) {
        final idx = groupRecords.indexWhere((g) => g.id == r.id);
        out.add(idx >= 0 && idx < newGroupIds.length ? newGroupIds[idx] : r.id);
      } else {
        out.add(r.id);
      }
    }
    await ref.read(wishlistRepoProvider).reorder(widget.tripId, out);
  }

  Future<void> _placeToDay(WishlistRecord record, {int? durationMin}) async {
    final trip = await ref.read(tripsRepoProvider).getById(widget.tripId);
    if (trip == null || !mounted) return;
    final n = trip.endEpochDay - trip.startEpochDay + 1;
    if (n < 1) {
      _toast('该行程还没有日期，先去编辑行程设置日期');
      return;
    }
    final day = await showDayPickSheet(
      context,
      startDay: trip.startEpochDay,
      endDay: trip.endEpochDay,
      title: '排到哪一天？',
    );
    if (day == null || !mounted) return;
    try {
      await ref.read(wishlistRepoProvider).placeToDay(
            tripId: widget.tripId,
            wishlistId: record.id,
            dateEpochDay: day,
            durationMin: durationMin,
          );
      if (!mounted) return;
      _toast('已排到第 ${day - trip.startEpochDay + 1} 天');
    } on StateError catch (e) {
      _toast(e.message);
    }
  }

  /// 补时长（未估时）；[thenPlace] = 补完继续走落卡。
  Future<void> _pickDuration(WishlistRecord record,
      {required bool thenPlace}) async {
    final picked = await showWishlistDurationSheet(context);
    if (picked == null || !mounted) return;
    await ref
        .read(wishlistRepoProvider)
        .updateItem(record.id, WishlistItemsCompanion(durationMin: Value(picked)));
    _toast('已估时 $picked 分钟');
    if (!thenPlace) return;
    final fresh = await ref.read(wishlistRepoProvider).getItem(record.id);
    if (fresh == null || !mounted) return;
    await _placeToDay(ref.read(wishlistRepoProvider).toRecord(fresh));
  }

  Widget _buildForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = _nameCtrl.text.trim();
    final nameOk = name.isNotEmpty && name.length <= 40;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.input,
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('手动添加想去',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: _nameCtrl,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '名称（必填）',
                counterText: '',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final t in kWishlistTypes)
                  ChoiceChip(
                    label: Text(kWishlistTypeLabels[t] ?? t),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: _addrCtrl,
              decoration: const InputDecoration(
                labelText: '地址（可选）',
                isDense: true,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: nameOk ? _submitForm : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('加入想去'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name.length > 40) return;
    await ref.read(wishlistRepoProvider).addItem(
          tripId: widget.tripId,
          name: name,
          address: _addrCtrl.text.trim(),
          type: _type,
        );
    _nameCtrl.clear();
    _addrCtrl.clear();
    setState(() => _type = 'attraction');
    _toast('已加入想去');
  }
}

class _WishGroup extends StatelessWidget {
  const _WishGroup({
    required this.cityKey,
    required this.label,
    required this.records,
    required this.canEdit,
    required this.onTapEntry,
    required this.onPlace,
    required this.onPickDuration,
    required this.onDelete,
    this.isEntryDisabled,
    this.onReorder,
  });

  final String cityKey;
  final String label;
  final List<WishlistRecord> records;
  final bool canEdit;
  final Future<void> Function(WishlistRecord record) onTapEntry;
  final Future<void> Function(WishlistRecord record, {int? durationMin}) onPlace;
  final Future<void> Function(WishlistRecord record) onPickDuration;
  final Future<void> Function(WishlistRecord record) onDelete;
  final bool Function(WishlistRecord record)? isEntryDisabled;
  final void Function(List<WishlistRecord> records, int oldIndex, int newIndex)?
      onReorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: true,
      maintainState: true,
      title: Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: Spacing.sm),
        Text('${records.length} 条',
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                color: scheme.onSurfaceVariant)),
      ]),
      children: [
        if (onReorder != null)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: records.length,
            onReorder: (o, n) => onReorder!(records, o, n),
            itemBuilder: (context, i) {
              final r = records[i];
              return ReorderableDragStartListener(
                key: ValueKey(r.id),
                index: i,
                child: _WishEntry(
                  record: r,
                  canEdit: canEdit,
                  disabled: isEntryDisabled?.call(r) ?? false,
                  onTap: () => onTapEntry(r),
                  onPlace: () => onPlace(r),
                  onPickDuration: () => onPickDuration(r),
                  onDelete: () => onDelete(r),
                ),
              );
            },
          )
        else
          for (final r in records)
            _WishEntry(
              record: r,
              canEdit: canEdit,
              disabled: isEntryDisabled?.call(r) ?? false,
              onTap: () => onTapEntry(r),
              onPlace: () => onPlace(r),
              onPickDuration: () => onPickDuration(r),
              onDelete: () => onDelete(r),
            ),
      ],
    );
  }
}

class _WishEntry extends StatelessWidget {
  const _WishEntry({
    required this.record,
    required this.canEdit,
    required this.onTap,
    required this.onPlace,
    required this.onPickDuration,
    required this.onDelete,
    this.disabled = false,
  });

  final WishlistRecord record;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onPlace;
  final VoidCallback onPickDuration;
  final VoidCallback onDelete;

  /// 置灰（类型窗与当天无交集）：不可点、无菜单。
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fromGuide = (record.guideRef ?? '').isNotEmpty;
    final dim = disabled;
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: InkWell(
      onTap: canEdit && !dim ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if ((record.tag ?? '').isNotEmpty) ...[
                        _miniChip(context, record.tag!,
                            scheme.primary.withValues(alpha: 0.12),
                            scheme.primary),
                        const SizedBox(width: Spacing.sm),
                      ],
                      _miniChip(
                        context,
                        fromGuide ? '攻略' : '手动',
                        fromGuide
                            ? scheme.tertiary.withValues(alpha: 0.14)
                            : scheme.surfaceContainerHigh,
                        fromGuide ? scheme.tertiary : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              record.durationMin == null ? '未估时' : '${record.durationMin} 分钟',
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                // V2.9.0：「未估时」是中性状态，不再误用 scheme.error 红色。
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (canEdit && !dim)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (v) {
                  switch (v) {
                    case 'place':
                      onPlace();
                      break;
                    case 'duration':
                      onPickDuration();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'place', child: Text('排到第 N 天…')),
                  PopupMenuItem(value: 'duration', child: Text('补充时长…')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              )
            else
              const SizedBox(width: Spacing.sm),
          ],
        ),
      ),
      ),
    );
  }

  Widget _miniChip(BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.capsule,
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: AppFontSizes.caption - 2,
              fontWeight: FontWeight.w600,
              color: fg)),
    );
  }
}

/// 「排到第 N 天」选天弹层。
/// V2.9.0：实现收编到共享组件 day_pick_sheet.dart（1 基 D 序号 + 月日 +
/// 星期 + 当前天高亮），本文件不再自绘列表。

/// 补时长弹层：四档 chips + 自定义 10–720 分钟（越界拒绝）。
class _WishDurationSheet extends StatefulWidget {
  const _WishDurationSheet({this.onDone});

  /// V2.9.0：容器接管 pop（拖拽抽屉里 pop 的是抽屉自身的 context）。
  final ValueChanged<int>? onDone;

  @override
  State<_WishDurationSheet> createState() => _WishDurationSheetState();
}

class _WishDurationSheetState extends State<_WishDurationSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  int? _picked;

  static const _presets = [
    (60, '1 小时'),
    (120, '2 小时'),
    (240, '半天'),
    (480, '一天'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    void done(int v) =>
        widget.onDone != null ? widget.onDone!(v) : Navigator.pop(context, v);
    if (_picked != null) {
      done(_picked!);
      return;
    }
    final v = parseWishlistDuration(_ctrl.text);
    if (v == null) {
      setState(() => _error = '请输入 10–720 之间的分钟数');
      return;
    }
    done(v);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.md, Spacing.lg, Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('预估停留时长', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final (m, label) in _presets)
                  ChoiceChip(
                    label: Text(label),
                    selected: _picked == m,
                    onSelected: (_) => setState(() {
                      _picked = m;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '自定义分钟（10–720）',
                errorText: _error,
                isDense: true,
                suffixText: _picked == null ? null : '已选 $_picked 分钟',
              ),
              onChanged: (_) => setState(() {
                _picked = null;
                _error = null;
              }),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(onPressed: _confirm, child: const Text('确定')),
          ],
        ),
      ),
    );
  }
}
