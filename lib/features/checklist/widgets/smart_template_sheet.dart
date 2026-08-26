// 清单智能模板库：推荐场景卡 + 收藏 + 分组预览勾选 + 批量导入。
// 依赖：
//   - data/seed/checklist_scenarios.dart（场景模板）
//   - domain/checklist_recommender.dart（推荐/去重）
//   - data/db/database.dart + core/uid.dart + data/providers.dart（落库）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/uid.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../data/seed/checklist_scenarios.dart';
import '../../../data/seed/checklist_templates.dart';
import '../../../domain/checklist_recommender.dart';
import '../../../theme/tokens.dart';

/// 智能模板库抽屉（推荐 + 全部场景 + 收藏置顶）。
class SmartTemplateSheet extends ConsumerStatefulWidget {
  const SmartTemplateSheet({
    super.key,
    required this.trip,
    required this.existing,
    required this.onImported,
  });

  final Trip trip;
  final List<ChecklistItem> existing;
  final VoidCallback onImported;

  @override
  ConsumerState<SmartTemplateSheet> createState() => _SmartTemplateSheetState();
}

class _SmartTemplateSheetState extends ConsumerState<SmartTemplateSheet> {
  Set<String> _favs = const {};

  List<ScenarioTemplate> get _scenarios => kScenarioTemplates;

  @override
  void initState() {
    super.initState();
    ref.read(prefsRepoProvider).getChecklistTplFavs().then((v) {
      if (mounted) setState(() => _favs = v);
    });
  }

  Future<void> _toggleFav(String key) async {
    HapticFeedback.selectionClick();
    final next = {..._favs};
    if (!next.add(key)) next.remove(key);
    setState(() => _favs = next);
    await ref.read(prefsRepoProvider).setChecklistTplFavs(next);
  }

  Future<void> _apply(
      BuildContext ctx, ScenarioTemplate tpl, Map<String, List<String>> chosen) async {
    final repo = ref.read(checklistRepoProvider);
    final tripId = widget.trip.id;
    final existingLabels = {for (final e in widget.existing) e.label.trim()};
    var order = widget.existing.length;
    final companions = <ChecklistItemsCompanion>[];
    chosen.forEach((catKey, labels) {
      for (final raw in labels) {
        final label = raw.trim();
        if (label.isEmpty || existingLabels.contains(label)) continue;
        existingLabels.add(label);
        companions.add(ChecklistItemsCompanion(
          id: Value(newId('check')),
          tripId: Value(tripId),
          scope: const Value('trip'),
          category: Value(catKey),
          label: Value(label),
          done: const Value(false),
          sortOrder: Value(order++),
        ));
      }
    });
    if (companions.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('所选条目都已存在，无需导入')));
      return;
    }
    await repo.importBatch(companions);
    if (ctx.mounted) {
      Navigator.of(ctx).pop();
      widget.onImported();
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('已从「${tpl.name}」导入 ${companions.length} 项')));
    }
  }

  void _openPreview(ScenarioTemplate tpl) {
    HapticFeedback.selectionClick();
    final existingLabels = {for (final e in widget.existing) e.label.trim()};
    showDraggableSheet(
      context: context,
      initialChildSize: 0.68,
      minChildSize: 0.46,
      builder: (ctx, scrollCtrl) => StatefulBuilder(
        builder: (sCtx, setSheet) {
          final selected = <String, Set<String>>{};
          for (final key in tpl.items.keys) {
            selected[key] = {for (final l in tpl.items[key]!) if (!existingLabels.contains(l.trim())) l};
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text(tpl.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text('「${tpl.name}」清单',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: Spacing.sm),
                Text('已存在的条目已自动跳过，可手动取消勾选',
                    style: TextStyle(fontSize: AppFontSizes.caption, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: Spacing.md),
                Flexible(
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      for (final entry in tpl.items.entries)
                        _CategoryPreview(
                          category: findChecklistCategory(entry.key),
                          labels: entry.value,
                          selectedSet: selected[entry.key]!,
                          onToggle: (label, v) => setSheet(() {
                            v ? selected[entry.key]!.add(label) : selected[entry.key]!.remove(label);
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.md),
                FilledButton(
                  onPressed: () async {
                    final chosen = <String, List<String>>{};
                    var count = 0;
                    selected.forEach((k, v) { if (v.isNotEmpty) { chosen[k] = v.toList(); count += v.length; } });
                    if (count == 0) {
                      ScaffoldMessenger.of(sCtx).showSnackBar(const SnackBar(content: Text('未选择任何条目')));
                      return;
                    }
                    await _apply(sCtx, tpl, chosen);
                  },
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: AppRadius.button)),
                  child: const Padding(padding: EdgeInsets.symmetric(vertical: Spacing.md), child: Text('导入所选')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matches = recommendTemplates(
      destination: widget.trip.destination,
      tripName: widget.trip.name,
      startEpochDay: widget.trip.startEpochDay,
      endEpochDay: widget.trip.endEpochDay,
    );
    final faved = [for (final t in _scenarios) if (_favs.contains(t.key)) t];
    final ordered = <ScenarioTemplate>[
      ...faved,
      ...matches.map((m) => m.template).where((t) => !_favs.contains(t.key)),
      ..._scenarios.where((t) => !_favs.contains(t.key) && !matches.any((m) => m.template.key == t.key)),
    ];
    final reasonByKey = {for (final m in matches) m.template.key: m.reasons};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Text('✨', style: TextStyle(fontSize: 20)),
          const SizedBox(width: Spacing.md),
          Text('智能模板库',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${_scenarios.length} 个场景', style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: Spacing.xs),
        Text('按目的地、月份、天数自动推荐，点亮星星收藏',
            style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.md),
        Flexible(
          child: GridView.builder(
            controller: ScrollController(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: Spacing.md,
              crossAxisSpacing: Spacing.md,
              childAspectRatio: 1.25,
            ),
            itemCount: ordered.length,
            itemBuilder: (context, i) {
              final t = ordered[i];
              final reasons = reasonByKey[t.key];
              final recommended = reasons != null && reasons.isNotEmpty;
              final fav = _favs.contains(t.key);
              return GestureDetector(
                onTap: () => _openPreview(t),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: recommended ? scheme.primaryContainer.withValues(alpha: 0.45) : scheme.surfaceContainerLowest,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: recommended ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 22)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _toggleFav(t.key),
                          child: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 18, color: fav ? Colors.amber : scheme.onSurfaceVariant),
                        ),
                      ]),
                      const Spacer(),
                      Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${t.items.values.fold<int>(0, (s, l) => s + l.length)} 项',
                          style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
                      if (recommended) ...[
                        const SizedBox(height: 2),
                        Text(reasons.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppFontSizes.caption - 2, color: scheme.primary)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 分组预览（分类标题 + 勾选项）
class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({
    required this.category,
    required this.labels,
    required this.selectedSet,
    required this.onToggle,
  });

  final ChecklistCategory category;
  final List<String> labels;
  final Set<String> selectedSet;
  final void Function(String label, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: AppRadius.input,
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
              child: Row(children: [
                Text(category.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: Spacing.sm),
                Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            for (final l in labels)
              CheckboxListTile(
                value: selectedSet.contains(l),
                onChanged: (v) => onToggle(l, v ?? false),
                title: Text(l, style: const TextStyle(fontSize: AppFontSizes.body)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}
