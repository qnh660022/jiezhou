/// 📦 行程模板库：把行程存为模板 / 用模板一键建行程 / 删除模板。
///
/// 模板数据存 SharedPreferences（trip_template_store.dart），
/// AI 生成行程后也会自动存同名模板。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/date_utils.dart';
import '../../../core/uid.dart';
import '../../../data/db/database.dart' show TripItemsCompanion;
import '../../../data/providers.dart';
import '../../../data/seed/item_types.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../theme/tokens.dart';
import '../../ledger/ledger_providers.dart';
import '../trip_template_store.dart';

class TripTemplatesScreen extends ConsumerWidget {
  const TripTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(tripTemplatesProvider);
    return Scaffold(
      appBar: GlassAppBar(title: '行程模板库'),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(emoji: '😵', title: '模板加载失败'),
        data: (templates) {
          if (templates.isEmpty) {
            return EmptyState(
              emoji: '📦',
              title: '还没有行程模板',
              message: '在行程详情页「存为模板」，\n或让 AI 生成行程后自动收藏',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.huge),
            children: [
              for (final t in templates)
                _TemplateCard(template: t),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});

  final TripTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(template.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          '${template.destination} · ${template.dayCount} 天 · ${template.items.length} 条安排',
                          style: TextStyle(
                              fontSize: AppFontSizes.caption,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '删除模板',
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      await deleteTemplate(template.id);
                      ref.invalidate(tripTemplatesProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              PrimaryButton(
                label: '用模板建行程',
                icon: Icons.add_road_rounded,
                expanded: true,
                onPressed: () => _pickStartDate(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: '选择新行程开始日期',
    );
    if (picked == null || !context.mounted) return;
    final start = dateToEpochDay(picked);
    final end = start + (template.dayCount - 1).clamp(0, 365);
    final now2 = DateTime.now().millisecondsSinceEpoch;
    final tripId = await ref.read(tripsRepoProvider).createTrip(
          name: template.name,
          dest: template.destination,
          emoji: template.emoji,
          cover: 'ocean',
          start: start,
          end: end,
          groupId: ref.read(activeGroupProvider).value?.id,
        );
    final perDay = <int, int>{};
    for (final i in template.items) {
      final idx = perDay[i.day] ?? 0;
      perDay[i.day] = idx + 1;
      await ref.read(tripsRepoProvider).insertItem(TripItemsCompanion(
            id: Value(newId('item')),
            tripId: Value(tripId),
            dateEpochDay: Value(start + i.day - 1),
            type: Value(findTripItemType(i.type).key),
            name: Value(i.name),
            address: Value(i.address),
            startTimeMin: Value(i.startTimeMin),
            costCents: Value(i.costCents),
            note: Value(i.note),
            sortOrder: Value(idx * 10),
            createdAt: Value(now2),
            updatedAt: Value(now2),
          ));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已创建行程「${template.name}」（${template.items.length} 条安排）'),
      ));
    }
  }
}
