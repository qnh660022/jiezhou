// 🧳 桌面行程工作台：左列表 → 右详情，行内快改、右键菜单、批量操作。
// 仅 Web 大屏由 router 分支接入；安卓/窄屏不受影响。
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../export/share_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/tokens.dart';
import 'screens/item_edit_screen.dart';
import 'screens/trip_edit_screen.dart';
import 'trip_utils.dart';
import '../desktop/desktop_context_menu.dart';
import '../desktop/desktop_utils.dart';

/// 行程分支在桌面态的首屏（替代 TripsHomeScreen）。
class DesktopTripsWorkbench extends ConsumerStatefulWidget {
  const DesktopTripsWorkbench({super.key});

  @override
  ConsumerState<DesktopTripsWorkbench> createState() =>
      _DesktopTripsWorkbenchState();
}

class _DesktopTripsWorkbenchState extends ConsumerState<DesktopTripsWorkbench> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _filter = 'all'; // all|ongoing|upcoming|planning|ended
  String? _selectedId;
  bool _multi = false;
  final Set<String> _picked = {};

  Stream<List<Trip>>? _stream;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  bool _matchFilter(TripLifeStatus s) {
    switch (_filter) {
      case 'ongoing':
        return s == TripLifeStatus.ongoing;
      case 'upcoming':
        return s == TripLifeStatus.upcoming;
      case 'planning':
        return s == TripLifeStatus.planning;
      case 'ended':
        return s == TripLifeStatus.ended;
      default:
        return true;
    }
  }

  Future<void> _newTrip() => openAsDialog(
        context,
        const TripEditScreen(initialId: null),
        width: 680,
      );

  Future<void> _editTrip(String id) =>
      openAsDialog(context, TripEditScreen(initialId: id), width: 680);

  Future<void> _toggleArchive(Trip t, WidgetRef ref) async {
    await ref.read(tripsRepoProvider).archiveTrip(t.id, !t.archived);
    _toast(t.archived ? '已恢复到列表' : '已归档');
  }

  Future<void> _deleteTrip(Trip t, WidgetRef ref) async {
    final ok = await _confirm(
      title: '删除「${t.name}」？',
      message: '安排、相册将一并删除，账单自动解绑，此操作不可恢复。',
      danger: true,
    );
    if (ok != true) return;
    await ref.read(tripsRepoProvider).deleteTrip(t.id);
    _toast('行程已删除');
  }

  Future<void> _exportTrip(Trip t, WidgetRef ref) async {
    try {
      final bytes = await ref.read(tripsRepoProvider).exportTripBackupBytes(t.id);
      final base =
          t.name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_').trim();
      await shareFile(bytes, '${base.isEmpty ? '行程' : base}_backup.tat',
          'application/x-travel-assistant-trip');
    } catch (_) {
      _toast('备份失败，稍后再试');
    }
  }

  List<DesktopAction> _actionsFor(Trip t) => [
        DesktopAction(
            label: '打开详情',
            icon: Icons.open_in_new_rounded,
            onTap: () => context.push('/trips/detail', extra: t.id)),
        DesktopAction(
            label: '编辑行程',
            icon: Icons.edit_rounded,
            onTap: () => _editTrip(t.id)),
        DesktopAction(
            label: '复制为副本',
            icon: Icons.copy_rounded,
            onTap: () async {
              await ref.read(tripsRepoProvider).copyTrip(t.id);
              _toast('已创建副本');
            }),
        DesktopAction(
            label: '导出行程备份（.tat）',
            icon: Icons.save_alt_rounded,
            onTap: () => _exportTrip(t, ref)),
        DesktopAction(
            label: t.archived ? '取消归档' : '归档行程',
            icon: Icons.archive_outlined,
            onTap: () => _toggleArchive(t, ref)),
        DesktopAction(
            label: '删除行程',
            icon: Icons.delete_outline_rounded,
            danger: true,
            onTap: () => _deleteTrip(t, ref)),
      ];

  Future<T?> _confirm<T>({required String title, String? message, bool danger = false}) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: DesktopLayout.masterPanelWidth,
          child: _buildMaster(),
        ),
        Container(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(child: _buildDetail()),
      ],
    );
  }

  Widget _buildMaster() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
          child: StreamBuilder<List<Trip>>(
            stream: _stream ??= ref.read(tripsRepoProvider).watchAll(),
            builder: (context, snap) {
              final trips = snap.data ?? const <Trip>[];
              return Row(
                children: [
                  Text('行程',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  const SizedBox(width: Spacing.sm),
                  Text('${trips.length} 个',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_multi) {
                      _picked.clear();
                      setState(() => _multi = false);
                    } else {
                      _newTrip();
                    }
                  },
                  icon: _multi
                      ? const Icon(Icons.close_rounded, size: 18)
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(_multi ? '退出多选' : '新建行程'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              IconButton(
                tooltip: _multi ? '退出多选' : '多选',
                onPressed: () => setState(() {
                  _multi = !_multi;
                  if (!_multi) _picked.clear();
                }),
                icon: Icon(_multi ? Icons.check_box_rounded : Icons.checklist_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '搜索行程', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
            children: [
              for (final (k, v) in [
                ('all', '全部'), ('ongoing', '进行中'), ('upcoming', '即将'), ('planning', '规划'), ('ended', '已结束'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: FilterChip(
                    label: Text(v),
                    selected: _filter == k,
                    onSelected: (_) => setState(() => _filter = k),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _multi ? _buildBatchBar() : _buildTripList(scheme),
        ),
      ],
    );
  }

  Widget _buildBatchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StreamBuilder<List<Trip>>(
            stream: _stream ??= ref.read(tripsRepoProvider).watchAll(),
            builder: (context, snap) {
              final trips = snap.data ?? const <Trip>[];
              return ListView(
                controller: _scroll,
                children: [
                  for (final t in trips)
                    CheckboxListTile(
                      dense: true,
                      value: _picked.contains(t.id),
                      title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(cnDateRange(t.startEpochDay, t.endEpochDay),
                          style: const TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (_) => setState(() {
                        if (!_picked.add(t.id)) _picked.remove(t.id);
                      }),
                    ),
                ],
              );
            },
          ),
        ),
        if (_picked.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            color: scheme.surfaceContainer,
            child: Row(
              children: [
                Text('已选 ${_picked.length} 项'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final ok = await _confirm(
                        title: '归档所选 ${_picked.length} 个行程？',
                        message: '归档后折叠到列表尾部。');
                    if (ok != true) return;
                    final repo = ref.read(tripsRepoProvider);
                    for (final id in _picked) {
                      await repo.archiveTrip(id, true);
                    }
                    _picked.clear();
                    setState(() => _multi = false);
                    _toast('已归档');
                  },
                  child: const Text('批量归档'),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await _confirm(
                        title: '删除所选 ${_picked.length} 个行程？',
                        message: '此操作不可恢复。',
                        danger: true);
                    if (ok != true) return;
                    final repo = ref.read(tripsRepoProvider);
                    for (final id in _picked) {
                      await repo.deleteTrip(id);
                    }
                    _picked.clear();
                    setState(() => _multi = false);
                    _toast('已删除');
                  },
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('批量删除'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTripList(ColorScheme scheme) {
    return StreamBuilder<List<Trip>>(
      stream: _stream ??= ref.read(tripsRepoProvider).watchAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(emoji: '😵', title: '加载失败', message: '${snap.error}');
        }
        final all = snap.data ?? const <Trip>[];
        final q = _search.text.trim().toLowerCase();
        var trips = all.where((t) {
          if (t.archived) return false;
          if (q.isNotEmpty && !t.name.toLowerCase().contains(q) && !t.destination.toLowerCase().contains(q)) {
            return false;
          }
          return _matchFilter(classifyTrip(
              startEpochDay: t.startEpochDay,
              endEpochDay: t.endEpochDay,
              archived: false,
              today: todayEpochDay()));
        }).toList()
          ..sort((a, b) => a.startEpochDay.compareTo(b.startEpochDay));
        final archived = all.where((t) => t.archived).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final children = <Widget>[
          for (final t in trips) _tripRow(scheme, t),
          if (archived.isNotEmpty) ...[
            Divider(height: 24, indent: Spacing.md, endIndent: Spacing.md, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 6),
              child: Text('已归档 ${archived.length}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ),
            for (final t in archived.take(30)) _tripRow(scheme, t),
          ],
          const SizedBox(height: Spacing.xl),
        ];
        return ListView(
          controller: _scroll,
          children: children.isEmpty ? [const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('没有匹配的行程')))] : children,
        );
      },
    );
  }

  Widget _tripRow(ColorScheme scheme, Trip t) {
    final today = todayEpochDay();
    final status = classifyTrip(
        startEpochDay: t.startEpochDay,
        endEpochDay: t.endEpochDay,
        archived: t.archived,
        today: today);
    final sel = _selectedId == t.id;
    return InkWell(
      onTap: () => setState(() => _selectedId = t.id),
      onDoubleTap: () => _editTrip(t.id),
      onSecondaryTapDown: (d) => showDesktopContextMenu(
          context, globalPosition: d.globalPosition, actions: _actionsFor(t)),
      child: Container(
        color: sel ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 10),
        child: Row(
          children: [
            Text(t.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${t.destination.isEmpty ? '目的地待定' : t.destination} · ${cnDateRange(t.startEpochDay, t.endEpochDay)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            _StatusDot(status: status),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail() {
    final id = _selectedId;
    if (id == null) {
      return const EmptyState(
          emoji: '🧭', title: '选择左侧行程', message: '点选一个行程即可在这里快速查看、修改安排与日期');
    }
    return _DesktopTripPane(tripId: id, onEditTrip: _editTrip);
  }
}

/// 行程详情右栏视图切换（列表 / 时间轴）的本地状态。
class _TripView {
  static final provider = StateProvider<String>((_) => 'list');
}

/// 行程详情主从右栏：行内改名/改日期 + 按天安排 + 添加/编辑/删除。
class _DesktopTripPane extends ConsumerWidget {
  const _DesktopTripPane({required this.tripId, required this.onEditTrip});

  final String tripId;
  final void Function(String id) onEditTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(tripsRepoProvider);
    final view = ref.watch(_TripView.provider);
    return StreamBuilder<Trip?>(
      stream: repo.watchTrip(tripId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final trip = snap.data;
        if (trip == null) {
          return const EmptyState(emoji: '🗂️', title: '行程不存在', message: '可能已被删除');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _paneHeader(context, ref, scheme, trip),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'list', label: Text('列表'), icon: Icon(Icons.view_list_rounded, size: 16)),
                    ButtonSegment(value: 'timeline', label: Text('时间轴'), icon: Icon(Icons.timeline_rounded, size: 16)),
                  ],
                  selected: {view},
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  onSelectionChanged: (v) =>
                      ref.read(_TripView.provider.notifier).state = v.first,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
            Expanded(
              child: view == 'timeline'
                  ? _TimelineView(trip: trip)
                  : _DayItems(trip: trip),
            ),
          ],
        );
      },
    );
  }

  Widget _paneHeader(BuildContext context, WidgetRef ref, ColorScheme scheme, Trip trip) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 点击即切换行程徽章（快速改 emoji）
              Tooltip(
                message: '点击切换徽章',
                child: InkWell(
                  onTap: () => _cycleEmoji(context, ref, trip),
                  customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    width: 46, height: 46, alignment: Alignment.center,
                    decoration: BoxDecoration(
                        gradient: CoverGradients.gradientFor(trip.cover),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(trip.emoji, style: const TextStyle(fontSize: 23)),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditableName(trip: trip),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(child: _EditableDestination(trip: trip)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text(cnDateRange(trip.startEpochDay, trip.endEpochDay)),
                onPressed: () => _pickDates(context, ref, trip),
              ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加安排'),
                onPressed: () =>
                    openAsDialog(context, ItemEditScreen(tripId: tripId, item: null), width: 700),
              ),
              ActionChip(
                avatar: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('编辑行程'),
                onPressed: () => onEditTrip(tripId),
              ),
              ActionChip(
                avatar: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('导出'),
                onPressed: () => _exportTrip(context, ref, trip),
              ),
              ActionChip(
                avatar: Icon(
                    trip.archived ? Icons.unarchive_rounded : Icons.archive_outlined,
                    size: 16),
                label: Text(trip.archived ? '取消归档' : '归档'),
                onPressed: () async {
                  await ref.read(tripsRepoProvider).archiveTrip(trip.id, !trip.archived);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('删除'),
                backgroundColor: scheme.errorContainer,
                labelStyle: TextStyle(color: scheme.onErrorContainer),
                onPressed: () => _deleteTrip(context, ref, trip),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cycleEmoji(BuildContext context, WidgetRef ref, Trip t) async {
    final i = (kTripEmojis.indexOf(t.emoji) + 1) % kTripEmojis.length;
    await ref.read(tripsRepoProvider).updateTrip(t.copyWith(emoji: kTripEmojis[i]));
  }

  Future<void> _pickDates(BuildContext context, WidgetRef ref, Trip t) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
          start: epochDayToDate(t.startEpochDay), end: epochDayToDate(t.endEpochDay)),
      helpText: '调整行程日期区间',
    );
    if (range != null) {
      await ref
          .read(tripsRepoProvider)
          .updateDates(t.id, dateToEpochDay(range.start), dateToEpochDay(range.end));
    }
  }

  Future<void> _exportTrip(BuildContext context, WidgetRef ref, Trip t) async {
    try {
      final bytes = await ref.read(tripsRepoProvider).exportTripBackupBytes(t.id);
      final base = t.name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_').trim();
      await shareFile(bytes, '${base.isEmpty ? '行程' : base}_backup.tat',
          'application/x-travel-assistant-trip');
    } catch (_) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('备份失败，稍后再试')));
    }
  }

  Future<void> _deleteTrip(BuildContext context, WidgetRef ref, Trip t) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${t.name}」？'),
        content: const Text('安排、相册将一并删除，账单自动解绑，此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tripsRepoProvider).deleteTrip(t.id);
  }
}

/// 行内改名：双击名称进入编辑态，回车保存、Esc/失焦取消。
class _EditableName extends ConsumerStatefulWidget {
  const _EditableName({required this.trip});
  final Trip trip;

  @override
  ConsumerState<_EditableName> createState() => _EditableNameState();
}

class _EditableNameState extends ConsumerState<_EditableName> {
  late final TextEditingController _c;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.trip.name);
  }

  @override
  void didUpdateWidget(covariant _EditableName old) {
    super.didUpdateWidget(old);
    if (old.trip.name != widget.trip.name) _c.text = widget.trip.name;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _c.text.trim();
    if (mounted) setState(() => _editing = false);
    if (name.isEmpty || name == widget.trip.name) return;
    await ref
        .read(tripsRepoProvider)
        .updateTrip(widget.trip.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onDoubleTap: () => setState(() {
          _c.text = widget.trip.name;
          _editing = true;
        }),
        child: Text(widget.trip.name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      );
    }
    return TextField(
      controller: _c,
      autofocus: true,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      onSubmitted: (_) => _save(),
      onTapOutside: (_) => setState(() => _editing = false),
    );
  }
}

/// 行内改目的地：双击进入编辑态，回车保存、失焦取消。
class _EditableDestination extends ConsumerStatefulWidget {
  const _EditableDestination({required this.trip});
  final Trip trip;

  @override
  ConsumerState<_EditableDestination> createState() => _EditableDestinationState();
}

class _EditableDestinationState extends ConsumerState<_EditableDestination> {
  late final TextEditingController _c;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.trip.destination);
  }

  @override
  void didUpdateWidget(covariant _EditableDestination old) {
    super.didUpdateWidget(old);
    if (old.trip.destination != widget.trip.destination) {
      _c.text = widget.trip.destination;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final dest = _c.text.trim();
    if (mounted) setState(() => _editing = false);
    if (dest == widget.trip.destination) return;
    await ref
        .read(tripsRepoProvider)
        .updateTrip(widget.trip.copyWith(destination: dest));
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return GestureDetector(
        onDoubleTap: () => setState(() {
          _c.text = widget.trip.destination;
          _editing = true;
        }),
        child: Text(
            widget.trip.destination.isEmpty ? '目的地待定（双击修改）' : widget.trip.destination,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontStyle: widget.trip.destination.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return TextField(
      controller: _c,
      autofocus: true,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(2)),
      onSubmitted: (_) => _save(),
      onTapOutside: (_) => setState(() => _editing = false),
    );
  }
}

/// 按天安排列表：每组一天，行内时间/名称/类型 + 悬浮编辑/删除。
class _DayItems extends ConsumerWidget {
  const _DayItems({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(tripsRepoProvider);
    return StreamBuilder<List<TripItem>>(
      stream: repo.watchItems(trip.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <TripItem>[];
        if (items.isEmpty) {
          return const EmptyState(emoji: '📅', title: '还没有安排', message: '点右上角「添加安排」规划行程');
        }
        // 按天分组
        final byDay = <int, List<TripItem>>{};
        for (final it in items) {
          byDay.putIfAbsent(it.dateEpochDay, () => []).add(it);
        }
        final days = byDay.keys.toList()..sort();
        return ListView.builder(
          padding: const EdgeInsets.all(Spacing.lg),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final list = byDay[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: Text('第 ${dayIndexOf(trip.startEpochDay, trip.endEpochDay, day) + 1} 天 · ${fmtMonthDayOfEpoch(day)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary)),
                ),
                for (final it in list) _ItemRow(tripId: trip.id, item: it),
              ],
            );
          },
        );
      },
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.tripId, required this.item});
  final String tripId;
  final TripItem item;

  static const _typeEmoji = {
    'attraction': '🏞️', 'food': '🍜', 'hotel': '🏨', 'transport': '🚗',
    'flight': '✈️', 'shopping': '🛍️', 'other': '📍',
  };

  String _time(int? min) {
    if (min == null) return '';
    final h = (min ~/ 60).toString().padLeft(2, '0');
    final m = (min % 60).toString().padLeft(2, '0');
    return '$h:$m ';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onDoubleTap: () => openAsDialog(context, ItemEditScreen(tripId: tripId, item: item), width: 700),
      onSecondaryTapDown: (d) => showDesktopContextMenu(context,
          globalPosition: d.globalPosition,
          actions: [
            DesktopAction(label: '编辑安排', icon: Icons.edit_rounded,
                onTap: () => openAsDialog(context, ItemEditScreen(tripId: tripId, item: item), width: 700)),
            DesktopAction(label: '删除安排', icon: Icons.delete_outline_rounded, danger: true,
                onTap: () async {
                  await ref.read(tripsRepoProvider).deleteItem(item.id);
                }),
          ]),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(_typeEmoji[item.type] ?? '📍', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_time(item.startTimeMin)}${item.name}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (item.address.isNotEmpty)
                    Text(item.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (item.costCents != null)
              Text((item.costCents! / 100).toStringAsFixed(0) + ' 元',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final TripLifeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TripLifeStatus.ongoing => Colors.green,
      TripLifeStatus.upcoming => Colors.blue,
      TripLifeStatus.planning => Colors.orange,
      TripLifeStatus.ended => Colors.grey,
      TripLifeStatus.archived => Colors.grey,
    };
    return Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

/// 行程时间轴视图：按天横排 0-24 时，色块拖拽调整开始时间（双击编辑）。
class _TimelineView extends ConsumerWidget {
  const _TimelineView({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(tripsRepoProvider);
    return StreamBuilder<List<TripItem>>(
      stream: repo.watchItems(trip.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <TripItem>[];
        if (items.isEmpty) {
          return const EmptyState(emoji: '📅', title: '还没有安排', message: '点右上角「添加安排」规划行程');
        }
        final byDay = <int, List<TripItem>>{};
        for (final it in items) {
          byDay.putIfAbsent(it.dateEpochDay, () => []).add(it);
        }
        final days = byDay.keys.toList()..sort();
        return ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Text('横向拖拽色块可调整开始时间 · 双击打开编辑',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.md),
            for (final day in days)
              _DayTimeline(day: day, items: byDay[day]!, trip: trip),
          ],
        );
      },
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline(
      {required this.day, required this.items, required this.trip});
  final int day;
  final List<TripItem> items;
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final withTime = items.where((i) => i.startTimeMin != null).toList()
      ..sort((a, b) => a.startTimeMin!.compareTo(b.startTimeMin!));
    final allDay = items.where((i) => i.startTimeMin == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Text(
            '第 ${dayIndexOf(trip.startEpochDay, trip.endEpochDay, day) + 1} 天 · ${fmtMonthDayOfEpoch(day)}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary),
          ),
        ),
        if (allDay.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final it in allDay) _AllDayChip(item: it, tripId: trip.id),
            ],
          ),
          const SizedBox(height: Spacing.sm),
        ],
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            const axisH = 22.0;
            const barH = 54.0;
            const hours = [0, 3, 6, 9, 12, 15, 18, 21, 24];
            return Column(
              children: [
                SizedBox(
                  height: axisH,
                  width: w,
                  child: Stack(
                    children: [
                      for (final h in hours)
                        Positioned(
                          left: w * (h / 24) - (h == 24 ? 20 : 0),
                          child: Text('$h:00',
                              style: TextStyle(
                                  fontSize: 9, color: scheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
                Container(
                  height: barH,
                  width: w,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  child: Stack(
                    children: [
                      for (final h in hours)
                        Positioned(
                          left: w * (h / 24),
                          top: 0,
                          bottom: 0,
                          child: Container(
                              width: 1,
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                      for (final it in withTime)
                        _TimelineBlock(
                          item: it,
                          widthPx: w,
                          barH: barH,
                          tripId: trip.id,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.lg),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TimelineBlock extends ConsumerStatefulWidget {
  const _TimelineBlock({
    required this.item,
    required this.widthPx,
    required this.barH,
    required this.tripId,
  });

  final TripItem item;
  final double widthPx;
  final double barH;
  final String tripId;

  @override
  ConsumerState<_TimelineBlock> createState() => _TimelineBlockState();
}

class _TimelineBlockState extends ConsumerState<_TimelineBlock> {
  static const _typeEmoji = {
    'attraction': '🏞️', 'food': '🍜', 'hotel': '🏨', 'transport': '🚗',
    'flight': '✈️', 'shopping': '🛍️', 'other': '📍',
  };
  double _dragDx = 0;
  int _dragBaseMin = 0;

  double get _left =>
      widget.widthPx * ((widget.item.startTimeMin ?? 0) / 1440);
  double get _blockW => widget.widthPx *
      ((widget.item.durationMin ?? 60).clamp(30, 480) / 1440);

  Future<void> _endDrag() async {
    final minutes = (_dragDx / widget.widthPx * 1440).round();
    final newMin = (_dragBaseMin + minutes).clamp(0, 1440);
    if (newMin != (widget.item.startTimeMin ?? 0)) {
      await ref
          .read(tripsRepoProvider)
          .updateItem(widget.item.id,
              TripItemsCompanion(startTimeMin: Value(newMin)));
    }
    if (mounted) setState(() => _dragDx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = (_left + _dragDx).clamp(0.0, widget.widthPx - 40.0).toDouble();
    final bw = _blockW.clamp(40.0, widget.widthPx).toDouble();
    return Positioned(
      left: left,
      top: 6,
      height: widget.barH - 12,
      width: bw,
      child: GestureDetector(
        onDoubleTap: () => openAsDialog(context,
            ItemEditScreen(tripId: widget.tripId, item: widget.item),
            width: 700),
        onHorizontalDragStart: (_) =>
            _dragBaseMin = widget.item.startTimeMin ?? 0,
        onHorizontalDragUpdate: (d) => setState(() => _dragDx += d.delta.dx),
        onHorizontalDragEnd: (_) => _endDrag(),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${_typeEmoji[widget.item.type] ?? '📍'} '
              '${_fmtTime(widget.item.startTimeMin)} ${widget.item.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTime(int? min) {
    if (min == null) return '';
    final h = (min ~/ 60).toString().padLeft(2, '0');
    final m = (min % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.item, required this.tripId});
  final TripItem item;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      avatar: const Icon(Icons.schedule_rounded, size: 14),
      onPressed: () => openAsDialog(
          context, ItemEditScreen(tripId: tripId, item: item),
          width: 700),
    );
  }
}