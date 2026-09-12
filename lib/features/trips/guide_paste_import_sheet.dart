/// 「粘贴导入攻略」弹层（2026-09）。
///
/// 用途：外部 AI（网页版大模型）生成的攻略 JSON，用户复制后直接贴进 App 就能用，
/// 不必等施工方改包。与 AI 助手内的生成流程共用同一套校验与落库
/// （`GuideService.importCityGuide`），优先级也一致（最高层的单城覆盖包）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/guide/guide_paste_import.dart';
import '../../../data/guide/guide_providers.dart' show guideServiceProvider;
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../theme/tokens.dart';

/// 打开粘贴导入弹层；导入成功返回导入的城市名。
Future<String?> showGuidePasteImport(BuildContext context) {
  return showDraggableSheet<String>(
    context: context,
    initialChildSize: 0.8,
    minChildSize: 0.5,
    builder: (ctx, scrollController) =>
        _PasteImportBody(scrollController: scrollController),
  );
}

class _PasteImportBody extends ConsumerStatefulWidget {
  const _PasteImportBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_PasteImportBody> createState() => _PasteImportBodyState();
}

class _PasteImportBodyState extends ConsumerState<_PasteImportBody> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _parsed;
  List<List<String>> _rows = const [];
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 先把现有城市 key 表拉出来，解析时校验 key 是否存在。
  Future<Map<String, String>> _seedNames() async {
    final cities = await ref.read(guideServiceProvider).allCities();
    return {for (final c in cities) c.key: c.name};
  }

  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final names = await _seedNames();
    if (!mounted) return;
    final res = parseGuideJson(_ctrl.text, seedNames: names);
    setState(() {
      _busy = false;
      _parsed = res.city;
      _error = res.error;
      _rows = res.city == null ? const [] : guideJsonSummary(res.city!);
    });
  }

  Future<void> _import() async {
    final city = _parsed;
    if (city == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(guideServiceProvider).importCityGuide(city);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) {
      Navigator.of(context).pop(city['name'] as String? ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.xl),
      children: [
        Text(copy('guide.pasteImport'),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: AppFontSizes.bodyLarge)),
        const SizedBox(height: Spacing.xs),
        Text(copy('guide.pasteImportHint'),
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _ctrl,
          minLines: 6,
          maxLines: 12,
          onChanged: (_) => setState(() {
            _parsed = null;
            _rows = const [];
            _error = null;
          }),
          decoration: const InputDecoration(
            hintText: '{"key":"hangzhou","name":"杭州","sections":{…}}',
            isDense: true,
          ),
          style: const TextStyle(fontSize: AppFontSizes.caption, height: 1.4),
        ),
        const SizedBox(height: Spacing.md),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text(_error!,
                style: TextStyle(
                    fontSize: AppFontSizes.caption, color: scheme.error)),
          ),
        if (_rows.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.input,
            ),
            child: Column(
              children: [
                for (final r in _rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(
                        width: 72,
                        child: Text(r[0],
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: scheme.onSurfaceVariant)),
                      ),
                      Expanded(
                        child: Text(r[1],
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(copy('guide.pasteImportOverwrite'),
              style: TextStyle(
                  fontSize: AppFontSizes.caption - 1,
                  color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _preview,
                child: Text(copy('guide.pasteImportPreview')),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: FilledButton(
                onPressed: (_busy || _parsed == null) ? null : _import,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(copy('guide.pasteImportAction')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
