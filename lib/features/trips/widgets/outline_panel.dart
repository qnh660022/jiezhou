/// 大纲页签面板（V2.7.2 S3，三宿主共用）。
///
/// 结构：上部多行文本域（等宽字体，初值 = 导出文本）+ 下部操作条；
/// 导入模式：追加 / 覆盖整程（强确认：列明删除 X 张、重建 Y 张 + 勾选
/// 「我已了解该操作不可恢复」方可确认）。
///
/// 本组件保持「哑」：文本初值、现有卡名（去重）、实际执行均由宿主注入
/// （[onApply] / [existingNamesByDay] / [currentCardCount]），便于三宿主与
/// 空间只读态复用。viewer：文本域只读、无导入按钮。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/outline_parser.dart';
import '../../../theme/tokens.dart';

/// 导入执行结果（宿主回填，用于导入报告）。
class OutlineImportReportView {
  const OutlineImportReportView({
    required this.added,
    required this.skipped,
    required this.invalid,
    required this.pooled,
    this.removed = 0,
  });

  /// 新建卡数
  final int added;

  /// 同名同天跳过数
  final int skipped;

  /// 无效行原文
  final List<String> invalid;

  /// 入池（含挂起）条目数
  final int pooled;

  /// 覆盖模式删除的旧卡数
  final int removed;
}

class OutlinePanel extends StatefulWidget {
  const OutlinePanel({
    super.key,
    required this.initialText,
    required this.existingNamesByDay,
    required this.currentCardCount,
    required this.onApply,
    this.canWrite = true,
    this.wishlistSlot,
    this.prefersReducedMotion = false,
  });

  final String initialText;

  /// 各天（1..N）已有卡名（trim 后）——同名同天去重数据源
  final Map<int, Set<String>> existingNamesByDay;
  final int currentCardCount;

  /// 宿主执行入口：解析、去重计划已在面板完成，这里负责落库并回填报告。
  /// 覆盖模式必须在宿主侧以单事务完成（逐行墓碑 → 建新卡）。
  final Future<OutlineImportReportView> Function(String text, {required bool overwrite})
      onApply;

  final bool canWrite;

  /// 侧栏想去池迷你列表（S6 接线；null = 不渲染）
  final Widget? wishlistSlot;
  final bool prefersReducedMotion;

  @override
  State<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends State<OutlinePanel> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final editor = _buildEditor(context, scheme);
      final actions = _buildActions(context, scheme);
      final pool = widget.wishlistSlot;
      final body = wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: editor),
                if (pool != null) ...[
                  const SizedBox(width: Spacing.md),
                  SizedBox(width: 240, child: pool),
                ],
              ],
            )
          : Column(children: [editor, if (pool != null) pool]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: body),
          if (widget.canWrite) actions,
        ],
      );
    });
  }

  Widget _buildEditor(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        readOnly: !widget.canWrite,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: ['Courier New', 'monospace'],
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: 'D1\n09:00 西湖 2h\n灵隐寺 半天\n\nD2\n14:00 返程',
          hintStyle: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontFamily: 'monospace'),
          filled: true,
          fillColor: scheme.surfaceContainerLowest,
          border: OutlineInputBorder(borderRadius: AppRadius.input),
          contentPadding: const EdgeInsets.all(Spacing.lg),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('复制大纲'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _controller.text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('大纲已复制')));
                }
              },
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.input_rounded, size: 18),
              label: const Text('导入'),
              onPressed: () => _onImport(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onImport(BuildContext context) async {
    final parsed = parseOutline(_controller.text);
    final plan = planOutlineImport(
      parsed,
      existingNamesByDay: widget.existingNamesByDay,
    );
    final overwrite = await _pickMode(context, plan);
    if (overwrite == null || !context.mounted) return;
    if (overwrite) {
      final ok = await _confirmOverwrite(context, plan);
      if (ok != true || !context.mounted) return;
    }
    final report = await widget.onApply(_controller.text, overwrite: overwrite);
    if (!context.mounted || report == null) return;
    final invalidText = report.invalid.isEmpty
        ? ''
        : '\n无效 ${report.invalid.length} 行：${report.invalid.take(3).join('、')}'
            '${report.invalid.length > 3 ? ' …' : ''}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          '新增 ${report.added} · 跳过重复 ${report.skipped} · 入池 ${report.pooled}'
          '${report.removed > 0 ? ' · 删除旧卡 ${report.removed}' : ''}'
          '$invalidText',
        ),
      ));
  }

  /// true = 覆盖整程；false = 追加；null = 取消
  Future<bool?> _pickMode(BuildContext context, OutlineImportPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.cardValue)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('导入大纲',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: Spacing.xs),
              Text(
                '解析出 ${plan.cardCount} 张卡、${plan.toPool.length} 条无天头（将入想去池）、'
                '${plan.skippedDuplicates.length} 条重复跳过、${plan.invalidLines.length} 行无效',
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.md),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('追加到现有安排'),
                subtitle: const Text('保留现有卡，按大纲新增'),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
              ListTile(
                leading: Icon(Icons.restart_alt_rounded, color: scheme.error),
                title: Text('覆盖整程',
                    style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700)),
                subtitle: const Text('删除全部现有卡后按大纲重建'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmOverwrite(BuildContext context, OutlineImportPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    var acknowledged = false;
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('覆盖整程'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将删除现有 $currentCardCountLabel 张卡，'
                '并按大纲重建 ${plan.cardCount} 张。该操作不可恢复。',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.md),
              CheckboxListTile(
                value: acknowledged,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: scheme.error,
                title: const Text('我已了解该操作不可恢复'),
                onChanged: (v) => setDialogState(() => acknowledged = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: acknowledged ? scheme.error : scheme.onSurfaceVariant,
              ),
              onPressed:
                  acknowledged ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('确认覆盖'),
            ),
          ],
        ),
      ),
    );
  }

  String get currentCardCountLabel => '${widget.currentCardCount}';
}
