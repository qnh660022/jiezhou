/// 城市锦囊面板（V2.7.2 S9，三宿主共用；规格 §十二）。
///
/// - 顶部城名与大区；四个分组卡：行前准备（prep）/ 避坑注意（tips）/
///   预算参考（budget，rangeText 原样保留「（参考）」字样）/ 季节日历
///   （calendar，仅种子含该栏之城渲染）；
/// - prep 转清单：`ChecklistItems(scope='trip', category='other',
///   label=prep.title)`；同 trip 同 label 全等去重（跳过 toast「已在清单中」）；
/// - 无命中城 → 页签仍显示，空态卡「该目的地暂无锦囊」（O9：不隐藏入口）；
/// - viewer 只读（无「加入清单」）。
/// - 数据走既有攻略取数链（getSeed：AI 导入 > 官网整包 > 内置种子）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/guide/guide_providers.dart';
import '../../../data/providers.dart';
import '../../../domain/guide_match.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../theme/tokens.dart';

class KitPanel extends ConsumerWidget {
  const KitPanel({
    super.key,
    required this.tripId,
    required this.destination,
    required this.canEdit,
  });

  final String tripId;

  /// 行程目的地（matchCityKey 输入）。
  final String destination;

  /// viewer 只读：无「加入清单」。
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameMap =
        ref.watch(guideCityKeyByNameProvider).valueOrNull ?? const {};
    final cityKey = matchCityKey(destination, nameMap);
    if (cityKey == null) {
      return const _KitEmpty();
    }
    final seedAsync = ref.watch(kitSeedProvider(cityKey));
    final seed = seedAsync.valueOrNull;
    if (seed == null) {
      if (seedAsync.hasError) return const _KitEmpty();
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(kitSeedProvider(cityKey)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.huge),
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

class _KitEmpty extends StatelessWidget {
  const _KitEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.backpack_rounded,
        title: '该目的地暂无锦囊',
        message: '攻略还在持续扩容，可以先看看目的地攻略页',
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
