// 全屏「今日驾驶舱」（V2.6.6.2 §8.3 主体 + §8.4 视觉规格 / D2）。
//
// 结构（自上而下）：
//   ① 页顶「第 N 天进度带」：一行天数 + 当地日期时间胶囊（时差角标）+ 全宽 4px 进度条
//      （**全页唯一渐变**：主题色两档明度）；
//   ② 今日花销主卡：大数字 + 预算余量小环（三态色）；
//   ③ 今日安排次卡：已完成/共 N 分数式大字 + 主题色纯色细进度条；
//   ④ 今日备注卡：多行便签，即时存本地（不上云）；
//   ⑤ 底部快捷区：「记一笔」主按钮（bottomNavigationBar 固定，不与内容争滚动）。
//
// 入场动效：首帧卡片 stagger 淡入 + 12px 上移归位，单卡 250ms、总时长 700ms，
// 只做 transform/opacity；`MediaQuery.disableAnimations`（prefers-reduced-motion）
// 为真时直接呈现，且同一行程二次进入不重放（todayLocalStore.cockpitEntered）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../shared/widgets/collab_polling_scope.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../theme/tokens.dart';
import '../today_local_store.dart';
import '../today_providers.dart';
import '../today_scope.dart';
import '../widgets/money_hero_text.dart';
import '../widgets/today_surface.dart';
import '../../../theme/app_icons.dart';

/// 今日驾驶舱：全屏页，路由 `/today/:tripId`。
class TodayCockpitScreen extends ConsumerStatefulWidget {
  const TodayCockpitScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TodayCockpitScreen> createState() =>
      _TodayCockpitScreenState();
}

class _TodayCockpitScreenState extends ConsumerState<TodayCockpitScreen> {
  /// 是否播放入场动效（进入前已在 initState 判定：非首次进入不重放）。
  bool _seenBefore = true;

  @override
  void initState() {
    super.initState();
    // 页面进入时预取一次本地状态（同步 SharedPreferences 读）。
    final store = ref.read(todayLocalStoreProvider);
    _seenBefore = store.cockpitEntered(widget.tripId);
    if (!_seenBefore) {
      // 一次性标记：下次进同一行程不再重放动效（写盘失败不影响首帧）。
      store.markCockpitEntered(widget.tripId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scope = ref.watch(todayScopeProvider(widget.tripId));
    final tripLink = ref.watch(tripSpansWithGroupProvider).value?[widget.tripId];
    final tripName = tripLink?.name ?? '今日';
    // V2.9.0:上游行程关联的账本 id——「记一笔」跳转带上,落库不再落到全局激活账本。
    final groupId = tripLink?.groupId;

    if (scope == null) {
      return Scaffold(
        appBar: GlassAppBar(title: tripName),
        body: const EmptyState(
          icon: AppIcons.compass,
          title: '行程不存在或已删除',
          message: '回到行程列表重新看看',
        ),
      );
    }

    // prefers-reduced-motion：为真时直接呈现，不播动效（§8.4 第 3 条）。
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate = !reducedMotion && !_seenBefore;

    final day = scope.tripTodayEpochDay;
    final rawItems =
        ref.watch(todayItemRecordsProvider((widget.tripId, day))).value ??
            const <TripItem>[];
    final items = todayItemsByDay<TripItem>(
      rawItems,
      day,
      (i) => i.dateEpochDay,
      (i) => i.startTimeMin,
      sortOrderOf: (i) => i.sortOrder,
    );
    final doneIds = ref.watch(todayDoneIdsProvider((widget.tripId, day)));
    final doneCount = items.where((i) => doneIds.contains(i.id)).length;
    final spend = ref.watch(todaySpendProvider((widget.tripId, day)));

    return CollabPollingScope(
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: GlassAppBar(title: tripName),
        body: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        children: [
          _EnterStagger(
            index: 0,
            enabled: animate,
            child: _DayProgressBand(scope: scope),
          ),
          _EnterStagger(
            index: 1,
            enabled: animate,
            child: _SpendSummaryCard(
              tripId: widget.tripId,
              summary: spend,
            ),
          ),
          _EnterStagger(
            index: 2,
            enabled: animate,
            child: _PlanSummaryCard(
              tripId: widget.tripId,
              doneCount: doneCount,
              totalCount: items.length,
            ),
          ),
          _EnterStagger(
            index: 3,
            enabled: animate,
            child: _TodayNoteCard(
              key: ValueKey<String>('today-note-${widget.tripId}-$day'),
              tripId: widget.tripId,
              epochDay: day,
            ),
          ),
        ],
      ),
        // 底部快捷区：固定占位，不参与内容滚动。
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.xl, Spacing.sm, Spacing.xl, Spacing.md),
            child: PrimaryButton(
              label: '记一笔',
              icon: Icons.edit_note_rounded,
              expanded: true,
              // 记账页带当日日期（epochDay），保存后回驾驶舱。
              // V2.9.0:再带上游行程关联的 groupId,避免落库取全局激活账本记错本;
              // groupId 为空时不带该参数(记账页参数支持由并行改动实现)。
              onPressed: () => context.push(groupId == null || groupId.isEmpty
                  ? '/expenses/edit?date=$day'
                  : '/expenses/edit?date=$day&groupId=$groupId'),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ① 页顶第 N 天进度带
// ---------------------------------------------------------------------------

class _DayProgressBand extends StatelessWidget {
  const _DayProgressBand({required this.scope});

  final TodayScope scope;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final local = scope.localNow;
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.lg, Spacing.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '第 ${scope.dayIndex} 天 · 共 ${scope.totalDays} 天',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSizes.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              // 当地日期时间胶囊 + 时差角标
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.brightness == Brightness.dark
                      ? scheme.surfaceContainerHigh
                      : scheme.surfaceContainerLow,
                  borderRadius: AppRadius.capsule,
                  border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${local.month}月${local.day}日 $time',
                      style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.onSurface,
                        fontFeatures: AppTextStyles.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: AppRadius.capsule,
                      ),
                      child: Text(
                        scope.offsetLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // 行程进度条：全宽 4px，主题色两档明度渐变（全页唯一渐变）。
          ClipRRect(
            borderRadius: AppRadius.capsule,
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: scheme.surfaceContainerHigh),
                  ),
                  FractionallySizedBox(
                    widthFactor: scope.progress.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            scheme.primary,
                            scheme.primary.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                      child: const SizedBox(height: 4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ② 今日花销主卡（全宽置顶的大数字卡）
// ---------------------------------------------------------------------------

class _SpendSummaryCard extends StatelessWidget {
  const _SpendSummaryCard({required this.tripId, required this.summary});

  final String tripId;
  final TodaySpendSummary? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = summary;
    final hasLedger = s?.hasLedger ?? false;
    final progress = s?.budgetProgress;
    final over = progress != null && progress > 1.0;
    // 环色三态：充足=主题色 / 接近(≥0.8)=预警橙 / 超支=error。
    final ringColor = progress == null
        ? scheme.primary
        : (over
            ? scheme.error
            : (progress >= 0.8 ? SemanticColors.warning : scheme.primary));

    return TodaySurface(
      accent: true,
      onTap: () => context.push('/today/$tripId/spend'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TodayCardTitle(title: '今日花销', trailing: const TodayMoreLink()),
          const SizedBox(height: Spacing.md),
          if (!hasLedger)
            // 无关联账本：显示引导而不是空数字（§8.4 第 5 条）。
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '关联账本后可用',
                  style: TextStyle(
                    fontSize: AppFontSizes.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '把这趟行程挂到一本账本上，今日花销与预算余量自动汇总。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.md),
                // V2.9.0:改跳行程编辑页——行程与账本的挂接在行程编辑页完成,
                // 原来只跳「建账本表单」,建完卡面依旧不可用(extra 传行程 id,
                // 与 trips_home 打开既有行程编辑的方式一致)。
                SecondaryButton(
                  label: '去关联账本',
                  icon: Icons.link_rounded,
                  onPressed: () => context.push('/trips/edit', extra: tripId),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MoneyHeroText(
                        s?.totalCents ?? 0,
                        fontSize: AppFontSizes.display,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        _budgetCaption(context, s, over),
                        style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: over ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(width: Spacing.md),
                  ProgressRing(
                    value: progress,
                    size: 64,
                    strokeWidth: 7,
                    color: ringColor,
                    child: Text(
                      '${(progress * 100).clamp(0, 999).round()}%',
                      style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        fontWeight: FontWeight.w700,
                        color: ringColor,
                        fontFeatures: AppTextStyles.tabularFigures,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// 预算余量文案（无预算 → 引导去设预算）。
  String _budgetCaption(BuildContext context, TodaySpendSummary? s, bool over) {
    if (s == null || s.budgetCents == null) return '本账本未设预算';
    final remain = s.remainingCents ?? 0;
    if (over) return '已超支 ${MoneyFormat.display(-remain)}';
    return '预算余量 ${MoneyFormat.display(remain)}';
  }
}

// ---------------------------------------------------------------------------
// ③ 今日安排次卡
// ---------------------------------------------------------------------------

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.tripId,
    required this.doneCount,
    required this.totalCount,
  });

  final String tripId;
  final int doneCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return TodaySurface(
      onTap: () => context.push('/today/$tripId/plan'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TodayCardTitle(
            title: '今日安排',
            trailing: TodayMoreLink(
              label: totalCount == 0 ? '去加安排' : '查看详情',
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '已完成 $doneCount',
                style: TextStyle(
                  fontSize: AppFontSizes.headline,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: AppTextStyles.tabularFigures,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '· 共 $totalCount',
                style: TextStyle(
                  fontSize: AppFontSizes.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: AppTextStyles.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // 底部细进度条：主题色纯色（不参与渐变，§8.4 第 2 条）。
          ClipRRect(
            borderRadius: AppRadius.capsule,
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 5,
              color: scheme.primary,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ④ 今日备注卡（本地便签，即时保存）
// ---------------------------------------------------------------------------

class _TodayNoteCard extends ConsumerStatefulWidget {
  const _TodayNoteCard({
    super.key,
    required this.tripId,
    required this.epochDay,
  });

  final String tripId;
  final int epochDay;

  @override
  ConsumerState<_TodayNoteCard> createState() => _TodayNoteCardState();
}

class _TodayNoteCardState extends ConsumerState<_TodayNoteCard> {
  late final TextEditingController _controller;
  late final TodayLocalStore _store;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(todayLocalStoreProvider);
    // 初值只在建立时读一次：避免每次按键触发 provider 重算导致光标跳动。
    _controller = TextEditingController(
      text: _store.note(widget.tripId, widget.epochDay),
    );
  }

  @override
  void dispose() {
    // 离开页面兜底落盘（正文已在 onChanged 写过一次）。
    if (_dirty) {
      _store.setNote(widget.tripId, widget.epochDay, _controller.text);
    }
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _dirty = true;
    _store.setNote(widget.tripId, widget.epochDay, text);
    // 通知可能的其他监听者（今日备注 provider）刷新。
    ref.read(todayNoteRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    return TodaySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TodayCardTitle(title: '今日备注'),
          const SizedBox(height: Spacing.sm),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            minLines: 3,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              fontSize: AppFontSizes.body,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              hintText: '今天的感受、明天的打算，随手记一句…',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 入场动效（唯一动效，克制；只做 transform/opacity）
// ---------------------------------------------------------------------------

/// stagger 淡入 + 12px 上移归位：单卡 250ms，总时长 700ms（硬约束）。
class _EnterStagger extends StatefulWidget {
  const _EnterStagger({
    required this.index,
    required this.enabled,
    required this.child,
  });

  final int index;

  /// false（prefers-reduced-motion 或二次进入）时**直接呈现**，不起动画。
  final bool enabled;
  final Widget child;

  @override
  State<_EnterStagger> createState() => _EnterStaggerState();
}

class _EnterStaggerState extends State<_EnterStagger>
    with SingleTickerProviderStateMixin {
  /// 时间轴总长（≤700ms）。
  static const Duration _total = Duration(milliseconds: 700);

  /// 单卡时长（≤250ms）。
  static const Duration _card = Duration(milliseconds: 250);

  /// 相邻卡片的起步间隔比例（index*150ms / 700ms）。
  static const double _step = 0.15;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final start = (widget.index * _step).clamp(0.0, 1.0);
    final end = (start + _card.inMilliseconds / _total.inMilliseconds)
        .clamp(0.0, 1.0);
    _controller =
        AnimationController(vsync: this, duration: _total);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    if (widget.enabled) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - _animation.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
