/// 目的地攻略页（V2.6 任务5 → 2026-09 UI 重设计 + 多入口 + 城市切换）。
///
/// ## 页面层次（用户反馈「很没有层次感」，这是本次重设计的核心）
/// ```
/// AppBar：标题 + 换城市/刷新
///   ├─ GuideCityHero      城市名 + 定位 + 统计（景点数/阅读时长/来源）
///   ├─ GuideSectionGrid   六栏速览宫格（点一格滚到对应栏目）
///   ├─ GuideSectionBody×6 栏目内容（按数据类型换渲染形态）
///   ├─ GuideArticleList   在线游记流（去哪儿城市页）
///   └─ 版权声明
/// ```
///
/// ## 数据来源（两段式：离线先出，在线后补）
/// 1. `getGuideMultiOffline*`（缓存/种子/AI 导入）零网络，立即渲染；
/// 2. `getGuideMulti*` 补在线层（open 事实 + 去哪儿城市页正文）后替换。
///
/// ## 入口（2026-09 从 1 个扩到 3 个）
/// - 行程详情「快捷操作」→ 带上 tripId（可「加入安排」）；
/// - 行程列表顶部卡片 / 我的-目的地攻略 → 只带城市 key（无 tripId）。
library;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/date_utils.dart';
import '../../../data/guide/guide_models.dart';
import '../../../data/db/database.dart' show Trip;
import '../../../data/guide/guide_providers.dart';
import '../../../data/guide/guide_service.dart' show GuideResult;
import '../../../data/providers.dart'
    show tripsRepoProvider, wishlistRepoProvider;
import '../../../domain/guide_ref.dart';
import '../../../features/ledger/ledger_models.dart' show TripCardView;
import '../../../features/ledger/ledger_providers.dart' show allTripsProvider;
import '../../../platform/open_external.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/tokens.dart';
import '../guide_city_picker.dart';
import '../guide_widgets.dart';

class TripGuideScreen extends ConsumerStatefulWidget {
  const TripGuideScreen({
    super.key,
    this.tripId,
    this.destination = '',
    this.cityKey,
    this.focusRef,
  });

  /// 行程入口才有；城市入口为 null。
  final String? tripId;

  /// 行程目的地（多城用「-」分隔）。
  final String destination;

  /// 城市入口直接给的 key。
  final String? cityKey;

  /// 深链定位（V2.7.2 S5）：行程卡「攻略」角标带来的 guideRef。
  /// 定位失败（城缺失/序号越界/条目被筛选隐藏）一律静默降级，仅到城页。
  final String? focusRef;

  @override
  ConsumerState<TripGuideScreen> createState() => _TripGuideScreenState();
}

class _TripGuideScreenState extends ConsumerState<TripGuideScreen> {
  /// 离线首屏结果（零网络，立即渲染）。
  List<GuideResult>? _offline;

  /// 完整结果（在线层完成后替换展示）。
  List<GuideResult>? _display;

  bool _refreshing = false;

  /// 当前城市 key 列表（城市入口时由选择器驱动；行程入口由 destination 归一化）。
  List<String> _cityKeys = const [];

  /// 各栏折叠状态（key = cityKey|sectionKey），跨会话记忆。
  Map<String, bool> _collapsed = {};

  /// 栏目锚点：宫格点击后滚动到对应栏目。
  final Map<String, GlobalKey> _sectionKeys = {};

  /// 全部可选城市（换城市选择器数据源）。
  List<GuideCityOption> _allCities = const [];

  /// 条目滚动锚点（V2.7.2 S5）：key = `cityKey|section|n:<名称>`。
  /// 行程卡「攻略」角标深链定位用，随条目构建惰性登记。
  final Map<String, GlobalKey> _itemKeys = {};

  /// 多城 TabBar 宿主（切城定位用）。
  final GlobalKey _tabHostKey = GlobalKey();

  /// 深链定位只尝试一次（刷新/换城不再触发）。
  bool _focusApplied = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
    _load();
  }

  @override
  void didUpdateWidget(covariant TripGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 行程入口：trip 异步加载后 destination 从空串变为真实值，需要重拉。
    if (widget.destination != oldWidget.destination ||
        widget.cityKey != oldWidget.cityKey) {
      _display = null;
      _offline = null;
      _load();
    }
  }

  Future<void> _loadCities() async {
    try {
      final list = await ref.read(guideServiceProvider).allCities();
      if (!mounted) return;
      setState(() => _allCities = list);
    } catch (_) {}
  }

  /// 当前要展示的城市 key 列表。
  Future<List<String>> _resolveKeys() async {
    final direct = widget.cityKey;
    if (direct != null && direct.isNotEmpty) return [direct];
    if (_cityKeys.isNotEmpty) return _cityKeys;
    return const [];
  }

  Future<void> _load({bool force = false}) async {
    final svc = ref.read(guideServiceProvider);
    final keys = await _resolveKeys();

    if (!force) {
      // 离线首屏
      final off = keys.isEmpty
          ? await svc.getGuideMultiOffline(widget.destination)
          : await svc.getGuideMultiOfflineByKeys(keys);
      if (!mounted) return;
      setState(() => _offline = off);
      await _loadCollapsedState(off);
    }

    final full = keys.isEmpty
        ? await svc.getGuideMulti(widget.destination, forceRefresh: force)
        : await svc.getGuideMultiByKeys(keys, forceRefresh: force);
    if (!mounted) return;
    setState(() {
      _display = full;
      _refreshing = false;
    });
    await _loadCollapsedState(full);
    await _applyFocus();
  }

  /// 「攻略」角标深链（V2.7.2 S5）：切到目标城 → 展开栏目 → 滚到条目。
  /// 任何一步失败都静默降级（城页/栏目页），不报错不阻断。
  Future<void> _applyFocus() async {
    final raw = widget.focusRef;
    if (_focusApplied || raw == null || raw.isEmpty) return;
    final results = _display ?? _offline;
    if (results == null || results.isEmpty) return;
    final parsed = GuideRef.tryParse(raw);
    _focusApplied = true; // 无论成败只尝试一次
    if (parsed == null) return;
    final cityIdx =
        results.indexWhere((r) => r.location?.key == parsed.cityKey);
    if (cityIdx < 0) return;
    final sectionId = '${parsed.cityKey}|${parsed.section}';

    // ① 下一帧：切城（多城 TabBar）→ 展开栏目 → 解析种子行名
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final host = _tabHostKey.currentContext;
      if (host != null && results.length > 1) {
        try {
          DefaultTabController.maybeOf(host)?.animateTo(cityIdx);
        } catch (_) {}
      }
      if (_collapsed[sectionId] == true) {
        setState(() => _collapsed[sectionId] = false);
        _persistCollapsed(parsed.cityKey);
      }
      // ② 解析种子行名（index → name），换算条目锚点
      String? name;
      try {
        final seed = await ref
            .read(guideServiceProvider)
            .seedSource
            .getSeed(parsed.cityKey);
        final rows =
            ((seed?['sections'] as Map?)?[parsed.section] as List?) ?? const [];
        if (parsed.index < rows.length) {
          name = ((rows[parsed.index] as Map)['name'] ?? '').toString();
        }
      } catch (_) {}
      final anchorId =
          name == null || name.isEmpty ? null : '$sectionId|n:$name';
      // ③ 再下一帧（展开布局已稳定）滚动
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final targetKey = (anchorId != null ? _itemKeys[anchorId] : null) ??
            _sectionKeys[sectionId];
        final ctx = targetKey?.currentContext;
        if (ctx == null) return; // 条目被筛选隐藏等：仅到城页
        try {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.06,
          );
        } catch (_) {}
      });
    });
  }

  /// 读该城的折叠/展开记忆（默认全部展开）。
  Future<void> _loadCollapsedState(List<GuideResult> results) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final next = <String, bool>{};
      for (final r in results) {
        final key = r.location?.key;
        if (key == null) continue;
        final raw = sp.getString('guide_view_collapsed_$key');
        if (raw == null) continue;
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        m.forEach((k, v) => next['$key|$k'] = v == true);
      }
      if (!mounted) return;
      setState(() => _collapsed = {..._collapsed, ...next});
    } catch (_) {}
  }

  Future<void> _persistCollapsed(String cityKey) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final mine = <String, bool>{};
      for (final k in GuideCity.sectionKeys) {
        final v = _collapsed['$cityKey|$k'];
        if (v != null) mine[k] = v;
      }
      await sp.setString('guide_view_collapsed_$cityKey', jsonEncode(mine));
    } catch (_) {}
  }

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    await _load(force: true);
  }

  /// 换城市：选择器返回 key；多城时作为新 Tab 追加。
  Future<void> _pickCity({bool append = false}) async {
    final picked = await showGuideCityPicker(
      context: context,
      cities: _allCities,
      currentKey: _display?.isNotEmpty == true
          ? _display!.first.location?.key
          : widget.cityKey,
    );
    if (picked == null || !mounted) return;
    final current = await _resolveKeys();
    if (append) {
      if (current.contains(picked)) return;
      setState(() => _cityKeys = [...current, picked]);
    } else {
      setState(() {
        _cityKeys = [picked];
        _display = null;
        _offline = null;
      });
    }
    await _load();
  }

  Future<void> _clearAiContent(String cityKey) async {
    // V2.8.2 S6：AlertDialog → 统一 L2 确认抽屉（中性确认）
    final ok = await showConfirmSheet(
      context: context,
      title: copy('guide.clearAiConfirm'),
      body: copy('guide.clearAiConfirmBody'),
      confirmLabel: copy('guide.clearAi'),
      cancelLabel: copy('guide.cancel'),
    );
    if (!ok || !mounted) return;
    await ref.read(guideServiceProvider).clearCityOverride(cityKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy('guide.clearAiDone'))));
    setState(() {
      _display = null;
      _offline = null;
    });
    await _load(force: true);
  }

  /// 宫格点击 → 滚到对应栏目。
  ///
  /// ## 为什么先展开、再「下一帧」滚动（2026-09-12 修 bug：内容一多就跳不动）
  /// 1. 目标栏目若处于折叠态，先展开 —— 展开会改变整页布局，先滚再展开
  ///    等于拿旧布局算出来的位移去滚，落点是错的；
  /// 2. `Scrollable.ensureVisible` 依赖目标 RenderObject **已经被 layout**：
  ///    一旦目标在视口外从未被布局过（内容一长必然如此），
  ///    `RenderViewport.getOffsetToReveal` 里 `childScrollOffset(child)!`
  ///    会拿到 null 并抛出空断言异常，跳转被静默吞掉（页面毫无反应）。
  ///    配合 `_CityGuideView` 改成「整体一次布局」的滚动容器（见下方注释），
  ///    目标永远已布局，再叠一层 `addPostFrameCallback` 保证顺序正确。
  void _jumpToSection(String cityKey, String sectionKey) {
    final id = '$cityKey|$sectionKey';
    // ① 折叠着就先展开
    if (_collapsed[id] == true) {
      setState(() => _collapsed[id] = false);
      _persistCollapsed(cityKey);
    }
    // ② 下一帧（布局已按展开后的形态更新）再滚动
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx == null) return;
      try {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.06,
        );
      } catch (_) {
        // 极端情况（目标被卸载 / 滚动容器已 dispose）：静默放弃，不弹红屏。
      }
    });
  }

  Widget _sectionAnchor(String cityKey, String sectionKey, Widget child) {
    final key = _sectionKeys.putIfAbsent(
        '$cityKey|$sectionKey', () => GlobalKey());
    return KeyedSubtree(key: key, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final results = _display ?? _offline;
    final showTabs = (results?.length ?? 0) > 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(copy('guide.title')),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _reload,
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            tooltip: '刷新在线内容',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              final key = results?.isNotEmpty == true
                  ? results!.first.location?.key
                  : widget.cityKey;
              if (v == 'clear-ai' && key != null) _clearAiContent(key);
              if (v == 'pick') _pickCity();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'pick', child: Text(copy('guide.switchCity'))),
              if (results?.isNotEmpty == true && results!.first.isAiImported)
                PopupMenuItem(
                    value: 'clear-ai', child: Text(copy('guide.clearAi'))),
            ],
          ),
        ],
      ),
      body: _buildBody(context, results, showTabs),
    );
  }

  Widget _buildBody(
      BuildContext context, List<GuideResult>? results, bool showTabs) {
    if (results == null) return _loadingList();
    if (results.isEmpty) {
      return _emptyState(context, copy('guide.badDestination'));
    }
    if (!showTabs) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: _CityGuideView(
          result: results.first,
          tripId: widget.tripId,
          onlineDone: _display != null,
          collapsed: _collapsed,
          onToggleSection: (sk) {
            final cityKey = results.first.location?.key ?? '';
            setState(() =>
                _collapsed['$cityKey|$sk'] = !(_collapsed['$cityKey|$sk'] ?? false));
            _persistCollapsed(cityKey);
          },
          onJumpSection: (sk) =>
              _jumpToSection(results.first.location?.key ?? '', sk),
          sectionAnchor: (sk, child) =>
              _sectionAnchor(results.first.location?.key ?? '', sk, child),
          itemAnchorKey: (sk, item) {
            final cityKey = results.first.location?.key ?? '';
            final name =
                (item['name'] ?? item['title'] ?? '').toString();
            if (name.isEmpty) return null;
            return _itemKeys.putIfAbsent(
                '$cityKey|$sk|n:$name', () => GlobalKey());
          },
          onClearAi: results.first.isAiImported
              ? () => _clearAiContent(results.first.location?.key ?? '')
              : null,
        ),
      );
    }
    return KeyedSubtree(
    key: _tabHostKey,
    child: DefaultTabController(
      length: results.length,
      child: Column(children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final r in results) Tab(text: r.location?.name ?? ''),
            Tab(
              icon: const Icon(Icons.add_rounded, size: 18),
              text: copy('guide.addCity'),
            ),
          ],
          onTap: (i) {
            if (i == results.length) _pickCity(append: true);
          },
        ),
        Expanded(
          child: TabBarView(children: [
            for (final r in results)
              RefreshIndicator(
                onRefresh: _reload,
                child: _CityGuideView(
                  result: r,
                  tripId: widget.tripId,
                  onlineDone: _display != null,
                  collapsed: _collapsed,
                  onToggleSection: (sk) {
                    final cityKey = r.location?.key ?? '';
                    setState(() => _collapsed['$cityKey|$sk'] =
                        !(_collapsed['$cityKey|$sk'] ?? false));
                    _persistCollapsed(cityKey);
                  },
                  onJumpSection: (sk) => _jumpToSection(r.location?.key ?? '', sk),
                  sectionAnchor: (sk, child) =>
                      _sectionAnchor(r.location?.key ?? '', sk, child),
                  itemAnchorKey: (sk, item) {
                    final cityKey = r.location?.key ?? '';
                    final name =
                        (item['name'] ?? item['title'] ?? '').toString();
                    if (name.isEmpty) return null;
                    return _itemKeys.putIfAbsent(
                        '$cityKey|$sk|n:$name', () => GlobalKey());
                  },
                  onClearAi: r.isAiImported
                      ? () => _clearAiContent(r.location?.key ?? '')
                      : null,
                ),
              ),
          ]),
        ),
      ]),
    ),
    );
  }

  Widget _loadingList() => ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              height: i == 0 ? 120 : 72,
              margin: const EdgeInsets.only(bottom: Spacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Spacing.lg),
              ),
            ),
        ],
      );

  Widget _emptyState(BuildContext context, String message) => EmptyState(
        icon: AppIcons.compass,
        title: copy('guide.noCityPicked'),
        message: message,
        actionLabel: copy('guide.pickCity'),
        onAction: () => _pickCity(),
      );
}

/// 单城内容：城市头 + 六栏宫格 + 六个栏目 + 在线游记 + 声明。
class _CityGuideView extends StatelessWidget {
  const _CityGuideView({
    required this.result,
    required this.tripId,
    required this.onlineDone,
    required this.collapsed,
    required this.onToggleSection,
    required this.onJumpSection,
    required this.sectionAnchor,
    this.itemAnchorKey,
    this.onClearAi,
  });

  final GuideResult result;

  /// null = 无行程上下文（城市入口），动作需先选行程。
  final String? tripId;

  /// 完整阶段是否已完成（未完成且无种子时展示「正在获取网络攻略」）。
  final bool onlineDone;
  final Map<String, bool> collapsed;
  final void Function(String sectionKey) onToggleSection;
  final void Function(String sectionKey) onJumpSection;

  /// 给每个栏目挂一个滚动锚点（宫格点击用）。
  ///
  /// 接一个 child 并包上 `KeyedSubtree`：锚点必须是**真实被渲染的那棵树**，
  /// 否则 `Scrollable.ensureVisible` 找不到上下文（早前版本只挂了个空
  /// SizedBox 占位，点击宫格无反应）。
  final Widget Function(String sectionKey, Widget child) sectionAnchor;

  /// 条目滚动锚点 key（行程卡「攻略」角标深链定位用）；null 表示不需要。
  final Key? Function(String sectionKey, Map<String, dynamic> item)?
      itemAnchorKey;
  final VoidCallback? onClearAi;

  String get _cityKey => result.location?.key ?? '';

  bool _isCollapsed(String sectionKey) =>
      collapsed['$_cityKey|$sectionKey'] ?? false;

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

    final allEmpty = GuideCity.sectionKeys
        .every((k) => (result.sections[k] ?? const []).isEmpty);
    final articleCount = result.articles.length;
    final spotCount = (result.sections['spots'] ?? const []).length +
        (result.sections['food'] ?? const []).length;

    // 滚动容器：**SingleChildScrollView + Column，而不是 ListView。**
    //
    // 这是「内容一多，宫格跳转就失效」的根因修复（2026-09-12）：
    // ListView（哪怕用 `children:` 一次性建完 widget）在渲染层仍是懒布局的，
    // 视口外的子项从未 layout，`Scrollable.ensureVisible` 通过
    // `RenderViewport.getOffsetToReveal` 取位移时会拿到
    // `childScrollOffset(child) == null`，空断言抛异常 → 跳转静默失败。
    // 改成 Column 后整棵子树每帧都被 layout（绘制仍被视口裁剪，不会额外耗
    // 绘制开销），`ensureVisible` 对任意长度的攻略都能算准落点。
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Spacing.huge),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- 1. 城市头 ----------
          GuideCityHero(
            cityName: loc.name,
            spots: spotCount,
            textChars: result.textChars,
            readingMinutes: result.readingMinutes,
            sourceLabel: _sourceLabel(),
            lead: _lead(),
          ),
          // AI 导入提示条（黄色语义，提醒内容来源与时效性）
          if (result.isAiImported)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.md, Spacing.xl, 0),
              child: Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: SemanticColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.input,
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: SemanticColors.warning),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(copy('guide.aiImportedTitle'),
                            style: const TextStyle(
                                fontSize: AppFontSizes.caption,
                                fontWeight: FontWeight.w700)),
                        Text(copy('guide.aiImportedNote'),
                            style: TextStyle(
                                fontSize: AppFontSizes.caption - 1,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (onClearAi != null)
                    TextButton(
                        onPressed: onClearAi,
                        child: Text(copy('guide.clearAi'))),
                ]),
              ),
            ),
          // 在线全败提示
          if (result.onlineAttempted && !result.hasOnline) ...[
            const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: Row(children: [
                Icon(Icons.wifi_off_rounded,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(copy('guide.onlineFail'),
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: AppFontSizes.caption)),
                ),
              ]),
            ),
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

          // ---------- 2. 六栏速览宫格 ----------
          if (!allEmpty) ...[
            const SizedBox(height: Spacing.sm),
            GuideSectionGrid(
              sections: result.sections,
              onTap: onJumpSection,
            ),
          ],

          // ---------- 3. 六个栏目 ----------
          for (final key in GuideCity.sectionKeys)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.lg),
              child: sectionAnchor(
                key,
                // 栏目外边距放在锚点内侧，否则滚动定位会把 16px 间距算进去
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                  child: GuideSectionBody(
                    sectionKey: key,
                    items: (result.sections[key] ?? const [])
                        // 在线条目不在这里重复（它们在栏目里以「来自」标注展示）
                        .toList(),
                    expanded: !_isCollapsed(key),
                    onToggle: () => onToggleSection(key),
                    itemActionBuilder: (item) => _addAction(context, key, item),
                    itemAnchorKey: (item) => itemAnchorKey?.call(key, item),
                  ),
                ),
              ),
            ),

          // ---------- 4. 在线游记流 ----------
          if (articleCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.lg),
              child: GuideArticleList(
                articles: result.articles,
                onOpen: _openArticle,
              ),
            ),

          // ---------- 5. 声明 ----------
          const SizedBox(height: Spacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Text(copy('guide.source'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: AppFontSizes.caption)),
          ),
        ],
      ),
    );
  }

  /// 数据来源标签（AI 导入 > 在线抓取 > 内置种子）。
  String _sourceLabel() {
    if (result.isAiImported) return copy('guide.sourceAi');
    if (result.hasCrawledGuide) return copy('guide.sourceNetwork');
    return copy('guide.sourceBuiltin');
  }

  /// 一句话定位：优先「城市概述」，其次首条内容。
  String? _lead() {
    for (final it in result.sections['prep'] ?? const []) {
      final t = (it['title'] ?? '').toString();
      if (t.contains('概述') || t.contains('定位')) {
        return (it['detail'] ?? '').toString();
      }
    }
    final first = (result.sections['prep'] ?? const []).firstOrNull;
    return first == null ? null : (first['detail'] ?? '').toString();
  }

  /// 条目双动作（V2.7.2 S5 §8.3）：有且仅有「直接排」「先想去」两个动词。
  /// 仅 spots/food 提供且条目必须存在于种子（guideRef 需要稳定下标）；
  /// 在线补充条目无稳定 ref，不提供动作（静默降级，偏差已登记）。
  Widget? _addAction(
      BuildContext context, String sectionKey, Map<String, dynamic> item) {
    if (!GuideRef.knownSections.contains(sectionKey)) return null;
    final name = (item['name'] ?? item['title'] ?? '').toString();
    if (name.isEmpty) return null;
    return _GuideEntryActions(
      tripId: tripId,
      cityKey: _cityKey,
      sectionKey: sectionKey,
      item: item,
    );
  }

  void _openArticle(Map<String, dynamic> a) {
    final url = a['sourceUrl'] as String? ?? a['url'] as String? ?? '';
    if (url.isEmpty) return;
    openExternal(url);
  }
}

// ---------------------------------------------------------------------------
// 条目双动作（直接排 / 先想去）
// ---------------------------------------------------------------------------

class _GuideEntryActions extends ConsumerStatefulWidget {
  const _GuideEntryActions({
    required this.tripId,
    required this.cityKey,
    required this.sectionKey,
    required this.item,
  });

  final String? tripId;
  final String cityKey;
  final String sectionKey;
  final Map<String, dynamic> item;

  @override
  ConsumerState<_GuideEntryActions> createState() =>
      _GuideEntryActionsState();
}

class _GuideEntryActionsState extends ConsumerState<_GuideEntryActions> {
  /// 城市入口选中的行程（选择后记住，刷新动作区）。
  String? _pickedTripId;
  bool _busy = false;

  String get _name =>
      (widget.item['name'] ?? widget.item['title'] ?? '').toString();

  /// 种子下标 → guideRef；条目不在种子中（在线补充）→ null。
  GuideRef? _refOf(Map<String, Map<String, int>>? seedIndex) {
    final idx = seedIndex?[widget.sectionKey]?[_name];
    if (idx == null) return null;
    return GuideRef(
        cityKey: widget.cityKey, section: widget.sectionKey, index: idx);
  }

  /// §8.3 字段映射：spots→attraction / food→food。
  String get _type => widget.sectionKey == 'food' ? 'food' : 'attraction';

  /// §8.3 字段映射：spots→addr / food→area（food 无 addr）；不复制 note 长文。
  String get _address =>
      (widget.item['addr'] ?? widget.item['area'] ?? '').toString();

  /// T1 映射（附录 T1）；未登记的 timeText → null（未估时）。
  int? get _duration =>
      guideDurationFromTimeText((widget.item['timeText'] ?? '').toString());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tid = _pickedTripId ?? widget.tripId;
    final seedIndex =
        ref.watch(guideSeedNameIndexProvider(widget.cityKey)).valueOrNull;
    final guideRef = _refOf(seedIndex);
    // 在线补充条目 / 种子索引未就绪：不渲染动作（静默降级）
    if (guideRef == null) return const SizedBox.shrink();

    if (tid == null || tid.isEmpty) {
      return _actions(context, scheme, null, guideRef, false);
    }
    final link = ref.watch(guideLinkProvider(tid)).valueOrNull;
    final days = link?.daysFor(guideRef.format()) ?? const <int>[];
    if (days.isNotEmpty) {
      // V2.8.2 S4：状态徽记 —— primary 实底白字胶囊 + 日历 icon
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.calendar, size: 12, color: scheme.onPrimary),
            const SizedBox(width: 4),
            Text(
              '已安排 · 第 ${days.join('、')} 天',
              style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      );
    }
    return _actions(
        context, scheme, tid, guideRef, link?.isWishlisted(guideRef.format()) ?? false);
  }

  /// V2.8.2 S4：双动作主次化 —— 「直接排」Filled 小号 36 高（calendar icon）
  /// +「先想去」Outlined（bookmark icon），间距 8。
  /// 已安排/已在想去态的隐藏逻辑不动（guideRef 参数逐字段不改）。
  Widget _actions(BuildContext context, ColorScheme scheme, String? tid,
      GuideRef guideRef, bool wished) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : () => _onPlace(guideRef),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: TextStyle(
                fontSize: AppFontSizes.caption, fontWeight: FontWeight.w700),
          ),
          icon: const Icon(AppIcons.calendar, size: 14),
          label: const Text('直接排'),
        ),
        const SizedBox(width: Spacing.sm),
        if (wished)
          // V2.8.2 S4：「已在想去」outline 胶囊 + bookmark icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.bookmark,
                    size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('已在想去',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _onWish(guideRef),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: TextStyle(
                  fontSize: AppFontSizes.caption, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(AppIcons.bookmark, size: 14),
            label: const Text('先想去'),
          ),
      ],
    );
  }

  /// 城市入口：先选行程（沿用既有「挑行程」抽屉交互）。
  Future<String?> _ensureTripId() async {
    final current = _pickedTripId ?? widget.tripId;
    if (current != null && current.isNotEmpty) return current;
    final trips = ref.read(allTripsProvider).value ?? const <TripCardView>[];
    if (!mounted) return null;
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还没有行程，先创建一个行程再来安排')));
      return null;
    }
    final picked = await showDraggableSheet<String>(
      context: context,
      initialChildSize: 0.5,
      builder: (ctx, _) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Text('把「$_name」加到哪个行程？'),
          ),
          for (final t in trips)
            ListTile(
              leading: Text(t.emoji, style: const TextStyle(fontSize: 22)),
              title: Text(t.name),
              subtitle: t.destination.isEmpty
                  ? null
                  : Text(t.destination,
                      style: const TextStyle(fontSize: AppFontSizes.caption)),
              onTap: () => Navigator.pop(ctx, t.id),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return null;
    setState(() => _pickedTripId = picked);
    return picked;
  }

  /// 「直接排」：选天 + 可选时段 → 同 guideRef 同日去重确认 → 建正式卡。
  Future<void> _onPlace(GuideRef guideRef) async {
    final tid = await _ensureTripId();
    if (tid == null || !mounted) return;
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _GuidePlaceSheet(tripId: tid),
    );
    if (picked == null || !mounted) return;
    final (day, slot) = picked;
    // §8.3 去重：同 guideRef 同日已存在 → 确认弹层（跨天不去重）
    final sameDay = await ref
        .read(tripsRepoProvider)
        .findByGuideRefPrefix(tid, guideRef.prefix());
    if (sameDay.any((it) => it.dateEpochDay == day) && mounted) {
      // V2.8.2 S6：AlertDialog → 统一 L2 确认抽屉（中性确认）
      final ok = await showConfirmSheet(
        context: context,
        title: '该条目已安排在此日',
        body: '同一天已有这条攻略的安排，仍要再添加一条吗？',
        confirmLabel: '仍要添加',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(tripsRepoProvider).addItemWithGuideRef(
            tripId: tid,
            dateEpochDay: day,
            name: _name,
            type: _type,
            guideRef: guideRef.format(),
            address: _address,
            durationMin: _duration,
            startTimeMin: slot <= 0 ? null : slot,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('已排入第 $day 天')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 「先想去」：入想去池（S6 面板展示；落卡即移出）。
  Future<void> _onWish(GuideRef guideRef) async {
    final tid = await _ensureTripId();
    if (tid == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final tag = (widget.item['tag'] ?? '').toString();
      await ref.read(wishlistRepoProvider).addItem(
            tripId: tid,
            cityKey: widget.cityKey,
            name: _name,
            address: _address,
            type: _type,
            durationMin: _duration,
            tag: tag.isEmpty ? null : tag,
            guideRef: guideRef.format(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已加入想去')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// 「直接排」选天 + 可选时段弹层（§8.3）。
/// V2.8.2 S4：天序列表 → 天卡网格（D1–Dn：天数+日期+星期+当天安排数 badge，
/// 3 列）；二级时段弹层视觉统一为 chips 行。
class _GuidePlaceSheet extends ConsumerStatefulWidget {
  const _GuidePlaceSheet({required this.tripId});

  final String tripId;

  @override
  ConsumerState<_GuidePlaceSheet> createState() => _GuidePlaceSheetState();
}

class _GuidePlaceSheetState extends ConsumerState<_GuidePlaceSheet> {
  Trip? _trip;

  /// 各天安排数（key = epochDay）。
  Map<int, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(tripsRepoProvider);
    final trip = await repo.getById(widget.tripId);
    final items = await repo.watchItems(widget.tripId).first;
    if (!mounted) return;
    setState(() {
      _trip = trip;
      _counts = {
        for (final it in items)
          it.dateEpochDay: (_counts[it.dateEpochDay] ?? 0) + 1,
      };
    });
  }

  Future<void> _pickDay(int day) async {
    final slot = await _slotPicker();
    if (!mounted) return;
    Navigator.pop(context, (day, slot));
  }

  /// 可选时段：0 = 不指定。V2.8.2 S4：ListTile 列表 → chips 行。
  Future<int> _slotPicker() {
    const presets = [540, 720, 900, 1080];
    return showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: SheetSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择时段（可留空）',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    _SlotChip(
                        label: '不指定',
                        onTap: () => Navigator.pop(ctx, 0)),
                    for (final m in presets)
                      _SlotChip(
                        label: _fmtSlot(m),
                        onTap: () => Navigator.pop(ctx, m),
                      ),
                    _SlotChip(
                      label: '自定义…',
                      icon: Icons.edit_outlined,
                      onTap: () async {
                        final t = await showTimePicker(
                            context: ctx,
                            initialTime:
                                const TimeOfDay(hour: 9, minute: 0));
                        if (t != null && ctx.mounted) {
                          Navigator.pop(ctx, t.hour * 60 + t.minute);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((v) => v ?? 0);
  }

  String _fmtSlot(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    if (trip == null) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }
    final n = trip.endEpochDay - trip.startEpochDay + 1;
    if (n < 1) {
      return const SizedBox(
          height: 120,
          child: Center(child: Text('该行程还没有日期，先去编辑行程设置日期')));
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, Spacing.md, Spacing.lg, Spacing.xs),
            child: Text('排到哪一天？',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          // V2.8.2 S4：天卡网格（3 列，D1–Dn）
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.xs, Spacing.lg, Spacing.xl),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: Spacing.sm,
                mainAxisSpacing: Spacing.sm,
                childAspectRatio: 1.0,
              ),
              itemCount: n,
              itemBuilder: (context, i) {
                final day = trip.startEpochDay + i;
                return _DayCard(
                  index: i + 1,
                  epochDay: day,
                  planCount: _counts[day] ?? 0,
                  onTap: () => _pickDay(day),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 天卡：D 序 + 日期 + 星期 + 当天安排数 badge（3 列网格）。
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.index,
    required this.epochDay,
    required this.planCount,
    required this.onTap,
  });

  final int index;
  final int epochDay;
  final int planCount;
  final VoidCallback onTap;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = epochDayToDate(epochDay);
    final weekday = _weekdays[date.weekday - 1];
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
      borderRadius: AppRadius.input,
      child: InkWell(
        borderRadius: AppRadius.input,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.input,
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('D$index',
                  style: TextStyle(
                      fontSize: AppFontSizes.title,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary)),
              const SizedBox(height: 2),
              Text('${date.month}/${date.day} · 周$weekday',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption - 1,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: Spacing.xs),
              if (planCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$planCount 个安排',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption - 2,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary)),
                )
              else
                Text('暂无安排',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption - 2,
                        color: scheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 时段 chip（S4 二级弹层视觉统一）。
class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: scheme.primary),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 路由包装（行程入口）：由 tripId 解析 destination 后挂载攻略页。
class TripGuideScreenBuilder extends ConsumerWidget {
  const TripGuideScreenBuilder({super.key, required this.tripId, this.focusRef});

  final String tripId;

  /// 深链定位（V2.7.2 S5）：透传给攻略页。
  final String? focusRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(tripsRepoProvider).getById(tripId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(copy('guide.title'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final dest = snap.data?.destination ?? '';
        return TripGuideScreen(
            tripId: tripId, destination: dest, focusRef: focusRef);
      },
    );
  }
}
