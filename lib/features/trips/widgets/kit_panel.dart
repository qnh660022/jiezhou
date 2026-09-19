/// 城市锦囊面板（V2.7.2 S9，三宿主共用；规格 §十二）。
///
/// - 顶部城名与大区；四个分组卡：行前准备（prep）/ 避坑注意（tips）/
///   预算参考（budget，rangeText 原样保留「（参考）」字样）/ 季节日历
///   （calendar，仅种子含该栏之城渲染）；
/// - prep 转清单：`ChecklistItems(scope='trip', category='other',
///   label=prep.title)`；同 trip 同 label 全等去重（跳过 toast「已在清单中」）；
/// - 无命中城 / 命中但四栏全空 / 种子读取失败 → 回落**城市攻略摘要**
///   （V2.8.3.5：城名 + 统计 + 六栏宫格 + 进完整攻略），页签仍显示
///   （O9：不隐藏入口），用户不再遇到「该目的地暂无锦囊」的死路；
/// - viewer 只读（无「加入清单」）。
/// - 数据走既有攻略取数链（getSeed：AI 导入 > 官网整包 > 内置种子）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/guide/guide_providers.dart';
import '../../../data/providers.dart';
import '../../../domain/guide_match.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/tokens.dart';
import '../guide_widgets.dart' show GuideSectionGrid, GuideStatChip;
import '../screens/trip_guide_screen.dart' show TripGuideScreenBuilder;

class KitPanel extends ConsumerWidget {
  const KitPanel({
    super.key,
    required this.tripId,
    required this.destination,
    required this.canEdit,
    this.bottomInset,
  });

  final String tripId;

  /// 行程目的地（matchCityKey 输入）。
  final String destination;

  /// viewer 只读：无「加入清单」。
  final bool canEdit;

  /// 列表末尾留白（V2.8.3.4）。null = `Spacing.huge`（桌面工作台等无悬浮底栏的
  /// 宿主）；移动详情页传 `AppBottomLayout.dockedContentTail` 以避开胶囊底栏
  /// 与底部停靠双段。
  final double? bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameMap =
        ref.watch(guideCityKeyByNameProvider).valueOrNull ?? const {};
    final cityKey = matchCityKey(destination, nameMap);
    // V2.8.3.5：锦囊不可用不再留死路 —— 未命中种子城时回落「城市攻略摘要」。
    if (cityKey == null) {
      return _CityGuideFallback(
        tripId: tripId,
        destination: destination,
        bottomInset: bottomInset,
      );
    }
    final seedAsync = ref.watch(kitSeedProvider(cityKey));
    final seed = seedAsync.valueOrNull;
    if (seed == null) {
      if (seedAsync.hasError) {
        return _CityGuideFallback(
          tripId: tripId,
          destination: destination,
          bottomInset: bottomInset,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    // V2.8.3.5：命中城但四栏全空（种子存在却无内容）→ 同样回落，避免空白页签。
    if (seed.prep.isEmpty &&
        seed.tips.isEmpty &&
        seed.budget.isEmpty &&
        seed.calendar.isEmpty) {
      return _CityGuideFallback(
        tripId: tripId,
        destination: destination,
        bottomInset: bottomInset,
      );
    }
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(kitSeedProvider(cityKey)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // V2.8.3.4：末尾留白由宿主决定 —— 移动详情页要避开胶囊底栏 + 底部停靠
        // 双段（传 dockedContentTail），桌面工作台没有悬浮底栏，维持原值。
        padding: EdgeInsets.fromLTRB(
          Spacing.xl,
          Spacing.md,
          Spacing.xl,
          bottomInset ?? Spacing.huge,
        ),
        children: [
          _cityHeader(context, seed),
          if (seed.prep.isNotEmpty)
            _PrepCard(
              rows: seed.prep,
              canEdit: canEdit,
              onAdd: (title) async {
                final added = await ref
                    .read(checklistRepoProvider)
                    .addKitPrepItem(tripId: tripId, label: title);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                      content: Text(added ? '已加入出行清单' : '已在清单中')));
              },
            ),
          if (seed.tips.isNotEmpty) _TitleDetailCard(title: '避坑注意', rows: seed.tips),
          if (seed.budget.isNotEmpty) _BudgetCard(rows: seed.budget),
          // 季节日历：仅种子含该栏之城渲染；无则整组不渲染
          if (seed.calendar.isNotEmpty) _TitleDetailCard(title: '季节日历', rows: seed.calendar),
        ],
      ),
    );
  }

  Widget _cityHeader(BuildContext context, KitSeed seed) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          Text(seed.cityName,
              style: const TextStyle(
                  fontSize: AppFontSizes.title, fontWeight: FontWeight.w800)),
          if (seed.area.isNotEmpty) ...[
            const SizedBox(width: Spacing.sm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: AppRadius.capsule,
              ),
              child: Text(seed.area,
                  style: TextStyle(
                      fontSize: AppFontSizes.caption - 1,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary)),
            ),
          ],
        ],
      ),
    );
  }
}

/// V2.8.3.5：锦囊不可用时的**回落**——渲染城市攻略摘要，绝不留死路。
///
/// 触发条件：行程目的地未命中种子城，或命中但四栏（prep / tips / budget /
/// calendar）全空，或种子读取失败。
///
/// 数据走既有 [guideByTripProvider]（离线种子优先，零网络依赖），六栏宫格
/// 复用攻略页的 [GuideSectionGrid]，点任意格 / 底部按钮进完整攻略页 —— 与
/// 「该目的地暂无锦囊」的旧空态相比，用户在这里始终拿得到东西。
class _CityGuideFallback extends ConsumerWidget {
  const _CityGuideFallback({
    required this.tripId,
    required this.destination,
    this.bottomInset,
  });

  final String tripId;
  final String destination;
  final double? bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(guideByTripProvider(tripId));
    final result = async.valueOrNull;
    if (result == null) {
      if (async.hasError) return _KitUnavailable(destination: destination);
      return const Center(child: CircularProgressIndicator());
    }
    final cityName = result.location?.name ?? destination;
    final spotCount = (result.sections['spots'] ?? const []).length +
        (result.sections['food'] ?? const []).length;
    final sourceLabel = result.isAiImported
        ? copy('guide.sourceAi')
        : result.hasCrawledGuide
            ? copy('guide.sourceNetwork')
            : copy('guide.sourceBuiltin');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: Spacing.md,
        bottom: bottomInset ?? Spacing.huge,
      ),
      children: [
        // 说明条：解释为什么这里不是锦囊
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.md),
          child: Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: AppRadius.input,
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 17, color: scheme.primary),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  '该目的地暂无城市锦囊，先看这份城市攻略',
                  style: TextStyle(
                      fontSize: AppFontSizes.caption, color: scheme.onSurface),
                ),
              ),
            ]),
          ),
        ),
        // 城市头摘要：城名 + 统计胶囊
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.lg),
          child: Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.card,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.85),
                  scheme.surfaceContainerLowest,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cityName,
                    style: AppTextStyles.headline(scheme)
                        .copyWith(fontSize: 26)),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    GuideStatChip(
                        icon: AppIcons.compass, text: '$spotCount 个景点/美食'),
                    GuideStatChip(
                        icon: AppIcons.clock,
                        text: '约 ${result.readingMinutes} 分钟读完'),
                    GuideStatChip(icon: AppIcons.check, text: sourceLabel),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 六栏宫格（自带横向 Spacing.xl 内边距）
        GuideSectionGrid(
          sections: result.sections,
          onTap: (_) => _openFullGuide(context),
        ),
        const SizedBox(height: Spacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: OutlinedButton.icon(
            onPressed: () => _openFullGuide(context),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('查看完整城市攻略'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullGuide(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TripGuideScreenBuilder(tripId: tripId),
    ));
  }
}

/// 城市攻略也取不到时的最坏空态（原「该目的地暂无锦囊」的收窄版）。
class _KitUnavailable extends StatelessWidget {
  const _KitUnavailable({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.backpack_rounded,
        title: '攻略暂时取不到',
        message: '「$destination」的攻略数据暂不可用，稍后再试',
      ),
    );
  }
}

/// 通用分组卡头。
Widget _kitCardHeader(BuildContext context, String title, IconData icon) {
  final scheme = Theme.of(context).colorScheme;
  return Row(children: [
    Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Spacing.sm + 2),
      ),
      child: Icon(icon, size: 17, color: scheme.primary),
    ),
    const SizedBox(width: Spacing.md),
    Text(title,
        style: const TextStyle(
            fontSize: AppFontSizes.bodyLarge, fontWeight: FontWeight.w700)),
  ]);
}

/// 行前准备：title 加粗 + detail 全文 + 右上「加入清单」。
class _PrepCard extends StatelessWidget {
  const _PrepCard({required this.rows, required this.canEdit, required this.onAdd});

  final List<Map<String, dynamic>> rows;
  final bool canEdit;
  final Future<void> Function(String title) onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _KitCard(
      header: Row(children: [
        Expanded(child: _kitCardHeader(context, '行前准备', Icons.checklist_rounded)),
        if (canEdit)
          Text('逐条可加入清单',
              style: TextStyle(
                  fontSize: AppFontSizes.caption - 1,
                  color: scheme.onSurfaceVariant)),
      ]),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text((row['title'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (canEdit)
                      Tooltip(
                        message: '加入出行清单',
                        child: InkWell(
                          borderRadius: AppRadius.capsule,
                          onTap: () =>
                              onAdd((row['title'] ?? '').toString()),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.playlist_add_rounded,
                                size: 20, color: scheme.primary),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text((row['detail'] ?? '').toString(),
                    style: TextStyle(
                        fontSize: AppFontSizes.body - 1,
                        height: 1.5,
                        color: scheme.onSurface)),
              ],
            ),
          ),
      ],
    );
  }
}

/// title + detail 通用卡（避坑注意 / 季节日历）。
class _TitleDetailCard extends StatelessWidget {
  const _TitleDetailCard({required this.title, required this.rows});

  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _KitCard(
      header: _kitCardHeader(context, title, Icons.tips_and_updates_rounded),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((row['title'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text((row['detail'] ?? '').toString(),
                    style: TextStyle(
                        fontSize: AppFontSizes.body - 1,
                        height: 1.5,
                        color: scheme.onSurface)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 预算参考：item + rangeText 原文（不数字化，保留「（参考）」字样）。
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _KitCard(
      header: _kitCardHeader(context, '预算参考', Icons.savings_rounded),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text((row['item'] ?? '').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Text((row['rangeText'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: AppFontSizes.body - 1,
                          color: scheme.onSurface)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KitCard extends StatelessWidget {
  const _KitCard({required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.lg),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.input,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, const Divider(height: Spacing.lg), ...children],
      ),
    );
  }
}
