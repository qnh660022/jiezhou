/// 攻略精要随卡（V2.7.2 S10，规格 §十三）。
///
/// 卡片详情抽屉底部的只读折叠段：guideRef 反查种子条目——
/// spots → `addr`/`tag` 行 + `note` 全文（完整不截断）；food → `area` + `note`；
/// 反查失败（无 guideRef/城缺失/序号越界/名称漂移）→ 整段不渲染；
/// 折叠态默认收起；viewer 可读；无任何写操作。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/guide/guide_providers.dart';
import '../../../domain/guide_ref.dart';
import '../../../theme/tokens.dart';

class GuideEssenceSection extends ConsumerStatefulWidget {
  const GuideEssenceSection({
    super.key,
    required this.guideRef,
    required this.itemName,
  });

  final String guideRef;

  /// 卡片名称（与反查行 name 全等校验——种子序号漂移时整段降级）。
  final String itemName;

  @override
  ConsumerState<GuideEssenceSection> createState() =>
      _GuideEssenceSectionState();
}

class _GuideEssenceSectionState extends ConsumerState<GuideEssenceSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parsed = GuideRef.tryParse(widget.guideRef);
    if (parsed == null) return const SizedBox.shrink();
    final row = ref.watch(guideRowByRefProvider(widget.guideRef)).valueOrNull;
    // 失效 ref / 序号漂移（行名与卡名不一致）→ 静默降级不渲染
    if (row == null) return const SizedBox.shrink();
    if ((row['name'] ?? '').toString().trim() != widget.itemName.trim()) {
      return const SizedBox.shrink();
    }
    final isSpot = parsed.section == 'spots';
    final place = (row[isSpot ? 'addr' : 'area'] ?? '').toString();
    final tag = (row['tag'] ?? '').toString();
    final note = (row['note'] ?? '').toString();
    if (note.isEmpty && place.isEmpty && tag.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: Spacing.md),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.input,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: AppRadius.input,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(children: [
                Icon(Icons.menu_book_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text('攻略精要',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                ),
                Text(tag.isNotEmpty ? tag : (isSpot ? '景点' : '美食'),
                    style: TextStyle(
                        fontSize: AppFontSizes.caption - 1,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(width: Spacing.sm),
                Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (place.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Row(children: [
                        Icon(Icons.place_rounded,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(place,
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption,
                                  color: scheme.onSurfaceVariant)),
                        ),
                      ]),
                    ),
                  // note 全文（完整不截断）；长文滚动适配小屏
                  if (note.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: Text(note,
                            style: TextStyle(
                                fontSize: AppFontSizes.body - 1,
                                height: 1.55,
                                color: scheme.onSurface)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
