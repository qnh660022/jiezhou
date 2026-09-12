/// 攻略「换城市」选择器（2026-09 新增）。
///
/// 与行程的目的地选择器（`destination_picker_sheet.dart`）分开：
/// - 那个是**多选 + 全国 330 城 + 海外手填**，为「填行程目的地」设计；
/// - 这个只需**单选一座城**，主推内置的精品城市（有 5000 字级正文），
///   其余城市通过「更多城市」复用原选择器兜底。
library;
import 'package:flutter/material.dart';

import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';
import 'screens/destination_picker_sheet.dart' show showDestinationPicker;
import 'guide_paste_import_sheet.dart' show showGuidePasteImport;

/// 一座可选城市。
typedef GuideCityOption = ({String key, String name, String area});

/// 打开攻略城市选择器。
///
/// 返回选中城市的 key；用户取消返回 null。
Future<String?> showGuideCityPicker({
  required BuildContext context,
  required List<GuideCityOption> cities,
  String? currentKey,
}) {
  return showDraggableSheet<String>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    builder: (ctx, scrollController) => _GuideCityPicker(
      cities: cities,
      currentKey: currentKey,
      scrollController: scrollController,
    ),
  );
}

class _GuideCityPicker extends StatefulWidget {
  const _GuideCityPicker({
    required this.cities,
    required this.currentKey,
    required this.scrollController,
  });

  final List<GuideCityOption> cities;
  final String? currentKey;
  final ScrollController scrollController;

  @override
  State<_GuideCityPicker> createState() => _GuideCityPickerState();
}

class _GuideCityPickerState extends State<_GuideCityPicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 有 area 的排前面（= 精品种子城），其余按名称。
  List<GuideCityOption> get _filtered {
    final q = _query.trim();
    final all = q.isEmpty
        ? widget.cities
        : widget.cities
            .where((c) => c.name.contains(q) || c.area.contains(q))
            .toList();
    return [...all]..sort((a, b) {
        final pa = a.area.isEmpty ? 1 : 0;
        final pb = b.area.isEmpty ? 1 : 0;
        if (pa != pb) return pa - pb;
        final ca = a.area.compareTo(b.area);
        if (ca != 0) return ca;
        return a.name.compareTo(b.name);
      });
  }

  /// 按大区分组（保持 _filtered 的顺序）。
  Map<String, List<GuideCityOption>> get _grouped {
    final out = <String, List<GuideCityOption>>{};
    for (final c in _filtered) {
      final g = c.area.isEmpty ? '其他可搜城市' : c.area;
      out.putIfAbsent(g, () => []).add(c);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grouped = _grouped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, Spacing.sm),
          child: Row(children: [
            Expanded(
              child: Text(copy('guide.pickCity'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppFontSizes.bodyLarge)),
            ),
            // 粘贴导入：把外部 AI 生成的攻略 JSON 直接贴进来
            TextButton(
              onPressed: () => showGuidePasteImport(context),
              child: Text(copy('guide.pasteImport')),
            ),
            TextButton(
              onPressed: () async {
                // 兜底：全国 330 城 + 海外手填，走原目的地选择器（单选语义取首段）
                final picked =
                    await showDestinationPicker(context, '');
                if (!context.mounted) return;
                final first = (picked ?? '')
                    .split(RegExp(r'[-—→~、，,/]|到'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .firstOrNull;
                if (first != null && first.isNotEmpty) {
                  Navigator.of(context).pop(first);
                }
              },
              child: Text(copy('guide.homeMore')),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: '搜索城市，如「杭州」「云南」',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Expanded(
          child: grouped.isEmpty
              ? Center(
                  child: Text('没有匹配的城市',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)))
              : ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, 0, Spacing.lg, Spacing.xl),
                  children: [
                    for (final e in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                            top: Spacing.md, bottom: Spacing.xs),
                        child: Text(e.key,
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant)),
                      ),
                      Wrap(
                        spacing: Spacing.sm,
                        runSpacing: Spacing.sm,
                        children: [
                          for (final c in e.value)
                            _CityChip(
                              city: c,
                              selected: c.key == widget.currentKey,
                              onTap: () => Navigator.of(context).pop(c.key),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final GuideCityOption city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerLowest,
      borderRadius: AppRadius.capsule,
      child: InkWell(
        borderRadius: AppRadius.capsule,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.capsule,
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.5)
                  : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            city.name,
            style: TextStyle(
              fontSize: AppFontSizes.body,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
