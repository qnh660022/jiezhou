import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../data/seed/checklist_templates.dart';
import '../../../data/db/database.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import '../../../theme/theme_provider.dart';
import '../widgets/checklist_segmented_control.dart';
import '../widgets/checklist_progress_card.dart';
import '../widgets/checklist_item_tile.dart';
import '../widgets/checklist_skeleton.dart';
import '../widgets/trip_chip_selector.dart';
import '../widgets/smart_template_sheet.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/stagger_in.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key});
  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  int _segmentIndex = 0;
  String? _selectedTripId;
  bool _showConfetti = false;
  Timer? _confettiTimer;

  // —— 流缓存：StreamBuilder 的 stream 必须与 build 解耦（同参同实例）——
  // 否则每次 build 换流 → 取消重订阅 → waiting 骨架闪 → rebuild 循环闪烁。
  // drift 的 watch 流基于 Stream.multi(isBroadcast:true)，可安全重复订阅复用。
  Stream<List<Trip>>? _tripsStream;
  Stream<List<ChecklistItem>>? _tripItemsStream;
  String? _tripItemsKey;
  Stream<List<ChecklistItem>>? _globalItemsStream;

  /// 行李页：行程列表流只建一次
  Stream<List<Trip>> get _watchTrips =>
      _tripsStream ??= ref.read(tripsRepoProvider).watchAll();

  /// 行李页：按选中行程缓存条目流，键变化才重建
  Stream<List<ChecklistItem>> _watchTripItems(String tripId) {
    if (_tripItemsStream == null || _tripItemsKey != tripId) {
      _tripItemsKey = tripId;
      _tripItemsStream = ref.read(checklistRepoProvider).watchByTrip(tripId);
    }
    return _tripItemsStream!;
  }

  bool get _isLuggage => _segmentIndex == 0;

  @override
  void dispose() {
    _confettiTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = ref.read(prefsRepoProvider);
      final lastId = await prefs.getLastChecklistTripId();
      if (lastId != null && mounted) setState(() => _selectedTripId = lastId);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;
    return Stack(children: [
      Column(children: [
        Padding(
          // Tab 根页自绘顶部：补状态栏安全区，避免分段控件顶进额头
          padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + Spacing.md,
              bottom: Spacing.sm),
          child: ChecklistSegmentedControl(
            segments: const [
              SegmentLabel(emoji: '🧳', label: '行李清单'),
              SegmentLabel(emoji: '✅', label: '待办清单'),
            ],
            selectedIndex: _segmentIndex,
            onChanged: (i) => setState(() => _segmentIndex = i),
          ),
        ),
        Expanded(child: _isLuggage ? _buildLuggageBody() : _buildTodoBody()),
      ]),
      if (_showConfetti)
        ConfettiBurst(colors: [scheme.primary, SemanticColors.income, SemanticColors.expense, scheme.tertiary, scheme.secondary]),
    ]);
  }

  Widget _buildLuggageBody() {
    return StreamBuilder<List<Trip>>(
      stream: _watchTrips,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const ChecklistSkeleton();
        if (snapshot.hasError) return EmptyState(emoji: '😵', title: '加载失败', message: snapshot.error.toString());
        final trips = snapshot.data ?? [];
        if (trips.isEmpty) return EmptyState(emoji: '🧳', title: '还没有行程', message: '创建行程后就可以整理行李啦', actionLabel: '去创建行程', onAction: () => context.push('/trips/edit'));
        // 不在 build 中直接改 state（会触发失活元素重建断言）：
        // 用局部变量计算有效选中；失效 id 延迟到 post-frame 安全重置。
        var selectedTripId = _selectedTripId;
        if (selectedTripId != null && !trips.any((t) => t.id == selectedTripId)) {
          final staleId = selectedTripId;
          selectedTripId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedTripId == staleId) setState(() => _selectedTripId = null);
          });
        }
        final effectiveTripId = selectedTripId;
        final stream = effectiveTripId != null ? _watchTripItems(effectiveTripId) : const Stream<List<ChecklistItem>>.empty();
        return Column(children: [
          TripChipSelector(
            trips: trips.map((t) => TripChipData(id: t.id, name: t.name, emoji: t.emoji)).toList(),
            selectedTripId: effectiveTripId,
            onSelect: (id) { setState(() => _selectedTripId = id); ref.read(prefsRepoProvider).setLastChecklistTripId(id); },
            onCopyFromHistory: _showCopyFromHistorySheet,
            onSmartTemplate: _showSmartTemplateSheet,
          ),
          const SizedBox(height: Spacing.sm),
          Expanded(child: effectiveTripId == null ? EmptyState(emoji: '👆', title: '选择行程', message: '在上方选择行程查看行李清单') : _buildChecklistBody(stream, true)),
        ]);
      },
    );
  }

  Widget _buildTodoBody() {
    return _buildChecklistBody(_globalItemsStream ??= ref.read(checklistRepoProvider).watchGlobal(), false);
  }

  Widget _buildChecklistBody(Stream<List<ChecklistItem>> stream, bool isLuggage) {
    return StreamBuilder<List<ChecklistItem>>(stream: stream, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const ChecklistSkeleton();
      final items = snapshot.data ?? [];
      if (items.isEmpty) return EmptyState(
        emoji: isLuggage ? '📦' : '📝',
        title: isLuggage ? '行李清单空空如也' : '暂无待办事项',
        message: isLuggage ? '点击下方按钮添加物品' : '点击下方按钮添加待办',
        actionLabel: isLuggage ? '添加物品' : '添加待办',
        onAction: () => _showAddEditSheet(isLuggage: isLuggage),
      );
      final grouped = _groupByCategory(items);
      final total = items.length;
      final doneCount = items.where((i) => i.done).length;
      final allDone = total > 0 && doneCount == total;
      if (allDone && !_showConfetti) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _showConfetti = true);
          _confettiTimer?.cancel();
          _confettiTimer = Timer(const Duration(milliseconds: 1800), () {
            if (mounted) setState(() => _showConfetti = false);
          });
        });
      }
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.sm),
          child: StaggerIn(delay: Duration.zero, child: ChecklistProgressCard(total: total, done: doneCount, headerLabel: isLuggage ? '打包进度' : '待办进度'))),
        Expanded(child: ListView.builder(
          // 底部留白统一 120：Tab 根页需让出悬浮胶囊底栏高度
          padding: const EdgeInsets.fromLTRB(
              Spacing.xl, Spacing.xs, Spacing.xl, Spacing.huge * 2 + Spacing.xxl),
          itemCount: grouped.length + (isLuggage ? 1 : 0),
          itemBuilder: (context, sectionIndex) {
            if (isLuggage && sectionIndex == grouped.length) return Padding(padding: const EdgeInsets.only(top: Spacing.md), child: _AddMoreButton(onTap: () => _showAddEditSheet(isLuggage: true)));
            final entry = grouped.entries.elementAt(sectionIndex);
            final catKey = entry.key;
            final catItems = entry.value;
            final category = findChecklistCategory(catKey);
            final catDone = catItems.where((i) => i.done).length;
            return StaggerIn(delay: Duration(milliseconds: 80 * sectionIndex), child: _CategorySection(
              category: category, done: catDone, total: catItems.length, items: catItems,
              onToggle: (item) => _toggleItem(item),
              onEdit: (item) => _showAddEditSheet(isLuggage: isLuggage, editItem: item),
              onDelete: (item) => _deleteItem(item),
              onReorder: (oldIdx, newIdx) => _reorderItems(catItems, oldIdx, newIdx),
              onAddFromTemplate: () => _showTemplateSheet(catKey, isLuggage),
              onAdd: () => _showAddEditSheet(isLuggage: isLuggage, presetCategory: catKey),
            ));
          },
        )),
      ]);
    });
  }

  Map<String, List<ChecklistItem>> _groupByCategory(List<ChecklistItem> items) {
    final map = <String, List<ChecklistItem>>{};
    for (final item in items) map.putIfAbsent(item.category, () => []).add(item);
    final order = kChecklistCategories.map((c) => c.key).toList();
    final sorted = <String, List<ChecklistItem>>{};
    for (final key in order) { if (map.containsKey(key)) sorted[key] = map[key]!; }
    for (final key in map.keys) { if (!sorted.containsKey(key)) sorted[key] = map[key]!; }
    return sorted;
  }

  Future<void> _toggleItem(ChecklistItem item) async {
    final repo = ref.read(checklistRepoProvider);
    await repo.toggleDone(item.id, !item.done);
    HapticFeedback.lightImpact();
  }

  Future<void> _deleteItem(ChecklistItem item) async {
    final repo = ref.read(checklistRepoProvider);
    await repo.deleteItem(item.id);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已删除「' + item.label + '」'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: '撤销', onPressed: () async { await repo.addItem(item.tripId, item.scope, item.category, item.label, item.sortOrder); }),
      ));
    }
  }

  Future<void> _reorderItems(List<ChecklistItem> items, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final repo = ref.read(checklistRepoProvider);
    HapticFeedback.mediumImpact();
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = items.removeAt(oldIndex);
    items.insert(adjustedNew, moved);
    for (var i = 0; i < items.length; i++) await repo.reorderItem(items[i].id, i);
  }

  void _showAddEditSheet({required bool isLuggage, ChecklistItem? editItem, String? presetCategory}) {
    final repo = ref.read(checklistRepoProvider);
    final isEdit = editItem != null;
    final textCtrl = TextEditingController(text: editItem?.label ?? '');
    String selectedCat = editItem?.category ?? presetCategory ?? 'other';
    final formKey = GlobalKey<FormState>();
    showDraggableSheet(context: context, initialChildSize: 0.55, builder: (ctx, scrollCtrl) {
      return StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(padding: const EdgeInsets.all(Spacing.xl), child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEdit ? '编辑条目' : (isLuggage ? '添加物品' : '添加待办'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.lg),
          TextFormField(controller: textCtrl, autofocus: true, decoration: const InputDecoration(hintText: '物品名称', border: OutlineInputBorder(borderRadius: AppRadius.input)), validator: (v) => (v == null || v.trim().isEmpty) ? '不能为空' : null),
          const SizedBox(height: Spacing.lg),
          if (isLuggage) ...[
            Text('所属分类', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.sm),
            Wrap(spacing: Spacing.sm, runSpacing: Spacing.sm, children: kChecklistCategories.map((cat) {
              final isSel = cat.key == selectedCat;
              return GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setSheetState(() => selectedCat = cat.key); },
                child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(color: isSel ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: AppRadius.capsule, border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant)),
                  child: Text(cat.icon + ' ' + cat.name, style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant))),
              );
            }).toList()),
          ],
          const SizedBox(height: Spacing.xxl),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () async { if (!formKey.currentState!.validate()) return; HapticFeedback.lightImpact(); final text = textCtrl.text.trim(); if (isEdit) { await repo.updateItem(editItem.id, label: text, category: selectedCat); } else { final scope = isLuggage ? 'trip' : 'global'; final existing = isLuggage && _selectedTripId != null ? await repo.getAllByScope(scope, tripId: _selectedTripId) : await repo.getAllByScope(scope); await repo.addItem(_selectedTripId, scope, selectedCat, text, existing.length); } if (ctx.mounted) Navigator.of(ctx).pop(); },
            style: FilledButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: AppRadius.button)),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: Spacing.md), child: Text(isEdit ? '保存' : '添加')),
          )),
        ])));
      });
    }).then((_) => textCtrl.dispose());
  }

  void _showTemplateSheet(String categoryKey, bool isLuggage) {
    final repo = ref.read(checklistRepoProvider);
    final category = findChecklistCategory(categoryKey);
    final selectedItems = <String>{};
    showDraggableSheet(context: context, initialChildSize: 0.6, builder: (ctx, scrollCtrl) {
      return StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(padding: const EdgeInsets.all(Spacing.xl), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(category.icon, style: const TextStyle(fontSize: 24)), const SizedBox(width: Spacing.md), Expanded(child: Text('从「' + category.name + '」模板导入', style: Theme.of(context).textTheme.titleMedium))]),
          const SizedBox(height: Spacing.lg),
          Row(children: [TextButton(onPressed: () { setSheetState(() { if (selectedItems.length == category.items.length) { selectedItems.clear(); } else { selectedItems.addAll(category.items); } }); }, child: Text(selectedItems.length == category.items.length ? '全不选' : '全选')), const Spacer(), Text(selectedItems.length.toString() + '/' + category.items.length.toString(), style: Theme.of(context).textTheme.bodySmall)]),
          const SizedBox(height: Spacing.sm),
          Flexible(child: ListView.builder(controller: scrollCtrl, itemCount: category.items.length, itemBuilder: (_, i) {
            final itemText = category.items[i];
            final isSel = selectedItems.contains(itemText);
            return CheckboxListTile(value: isSel, onChanged: (v) { setSheetState(() { if (v == true) { selectedItems.add(itemText); } else { selectedItems.remove(itemText); } }); }, title: Text(itemText), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.inputValue)));
          })),
          const SizedBox(height: Spacing.md),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: selectedItems.isEmpty ? null : () async { HapticFeedback.lightImpact(); final scope = isLuggage ? 'trip' : 'global'; final existing = isLuggage && _selectedTripId != null ? await repo.getAllByScope(scope, tripId: _selectedTripId) : await repo.getAllByScope(scope); var order = existing.length; for (final tplText in selectedItems) { await repo.addItem(_selectedTripId, scope, categoryKey, tplText, order++); } if (ctx.mounted) Navigator.of(ctx).pop(); },
            style: FilledButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: AppRadius.button)),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: Spacing.md), child: Text('导入 ' + selectedItems.length.toString() + ' 项')),
          )),
        ]));
      });
    });
  }

  /// 智能模板库：拉取当前行程 + 已有条目，弹推荐场景抽屉
  void _showSmartTemplateSheet() {
    final tid = _selectedTripId;
    if (tid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('先在上方选一个行程，再套用模板')));
      return;
    }
    HapticFeedback.selectionClick();
    final tripsRepoInst = ref.read(tripsRepoProvider);
    final repo = ref.read(checklistRepoProvider);
    tripsRepoInst.watchTrip(tid).first.then((trip) async {
      if (trip == null || !mounted) return;
      final existing = await repo.getAllByScope('trip', tripId: tid);
      if (!mounted) return;
      showDraggableSheet(
        context: context,
        initialChildSize: 0.72,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => SmartTemplateSheet(
          trip: trip,
          existing: existing,
          onImported: () {
            if (mounted) {
              // 触发当前行程流重建（流缓存键不变，靠 drift 数据流自动刷新）
              setState(() {});
            }
          },
        ),
      );
    });
  }

  void _showCopyFromHistorySheet() {
    final repo = ref.read(checklistRepoProvider);
    final tripsRepoInst = ref.read(tripsRepoProvider);
    // 每次打开 sheet 只建一次流、闭包内复用：sheet 拖拽/重建不再换流重订阅
    final tripsStream = tripsRepoInst.watchAll();
    showDraggableSheet(context: context, initialChildSize: 0.55, builder: (ctx, scrollCtrl) {
      return StreamBuilder<List<Trip>>(stream: tripsStream, builder: (context, snapshot) {
        final trips = snapshot.data ?? [];
        return Padding(padding: const EdgeInsets.all(Spacing.xl), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('从历史行程复制', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.sm),
          Text('选择一个行程，将其行李清单复制到当前行程', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.lg),
          Flexible(child: trips.isEmpty ? const Center(child: Text('暂无其他行程')) : ListView.builder(controller: scrollCtrl, itemCount: trips.length, itemBuilder: (_, i) {
            final trip = trips[i];
            final isCurrent = trip.id == _selectedTripId;
            return ListTile(leading: Text(trip.emoji, style: const TextStyle(fontSize: 24)), title: Text(trip.name), subtitle: Text(trip.destination), trailing: isCurrent ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null, enabled: !isCurrent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.inputValue)),
              onTap: isCurrent ? null : () async { if (_selectedTripId == null) return; await repo.copyFromTrip(trip.id, _selectedTripId!); if (ctx.mounted) { Navigator.of(ctx).pop(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已从「' + trip.name + '」复制清单'))); } },
            );
          })),
        ]));
      });
    });
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.done, required this.total, required this.items, required this.onToggle, required this.onEdit, required this.onDelete, required this.onReorder, required this.onAddFromTemplate, required this.onAdd});
  final ChecklistCategory category;
  final int done;
  final int total;
  final List<ChecklistItem> items;
  final ValueChanged<ChecklistItem> onToggle;
  final ValueChanged<ChecklistItem> onEdit;
  final ValueChanged<ChecklistItem> onDelete;
  final void Function(int, int) onReorder;
  final VoidCallback onAddFromTemplate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = total > 0 ? done / total : 0.0;
    return Container(margin: const EdgeInsets.only(bottom: Spacing.md), decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: AppRadius.card, border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.xs), child: Row(children: [
          Text(category.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: Spacing.sm),
          Text(category.name, style: TextStyle(fontSize: AppFontSizes.bodyLarge, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(width: Spacing.sm),
          MiniProgressBadge(value: progress),
          const SizedBox(width: Spacing.xs),
          Text(done.toString() + '/' + total.toString(), style: TextStyle(fontSize: AppFontSizes.caption, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant, fontFeatures: AppTextStyles.tabularFigures)),
          const Spacer(),
          GestureDetector(onTap: onAddFromTemplate, child: Container(padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs), decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.7), borderRadius: AppRadius.capsule), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome_outlined, size: 14, color: scheme.primary), const SizedBox(width: 3), Text('模板', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary))]))),
          const SizedBox(width: Spacing.sm),
          GestureDetector(onTap: onAdd, child: Icon(Icons.add_rounded, size: 22, color: scheme.primary)),
        ])),
        if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md), child: Text('暂无物品，点击 + 或模板导入', style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant.withValues(alpha: 0.7))))
        else ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), onReorderItem: (oldIndex, newIndex) { onReorder(oldIndex, newIndex); }, itemCount: items.length,
          proxyDecorator: (child, index, animation) { return AnimatedBuilder(animation: animation, builder: (context, _) { final t = animation.value; return Transform.scale(scale: 1.0 + 0.06 * (1 - t), child: Opacity(opacity: 0.85 + 0.15 * t, child: child)); }); },
          itemBuilder: (context, index) {
            final sorted = List<ChecklistItem>.from(items)..sort((a, b) { if (a.done != b.done) return a.done ? 1 : -1; return a.sortOrder.compareTo(b.sortOrder); });
            final item = sorted[index];
            return ChecklistItemTile(key: ValueKey(item.id), item: ChecklistItemView(id: item.id, text: item.label, done: item.done), index: index, onToggle: () => onToggle(item), onEdit: () => onEdit(item), onDeleteConfirmed: () => onDelete(item));
          },
        ),
        const SizedBox(height: Spacing.xs),
      ],
    ),
    );
  }
}

class _AddMoreButton extends StatelessWidget {
  const _AddMoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: Spacing.md), decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.4), borderRadius: AppRadius.card, border: Border.all(color: scheme.primary.withValues(alpha: 0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, size: 20, color: scheme.primary), const SizedBox(width: Spacing.sm), Text('添加物品', style: TextStyle(fontSize: AppFontSizes.body, fontWeight: FontWeight.w600, color: scheme.primary))]),
    ));
  }
}
