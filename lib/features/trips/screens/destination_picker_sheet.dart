/// 目的地选择器（底部弹层）：全国城市两级浏览 + 搜索 + 多选 + 海外手动填。
/// 选择结果以「-」连接回填行程目的地，与攻略多目的地归一化（§7.14）直接对齐。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/seed/china_regions.dart';
import '../../../theme/tokens.dart';
import '../../../shared/widgets/sheet.dart';

/// 目的地分隔符（行程存储形态：「成都-稻城」）。
const String kDestinationSeparator = '-';

/// 解析已有目的地字符串为城市列表（兼容 - 到 、 ， / 等历史手填形态）。
List<String> parseDestinations(String raw) => raw
    .split(RegExp(r'[-—→~、，,/]|到'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// 打开目的地选择弹层；返回以分隔符连接的目的地串（取消返回 null）。
Future<String?> showDestinationPicker(BuildContext context, String current) {
  return showDraggableSheet<String>(
    context: context,
    initialChildSize: 0.9,
    minChildSize: 0.6,
    builder: (context, scrollController) =>
        _DestinationPickerBody(initial: parseDestinations(current)),
  );
}

class _DestinationPickerBody extends StatefulWidget {
  const _DestinationPickerBody({required this.initial});

  final List<String> initial;

  @override
  State<_DestinationPickerBody> createState() => _DestinationPickerBodyState();
}

class _DestinationPickerBodyState extends State<_DestinationPickerBody> {
  late final List<String> _selected = [...widget.initial];
  final _searchCtrl = TextEditingController();
  final _manualCtrl = TextEditingController();
  String _query = '';
  String _activeRegion = kChinaRegions.keys.first;
  bool _manualMode = false;

  static const _maxSelect = 5;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _toggle(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else if (_selected.length < _maxSelect) {
        _selected.add(name);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最多选 5 个目的地，长路线可拆成多段行程')));
      }
    });
  }

  /// 搜索命中：城市名或所属省份含关键词。
  List<ChinaCity> get _searchHits {
    final q = _query.trim();
    if (q.isEmpty) return const [];
    return [
      for (final c in kChinaCities)
        if (c.name.contains(q) || c.region.contains(q)) c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('选择目的地',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: AppFontSizes.bodyLarge)),
            ),
            Text('可多选（${_selected.length}/$_maxSelect）',
                style: TextStyle(
                    fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: Spacing.sm),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '搜索城市或省份，如「大理」「云南」',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                for (final name in _selected)
                  InputChip(
                    label: Text(name),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => setState(() => _selected.remove(name)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Expanded(child: _query.isNotEmpty ? _buildSearchList() : _buildBrowser()),
          const SizedBox(height: Spacing.sm),
          Row(children: [
            TextButton.icon(
              onPressed: () => setState(() => _manualMode = !_manualMode),
              icon: const Icon(Icons.public_rounded, size: 18),
              label: Text(_manualMode ? '收起手动输入' : '海外/自定义城市'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_selected.join(kDestinationSeparator)),
              child: const Text('确定'),
            ),
          ]),
          if (_manualMode)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: TextField(
                controller: _manualCtrl,
                decoration: const InputDecoration(
                    hintText: '输入海外城市名，如「东京」「巴黎」，回车添加', isDense: true),
                onSubmitted: (v) {
                  final name = v.trim();
                  if (name.isEmpty) return;
                  if (!_selected.contains(name)) _toggle(name);
                  _manualCtrl.clear();
                },
              ),
            ),
        ],
      ),
    );
  }

  // ============ 浏览模式：省份左栏 + 城市右栏 ============

  Widget _buildBrowser() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: ListView.builder(
            itemCount: kChinaRegions.length,
            itemBuilder: (context, i) {
              final region = kChinaRegions.keys.elementAt(i);
              final active = region == _activeRegion;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeRegion = region);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: Spacing.sm, horizontal: Spacing.xs),
                  color: active ? scheme.surfaceContainerHigh : Colors.transparent,
                  child: Text(
                    region,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSizes.caption,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Builder(builder: (context) {
            final cities = kChinaRegions[_activeRegion] ?? const [];
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
              itemCount: cities.length,
              itemBuilder: (context, i) {
                final name = cities[i];
                final picked = _selected.contains(name);
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(name, style: const TextStyle(fontSize: AppFontSizes.body)),
                  trailing: picked
                      ? Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary)
                      : null,
                  onTap: () => _toggle(name),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  // ============ 搜索模式：命中城市平铺 ============

  Widget _buildSearchList() {
    final hits = _searchHits;
    if (hits.isEmpty) {
      return Center(
        child: Text('没有匹配的城市，海外城市可用底部「海外/自定义城市」手填',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppFontSizes.caption)),
      );
    }
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final c = hits[i];
        final picked = _selected.contains(c.name);
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(c.name, style: const TextStyle(fontSize: AppFontSizes.body)),
          subtitle: c.isHongKongMacaoTaiwan
              ? null
              : Text(c.region, style: const TextStyle(fontSize: AppFontSizes.caption)),
          trailing: picked
              ? Icon(Icons.check_circle_rounded,
                  size: 18, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () => _toggle(c.name),
        );
      },
    );
  }
}
