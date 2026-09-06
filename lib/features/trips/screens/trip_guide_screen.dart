/// 目的地攻略页（V2.6 任务5，§7.10）：仅 Android（Web 不注册路由）。
/// 六栏折叠分节卡 + 精选文章流 + 底部声明 + 一键加入安排（§7.9）。
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
  late Future<GuideResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(guideServiceProvider).getGuide(widget.destination);
  }

  @override
  void didUpdateWidget(covariant TripGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Builder 端 trip 异步加载：destination 从空串变为真实值后需重新拉取。
    if (widget.destination != oldWidget.destination) {
      _future = ref.read(guideServiceProvider).getGuide(widget.destination);
    }
  }

  void _reload() {
    setState(() {
      _future = ref
          .read(guideServiceProvider)
          .getGuide(widget.destination, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(copy('guide.title'))),
      body: FutureBuilder<GuideResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    height: 72,
                    margin: const EdgeInsets.only(bottom: Spacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(Spacing.lg),
                    ),
                  ),
              ],
            );
          }
          final result = snap.data;
          if (result == null || result.failed != null) {
            return _empty(context, result?.failed ?? copy('guide.empty'));
          }
          final loc = result.location!;
          final offline = result.cached ||
              result.layersUsed.contains('seed') &&
                  !result.layersUsed.contains('aggregate');
          return ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              Row(children: [
                Expanded(
                  child: Text(loc.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                _badge(context,
                    offline ? copy('guide.badgeOffline') : copy('guide.badgeNetwork')),
              ]),
              if (result.sectionMiss('prep') != null) ..._missRows(result),
              for (final key in GuideCity.sectionKeys) ...[
                const SizedBox(height: Spacing.lg),
                _SectionCard(
                  sectionKey: key,
                  items: result.sections[key] ?? const [],
                  tripId: widget.tripId,
                  guideKey: loc.key,
                ),
              ],
              if (result.articles.isNotEmpty) ...[
                const SizedBox(height: Spacing.lg),
                Text(copy('guide.article'),
                    style: Theme.of(context).textTheme.titleMedium),
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
              const SizedBox(height: Spacing.xl),
              Text(copy('guide.source'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: AppFontSizes.caption)),
              const SizedBox(height: Spacing.huge),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _missRows(GuideResult result) {
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

  Widget _badge(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: AppFontSizes.caption)),
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
    return Text(parts.join(' · '),
        style: const TextStyle(fontSize: AppFontSizes.caption),
        maxLines: 2,
        overflow: TextOverflow.ellipsis);
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
