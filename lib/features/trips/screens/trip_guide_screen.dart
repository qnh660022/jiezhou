/// 目的地攻略页（V2.6 任务5，§7.10）：仅非 Web（Web 不注册路由）。
/// 两段式加载（用户变更 2026-09-06）：先离线首屏（种子/缓存，零网络），
/// 再在线优先补全（open/crawl/aggregate）——离线六栏与在线精选同屏可读。
/// 多目的地（「成都-稻城」）按城 TabBar 分页，每城独立内容。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/guide/guide_models.dart';
import '../../../data/db/database.dart' show TripItem;
import '../../../data/guide/guide_providers.dart';
import '../../../data/guide/guide_service.dart' show GuideResult;
import '../../../data/providers.dart' show tripsRepoProvider;
import '../../../platform/open_external.dart';
import 'item_edit_screen.dart';

import '../../../shared/copy_tokens.dart';
import '../../../theme/tokens.dart';

class TripGuideScreen extends ConsumerStatefulWidget {
  const TripGuideScreen({super.key, required this.tripId, required this.destination});

  final String tripId;
  final String destination;

  @override
  ConsumerState<TripGuideScreen> createState() => _TripGuideScreenState();
}

class _TripGuideScreenState extends ConsumerState<TripGuideScreen> {
  /// 离线首屏结果（零网络，立即渲染）。
  List<GuideResult>? _offline;

  /// 完整结果（在线层完成后替换展示；在线内容置顶）。
  List<GuideResult>? _display;

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TripGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Builder 端 trip 异步加载：destination 从空串变为真实值后需重新拉取。
    if (widget.destination != oldWidget.destination) {
      _display = null;
      _offline = null;
      _load();
    }
  }

  Future<void> _load({bool force = false}) async {
    final svc = ref.read(guideServiceProvider);
    if (!force) {
      final off = await svc.getGuideMultiOffline(widget.destination);
      if (!mounted) return;
      setState(() => _offline = off);
    }
    final full =
        await svc.getGuideMulti(widget.destination, forceRefresh: force);
    if (!mounted) return;
    setState(() {
      _display = full;
      _refreshing = false;
    });
  }

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    await _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final results = _display ?? _offline;
    return Scaffold(
      appBar: AppBar(
        title: Text(copy('guide.title')),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _reload,
            icon: _refreshing
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            tooltip: '刷新在线内容',
          ),
        ],
      ),
      body: _buildBody(context, results),
    );
  }

  Widget _buildBody(BuildContext context, List<GuideResult>? results) {
    if (results == null) return _loadingList();
    if (results.isEmpty) {
      return _empty(context, copy('guide.badDestination'));
    }
    if (results.length == 1) {
      return RefreshIndicator(
          onRefresh: _reload, child: _CityGuideView(result: results.first, tripId: widget.tripId, onlineDone: _display != null));
    }
    // 多目的地：按城 TabBar 分页
    return DefaultTabController(
      length: results.length,
      child: Column(children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final r in results) Tab(text: r.location?.name ?? '')],
        ),
        Expanded(
          child: TabBarView(children: [
            for (final r in results)
              RefreshIndicator(
                  onRefresh: _reload,
                  child: _CityGuideView(result: r, tripId: widget.tripId, onlineDone: _display != null)),
          ]),
        ),
      ]),
    );
  }

  Widget _loadingList() => ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: Spacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Spacing.lg),
              ),
            ),
        ],
      );

  Widget _empty(BuildContext context, String message) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.explore_off_rounded,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: Spacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: Spacing.lg),
          FilledButton(onPressed: _reload, child: Text(copy('guide.retry'))),
        ]),
      );
}

/// 单城内容：徽标三态 + 在线区块置顶（精选文章 + 网络补充）+ 离线六栏。
class _CityGuideView extends StatelessWidget {
  const _CityGuideView({
    required this.result,
    required this.tripId,
    required this.onlineDone,
  });

  final GuideResult result;
  final String tripId;

  /// 完整阶段是否已完成（未完成且无种子时展示「正在获取网络攻略」）。
  final bool onlineDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = result.location;
    if (loc == null || result.failed != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        Text(result.failed ?? copy('guide.empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant)),
      ]);
    }
    final online = result.hasOnline;
    final badgeText = online
        ? (result.layersUsed.contains('seed') ? '种子+网络' : '在线')
        : '离线种子';
    final allEmpty = GuideCity.sectionKeys
        .every((k) => (result.sections[k] ?? const []).isEmpty);
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(children: [
          Expanded(
            child: Text(loc.name,
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          _badge(context, badgeText,
              highlight: online),
        ]),
        // 在线全败提示（明确告知离线兜底生效）
        if (result.onlineAttempted && !online) ...[
          const SizedBox(height: Spacing.sm),
          Row(children: [
            Icon(Icons.wifi_off_rounded,
                size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(
              child: Text('在线内容暂时不可用，已展示离线攻略',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: AppFontSizes.caption)),
            ),
          ]),
        ],
        if (allEmpty && !onlineDone) ...[
          const SizedBox(height: Spacing.xl),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: Spacing.sm),
          Text('正在获取网络攻略…',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: AppFontSizes.caption)),
        ],
        // ===== 在线区块（置顶） =====
        if (result.articles.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          Text('在线精选', style: Theme.of(context).textTheme.titleMedium),
          for (final a in result.articles)
            Card(
              margin: const EdgeInsets.only(top: Spacing.md),
              child: ListTile(
                title: Text(a['title'] as String? ?? ''),
                subtitle: Text(
                    '${a['source'] ?? ''} ${a['summary'] ?? ''}'.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppFontSizes.caption)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => _openArticle(a),
              ),
            ),
        ],
        if (result.onlineSections.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          Text('网络补充', style: Theme.of(context).textTheme.titleMedium),
          for (final entry in result.onlineSections.entries)
            if (entry.value.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: Spacing.md),
                child: Column(children: [
                  for (final item in entry.value)
                    ListTile(
                      dense: true,
                      leading: Icon(_iconOf(entry.key),
                          size: 18, color: scheme.primary),
                      title: Text(
                          (item['title'] ?? item['name'] ?? '').toString(),
                          style: const TextStyle(fontSize: AppFontSizes.body)),
                      subtitle: (item['detail'] ??
                                  item['note'] ??
                                  item['addr'] ??
                                  '')
                              .toString()
                              .isEmpty
                          ? null
                          : Text(
                              (item['detail'] ?? item['note'] ?? item['addr'] ?? '')
                                  .toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: AppFontSizes.caption)),
                      trailing: (item['sourceUrl'] as String?)?.isNotEmpty ?? false
                          ? const Icon(Icons.link_rounded, size: 16)
                          : null,
                      onTap: () {
                        final url = item['sourceUrl'] as String?;
                        if (url != null && url.isNotEmpty) openExternal(url);
                      },
                    ),
                ]),
              ),
        ],
        // ===== 离线六栏（种子打底；在线条目已在上方展示不重复） =====
        if (result.sectionMiss('prep') != null) ..._missRows(context, result),
        for (final key in GuideCity.sectionKeys) ...[
          const SizedBox(height: Spacing.lg),
          _SectionCard(
            sectionKey: key,
            items: (result.sections[key] ?? const [])
                .where((item) => item['source'] == null)
                .toList(),
            tripId: tripId,
            guideKey: loc.key,
          ),
        ],
        const SizedBox(height: Spacing.xl),
        Text(copy('guide.source'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: AppFontSizes.caption)),
        const SizedBox(height: Spacing.huge),
      ],
    );
  }

  IconData _iconOf(String sectionKey) => switch (sectionKey) {
        'prep' => Icons.wb_sunny_rounded,
        'spots' => Icons.photo_camera_rounded,
        'food' => Icons.restaurant_rounded,
        'transport' => Icons.directions_transit_rounded,
        'tips' => Icons.lightbulb_rounded,
        _ => Icons.payments_rounded,
      };

  List<Widget> _missRows(BuildContext context, GuideResult result) {
    final missing = GuideCity.sectionKeys
        .where((k) => (result.sections[k] ?? const []).isEmpty)
        .toList();
    if (missing.isEmpty) return const [];
    return [
      const SizedBox(height: Spacing.sm),
      Text(
          missing
              .map((k) => switch (k) {
                    'prep' => '行前准备',
                    'spots' => '景点',
                    'food' => '美食',
                    'transport' => '交通',
                    'tips' => '避坑',
                    _ => '预算',
                  })
              .join('、') +
              copy('guide.missSection'),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppFontSizes.caption)),
    ];
  }

  Widget _badge(BuildContext context, String text, {bool highlight = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 4),
        decoration: BoxDecoration(
          color: highlight
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: AppFontSizes.caption)),
      );

  void _openArticle(Map<String, dynamic> a) {
    final url = a['sourceUrl'] as String? ?? a['url'] as String? ?? '';
    if (url.isEmpty) return;
    // 文章默认外跳浏览器（§7.7）
    openExternal(url);
  }
}

/// 六栏折叠分节卡（默认全部展开）。
class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.sectionKey,
    required this.items,
    required this.tripId,
    required this.guideKey,
  });

  final String sectionKey;
  final List<Map<String, dynamic>> items;
  final String tripId;
  final String guideKey;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = true;

  String get _title => switch (widget.sectionKey) {
        'prep' => copy('guide.sectionPrep'),
        'spots' => copy('guide.sectionSpots'),
        'food' => copy('guide.sectionFood'),
        'transport' => copy('guide.sectionTransport'),
        'tips' => copy('guide.sectionTips'),
        _ => copy('guide.sectionBudget'),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: [
        ListTile(
          title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 20),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  left: Spacing.lg, right: Spacing.lg, bottom: Spacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(copy('guide.missSection'),
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: AppFontSizes.caption)),
              ),
            )
          else
            for (final item in widget.items)
              ListTile(
                dense: true,
                title: Text(
                    (item['title'] ?? item['name'] ?? '').toString(),
                    style: const TextStyle(fontSize: AppFontSizes.body)),
                subtitle: _subtitle(item),
                trailing: (widget.sectionKey == 'spots' ||
                        widget.sectionKey == 'food')
                    ? _addButton(item)
                    : null,
              ),
      ]),
    );
  }

  Widget? _subtitle(Map<String, dynamic> item) {
    final parts = <String>[
      item['addr'] as String? ?? item['area'] as String? ?? '',
      item['tag'] as String? ?? '',
      item['timeText'] as String? ?? '',
      item['note'] as String? ?? item['detail'] as String? ?? '',
      item['rangeText'] as String? ?? '',
      item['line'] as String? ?? '',
    ].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    // 离线种子 2.0：内容精品化后不截断，完整展示 detail 便于长文阅读。
    return Text(parts.join(' · '),
        style: const TextStyle(fontSize: AppFontSizes.caption, height: 1.35));
  }

  Widget? _addButton(Map<String, dynamic> item) {
    final name = (item['name'] ?? item['title'] ?? '').toString();
    if (name.isEmpty) return null;
    return Consumer(builder: (context, ref, _) {
      return FutureBuilder<int?>(
        future: _addedDay(name),
        builder: (context, snap) {
          final day = snap.data;
          if (day != null) {
            return Text('已加入 D${day + 1}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: AppFontSizes.caption));
          }
          return TextButton(
            onPressed: () => _addToPlan(name, item),
            child: Text(copy('guide.addPlan')),
          );
        },
      );
    });
  }

  /// 防重复记录：prefs['guide_added_<tripId>_<guideKey>_<name>'] = dateEpochDay。
  Future<int?> _addedDay(String name) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('guide_added_${widget.tripId}_${widget.guideKey}_$name');
  }

  Future<void> _addToPlan(String name, Map<String, dynamic> item) async {
    final sp = await SharedPreferences.getInstance();
    // 选日期 sheet：行程 startEpochDay..endEpochDay（§7.9）
    final day = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(child: _DayPicker(tripId: widget.tripId)),
    );
    if (day == null || !mounted) return;
    await sp.setInt(
        'guide_added_${widget.tripId}_${widget.guideKey}_$name', day);
    // 预填新建 TripItem（spot→attraction / food→food；cost 留空自填）
    final type = widget.sectionKey == 'food' ? 'food' : 'attraction';
    final rawNote = (item['note'] ?? item['detail'] ?? '').toString();
    final note = rawNote.isEmpty ? '来自攻略' : '$rawNote · 来自攻略';
    final now = DateTime.now().millisecondsSinceEpoch;
    final prefill = TripItem(
      id: 'guide_prefill',
      tripId: widget.tripId,
      dateEpochDay: day,
      type: type,
      name: name,
      address: (item['addr'] ?? '').toString(),
      fromName: '',
      fromAddress: '',
      toName: '',
      toAddress: '',
      sortOrder: 0,
      costCurrency: 'CNY',
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ItemEditScreen(tripId: widget.tripId, item: prefill, prefillNew: true),
    ));
    if (mounted) setState(() {});
  }
}

class _DayPicker extends ConsumerStatefulWidget {
  const _DayPicker({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_DayPicker> createState() => _DayPickerState();
}

class _DayPickerState extends ConsumerState<_DayPicker> {
  List<int>? _days;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trip = await ref.read(tripsRepoProvider).getById(widget.tripId);
    if (!mounted) return;
    if (trip == null) {
      setState(() => _days = []);
      return;
    }
    final days = <int>[];
    for (var d = trip.startEpochDay; d <= trip.endEpochDay; d++) {
      days.add(d);
    }
    setState(() => _days = days.isEmpty ? [trip.startEpochDay] : days);
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    return ListView(
      shrinkWrap: true,
      children: [
        const Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: Text('选择加入日期'),
        ),
        if (days == null)
          const Padding(
              padding: EdgeInsets.all(Spacing.xl),
              child: Center(child: CircularProgressIndicator()))
        else
          for (final d in days)
            ListTile(
              title: Text('D${d - (days.first) + 1} · ${_fmt(d)}'),
              onTap: () => Navigator.pop(context, d),
            ),
      ],
    );
  }

  String _fmt(int epochDay) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochDay * 86400000, isUtc: true);
    return '${dt.month}月${dt.day}日';
  }
}

/// 路由包装：由 tripId 解析 destination 后挂载攻略页。
class TripGuideScreenBuilder extends ConsumerWidget {
  const TripGuideScreenBuilder({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(tripsRepoProvider).getById(tripId),
      builder: (context, snap) {
        // trip 未加载完成前不挂载攻略页（避免以空目的地发起请求）。
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(copy('guide.title'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final dest = snap.data?.destination ?? '';
        return TripGuideScreen(tripId: tripId, destination: dest);
      },
    );
  }
}
