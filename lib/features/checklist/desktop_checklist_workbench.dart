// 📋 桌面清单工作台：左列表（行程/待办 + 条目）→ 右进度与快捷操作。
// 仅 Web 大屏由 router 分支接入；安卓/窄屏仍走 ChecklistScreen。
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/seed/checklist_templates.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/tokens.dart';
import 'widgets/checklist_progress_card.dart';
import 'widgets/checklist_segmented_control.dart';
import 'widgets/smart_template_sheet.dart';
import '../desktop/desktop_context_menu.dart';
import '../desktop/desktop_utils.dart';

/// 清单分支在桌面态的首屏（替代 ChecklistScreen）。
class DesktopChecklistWorkbench extends ConsumerStatefulWidget {
  const DesktopChecklistWorkbench({super.key});

  @override
  ConsumerState<DesktopChecklistWorkbench> createState() =>
      _DesktopChecklistWorkbenchState();
}

class _DesktopChecklistWorkbenchState
    extends ConsumerState<DesktopChecklistWorkbench> {
  int _segment = 0; // 0 行李 / 1 待办
  String? _tripId;
  final _search = TextEditingController();
  Stream<List<Trip>>? _tripsStream;
  Stream<List<ChecklistItem>>? _itemsStream;
  String? _itemsKey;

  bool get _isLuggage => _segment == 0;

  Stream<List<Trip>> get _watchTrips =>
      _tripsStream ??= ref.read(tripsRepoProvider).watchAll();

  Stream<List<ChecklistItem>> _watchItems() {
    if (_isLuggage) {
      final id = _tripId;
      if (id == null) return const Stream.empty();
      final key = 'trip-$id';
      if (_itemsStream == null || _itemsKey != key) {
        _itemsKey = key;
        _itemsStream = ref.read(checklistRepoProvider).watchByTrip(id);
      }
      return _itemsStream!;
    }
    if (_itemsStream == null || _itemsKey != 'global') {
      _itemsKey = 'global';
      _itemsStream = ref.read(checklistRepoProvider).watchGlobal();
    }
    return _itemsStream!;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _showAddEdit({ChecklistItem? editItem, String? presetCategory}) async {
    if (_isLuggage && _tripId == null) {
      _toast('请先选择行程');
      return;
    }
    final textCtl = TextEditingController(text: editItem?.label ?? '');
    var category = editItem?.category ?? presetCategory ?? kChecklistCategories.first.key;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(editItem == null ? '添加事项' : '编辑事项'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textCtl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '事项内容'),
                ),
                const SizedBox(height: Spacing.md),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: category,
                    items: [
                      for (final c in kChecklistCategories)
                        DropdownMenuItem(value: c.key, child: Text('${c.icon} ${c.name}')),
                    ],
                    onChanged: (v) => setDlgState(() => category = v ?? category),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result != true) {
      textCtl.dispose();
      return;
    }
    final text = textCtl.text.trim();
    textCtl.dispose();
    if (text.isEmpty) return;
    final repo = ref.read(checklistRepoProvider);
    if (editItem != null) {
      await repo.updateItem(editItem.id, label: text, category: category);
    } else {
      final scope = _isLuggage ? 'trip' : 'global';
      final tripId = _isLuggage ? _tripId : null;
      final items = await repo.getAllByScope(scope, tripId: tripId);
      await repo.addItem(tripId, scope, category, text, items.length);
    }
  }

  Future<void> _showTemplates(List<ChecklistItem> items) async {
    final trips = await (ref.read(tripsRepoProvider).watchAll().first);
    final trip = trips.where((t) => t.id == _tripId).firstOrNull;
    if (trip == null) return;
    await openAsDialog(
      context,
      SmartTemplateSheet(
        trip: trip,
        existing: items,
        onImported: () {},
      ),
      width: 860,
    );
  }

  Future<void> _showCopyFromTrip() async {
    final trips = await ref.read(tripsRepoProvider).watchAll().first;
    final others =
        trips.where((t) => t.id != _tripId && !t.archived).toList();
    if (others.isEmpty) {
      _toast('还没有其它行程可复制');
      return;
    }
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('从哪个行程复制清单？'),
        children: [
          for (final t in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Text('${t.emoji} ${t.name}'),
            ),
        ],
      ),
    );
    if (pick == null || _tripId == null) return;
    await ref.read(checklistRepoProvider).copyFromTrip(pick, _tripId!);
    _toast('已复制');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: DesktopLayout.masterPanelWidth + 20,
          child: _buildMaster(scheme),
        ),
        Container(width: 1, color: scheme.outlineVariant),
        Expanded(child: _buildDetail(scheme)),
      ],
    );
  }

  Widget _buildMaster(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
          child: ChecklistSegmentedControl(
            segments: const [
              SegmentLabel(emoji: '🧳', label: '行李清单'),
              SegmentLabel(emoji: '✅', label: '待办清单'),
            ],
            selectedIndex: _segment,
            onChanged: (i) => setState(() {
              _segment = i;
              if (_isLuggage && _tripId == null) {
                _tripsStream ??= ref.read(tripsRepoProvider).watchAll();
              }
            }),
          ),
        ),
        if (_isLuggage)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: StreamBuilder<List<Trip>>(
              stream: _watchTrips,
              builder: (context, snap) {
                final trips = snap.data ?? const <Trip>[];
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: _tripId,
                    hint: const Text('选择行程'),
                    items: [
                      for (final t in trips)
                        DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.emoji} ${t.name}',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (id) => setState(() => _tripId = id),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                hintText: '搜索事项', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _ItemList(stream: _watchItems(), isLuggage: _isLuggage, query: _search.text)),
      ],
    );
  }

  Widget _buildDetail(ColorScheme scheme) {
    final stream = _watchItems();
    return StreamBuilder<List<ChecklistItem>>(
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? const <ChecklistItem>[];
        final done = items.where((i) => i.done).length;
        return ListView(
          padding: const EdgeInsets.all(Spacing.xl),
          children: [
            ChecklistProgressCard(
              total: items.length,
              done: done,
              headerLabel: _isLuggage ? '打包进度' : '待办进度',
            ),
            const SizedBox(height: Spacing.lg),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(_isLuggage ? '添加物品' : '添加待办'),
                  onPressed: () => _showAddEdit(),
                ),
                if (_isLuggage && _tripId != null)
                  ActionChip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('智能模板'),
                    onPressed: () => _showTemplates(items),
                  ),
                if (_isLuggage && _tripId != null)
                  ActionChip(
                    avatar: const Icon(Icons.content_copy_rounded, size: 16),
                    label: const Text('复制其他行程'),
                    onPressed: _showCopyFromTrip,
                  ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Text('分类概览', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final c in kChecklistCategories)
                  if (items.any((i) => i.category == c.key))
                    _CategoryStat(
                      cat: c,
                      total: items.where((i) => i.category == c.key).length,
                      done: items.where((i) => i.category == c.key && i.done).length,
                    ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CategoryStat extends StatelessWidget {
  const _CategoryStat({required this.cat, required this.total, required this.done});
  final ChecklistCategory cat;
  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.button,
      ),
      child: Text('${cat.icon} ${cat.name} $done/$total',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurface)),
    );
  }
}

class _ItemList extends ConsumerWidget {
  const _ItemList({required this.stream, required this.isLuggage, required this.query});
  final Stream<List<ChecklistItem>> stream;
  final bool isLuggage;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<ChecklistItem>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? const <ChecklistItem>[];
        final q = query.trim().toLowerCase();
        final items = q.isEmpty
            ? all
            : all.where((i) => i.label.toLowerCase().contains(q)).toList();
        if (items.isEmpty) {
          return EmptyState(
              emoji: isLuggage ? '📦' : '📝',
              title: isLuggage ? '行李清单空空如也' : '暂无待办事项',
              message: '点击右侧「添加」按钮开始');
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, indent: 48, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          itemBuilder: (context, i) => _CheckRow(item: items[i]),
        );
      },
    );
  }
}

class _CheckRow extends ConsumerStatefulWidget {
  const _CheckRow({required this.item});
  final ChecklistItem item;

  @override
  ConsumerState<_CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends ConsumerState<_CheckRow> {
  bool _hover = false;
  bool _editing = false;
  late final TextEditingController _c = TextEditingController(text: widget.item.label);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _c.text.trim();
    setState(() => _editing = false);
    if (t.isEmpty || t == widget.item.label) return;
    await ref.read(checklistRepoProvider).updateItem(widget.item.id, label: t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final cat = findChecklistCategory(item.category);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onDoubleTap: () => setState(() {
          _c.text = item.label;
          _editing = true;
        }),
        onSecondaryTapDown: (d) => showDesktopContextMenu(context,
            globalPosition: d.globalPosition,
            actions: [
              DesktopAction(label: '编辑', icon: Icons.edit_rounded,
                  onTap: () => setState(() {
                    _c.text = item.label;
                    _editing = true;
                  })),
              DesktopAction(label: '删除', icon: Icons.delete_outline_rounded, danger: true,
                  onTap: () async {
                    await ref.read(checklistRepoProvider).deleteItem(item.id);
                  }),
            ]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: item.done,
                visualDensity: VisualDensity.compact,
                onChanged: (v) async {
                  await ref.read(checklistRepoProvider).toggleDone(item.id, v ?? false);
                },
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: _editing
                    ? TextField(
                        controller: _c,
                        autofocus: true,
                        decoration: const InputDecoration(isDense: true),
                        onSubmitted: (_) => _save(),
                        onTapOutside: (_) => setState(() => _editing = false),
                      )
                    : Text(item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            decoration: item.done ? TextDecoration.lineThrough : null,
                            color: item.done ? scheme.onSurfaceVariant : scheme.onSurface)),
              ),
              const SizedBox(width: Spacing.sm),
              Text('${cat.icon}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (_hover) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '编辑',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () => setState(() {
                    _c.text = item.label;
                    _editing = true;
                  }),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () async {
                    await ref.read(checklistRepoProvider).deleteItem(item.id);
                  },
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
