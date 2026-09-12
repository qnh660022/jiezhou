/// AI 通用确认卡（action_confirm）与统计卡（expense_stats）。
///
/// 确认卡：敏感操作预览 + 取消/确认按钮，确认后走 [commitAiAction]
/// 本地落库（零 token）。危险操作（删除类）用 error 色带警示。
///
/// 2026-09 新增 [GuideImportCard]：AI 生成的攻略内容预览与导入
/// （用户需求 5「支持软件中 AI 生成攻略并导入攻略（要有确认卡）」）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/guide/guide_providers.dart' show guideServiceProvider;
import '../../../shared/copy_tokens.dart';
import '../../../theme/tokens.dart';
import '../ai_confirm_actions.dart' show commitAiAction;

/// 通用操作确认卡。
class ActionConfirmCard extends ConsumerStatefulWidget {
  const ActionConfirmCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  ConsumerState<ActionConfirmCard> createState() => _ActionConfirmCardState();
}

class _ActionConfirmCardState extends ConsumerState<ActionConfirmCard> {
  bool _committing = false;
  String? _error;
  bool _cancelled = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.data;
    final danger = data['danger'] == true;
    final title = data['title'] as String? ?? '确认操作';
    final note = data['note'] as String?;
    final rows = (data['rows'] as List?)?.cast<Map>() ?? const [];
    final accent = danger ? scheme.error : scheme.primary;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.85),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部色带：危险操作 error 色调，其余 primary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
              color: accent.withValues(alpha: danger ? 0.14 : 0.10),
              child: Row(
                children: [
                  Icon(
                    danger ? Icons.warning_amber_rounded : Icons.task_alt_rounded,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: AppFontSizes.body,
                            color: accent)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('需确认',
                        style: TextStyle(
                            fontSize: AppFontSizes.caption,
                            color: accent,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['label']}',
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption,
                                  color: scheme.onSurfaceVariant)),
                          const Spacer(),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.widthOf(context) * 0.5),
                            child: Text('${r['value']}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: AppFontSizes.caption,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  if (note != null) ...[
                    const SizedBox(height: Spacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(note,
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption,
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Spacing.lg),
                  if (_done)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1.0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Row(children: [
                        Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
                        const SizedBox(width: Spacing.sm),
                        Text('已完成',
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: scheme.primary,
                                fontWeight: FontWeight.w700)),
                      ]),
                    )
                  else if (_cancelled)
                    Row(children: [
                      Icon(Icons.cancel_outlined, size: 18, color: scheme.outline),
                      const SizedBox(width: Spacing.sm),
                      Text('已取消，未执行',
                          style: TextStyle(
                              fontSize: AppFontSizes.caption,
                              color: scheme.onSurfaceVariant)),
                    ])
                  else ...[
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(
                              fontSize: AppFontSizes.caption, color: scheme.error)),
                      const SizedBox(height: Spacing.sm),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _committing ? null : () => setState(() => _cancelled = true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant,
                              side: BorderSide(color: scheme.outlineVariant),
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _committing ? null : _confirm,
                            style: danger
                                ? FilledButton.styleFrom(
                                    backgroundColor: scheme.error,
                                    foregroundColor: scheme.onError,
                                  )
                                : null,
                            icon: _committing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2))
                                : Icon(danger
                                    ? Icons.delete_outline_rounded
                                    : Icons.check_rounded,
                                    size: 18),
                            label: Text(danger ? '确认删除' : '确认执行'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _committing = true;
      _error = null;
    });
    final action = widget.data['action'] as String? ?? '';
    final args = (widget.data['args'] as Map?)?.cast<String, dynamic>() ?? const {};
    String? err;
    try {
      err = await commitAiAction(ref, action, args);
    } catch (e) {
      err = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _committing = false;
      if (err == null) {
        _done = true;
      } else {
        _error = err;
      }
    });
  }
}

/// 统计卡：横向占比条形，冠军条高亮。
class ExpenseStatsCard extends StatelessWidget {
  const ExpenseStatsCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = data['label'] as String? ?? '分类';
    final rows = (data['rows'] as List?)?.cast<Map>() ?? const [];
    final totalYuan = (data['totalYuan'] as num?)?.toDouble() ?? 0;

    final maxPercent = rows.fold<double>(
        0.0, (m, r) => m > _pct(r) ? m : _pct(r));
    return _StatShell(
      title: '消费统计 · $label',
      trailing: '合计 ¥${totalYuan.toStringAsFixed(totalYuan % 1 == 0 ? 0 : 2)}',
      child: rows.isEmpty
          ? Text('没有符合条件的账单',
              style: TextStyle(
                  fontSize: AppFontSizes.caption, color: scheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text('${rows[i]['label']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption,
                                  fontWeight:
                                      i == 0 ? FontWeight.w800 : FontWeight.w500)),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: _pct(rows[i]) / (maxPercent == 0 ? 1 : maxPercent)),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => LinearProgressIndicator(
                                value: v.clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor:
                                    scheme.outlineVariant.withValues(alpha: 0.4),
                                color: i == 0 ? scheme.primary : scheme.primary.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        SizedBox(
                          width: 76,
                          child: Text(
                            '¥${_yuan(rows[i])} · ${(_pct(rows[i]) * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  double _pct(Map r) => r['percent'] is num ? (r['percent'] as num).toDouble() : 0;
  String _yuan(Map r) {
    final v = r['yuan'] is num ? (r['yuan'] as num).toDouble() : 0.0;
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
  }
}

/// 统计卡外壳（与确认卡同风格的轻投影容器）
class _StatShell extends StatelessWidget {
  const _StatShell({required this.title, required this.trailing, required this.child});

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.85),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.donut_small_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: AppFontSizes.body)),
                const Spacer(),
                Text(trailing,
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 攻略导入确认卡（guide_import_confirm）
// ---------------------------------------------------------------------------

/// AI 生成攻略的导入确认卡。
///
/// 展示：城市、六栏条数与字数、正文合计与预计阅读时长、内容缺口提示，
/// 以及「AI 生成内容仅供参考」的提醒。点「导入攻略」后由
/// [commitAiAction] 走 `import_guide` 本地落盘（不发任何 AI 请求）。
class GuideImportCard extends ConsumerStatefulWidget {
  const GuideImportCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  ConsumerState<GuideImportCard> createState() => _GuideImportCardState();
}

class _GuideImportCardState extends ConsumerState<GuideImportCard> {
  bool _committing = false;
  bool _done = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.data;
    final cityName = (data['cityName'] ?? '').toString();
    final rows = (data['rows'] as List?)?.cast<Map>() ?? const [];
    final gaps = (data['gaps'] as List?)?.cast<String>() ?? const <String>[];
    final minutes = (data['readingMinutes'] as num?)?.toInt() ?? 0;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.85),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.5), width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
              child: Row(children: [
                Icon(Icons.menu_book_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    '${copy('guide.aiImportTitle')} · $cityName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppFontSizes.body),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.sm, Spacing.lg, 0),
              child: Column(
                children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(
                          width: 72,
                          child: Text((r['label'] ?? '').toString(),
                              style: TextStyle(
                                  fontSize: AppFontSizes.caption,
                                  color: scheme.onSurfaceVariant)),
                        ),
                        Expanded(
                          child: Text((r['value'] ?? '').toString(),
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
            if (minutes > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.sm, Spacing.lg, 0),
                child: Text('约 $minutes 分钟读完',
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700)),
              ),
            if (gaps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.sm, Spacing.lg, 0),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: SemanticColors.warning.withValues(alpha: 0.12),
                    borderRadius: AppRadius.input,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('还可以更完整：',
                          style: TextStyle(
                              fontSize: AppFontSizes.caption,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface)),
                      for (final g in gaps.take(4))
                        Text('· $g',
                            style: TextStyle(
                                fontSize: AppFontSizes.caption - 1,
                                color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
              child: Text(copy('guide.aiImportNote'),
                  style: TextStyle(
                      fontSize: AppFontSizes.caption - 1,
                      color: scheme.onSurfaceVariant)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.sm),
                child: Text(_error!,
                    style: TextStyle(
                        fontSize: AppFontSizes.caption,
                        color: scheme.error)),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_done)
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(copy('guide.aiImported')),
                    )
                  else
                    FilledButton(
                      onPressed: _committing ? null : _commit,
                      child: _committing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(copy('guide.aiImportAction')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _commit() async {
    setState(() {
      _committing = true;
      _error = null;
    });
    final city = (widget.data['city'] as Map?)?.cast<String, dynamic>();
    if (city == null) {
      setState(() {
        _committing = false;
        _error = '内容丢失，请让 AI 重新生成一次';
      });
      return;
    }
    final err = await ref.read(guideServiceProvider).importCityGuide(city);
    if (!mounted) return;
    setState(() {
      _committing = false;
      _error = err;
      _done = err == null;
    });
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入「${city['name']}」攻略')));
    }
  }
}
