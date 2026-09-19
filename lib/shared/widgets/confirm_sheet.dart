import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_icons.dart';
import 'sheet.dart';

/// V2.8.1 S3：L2 确认弹层 —— 替代 AlertDialog 的唯一合法形态。
///
/// 全 App 模态四层语言：
/// * L1 轻提示（showAppSnackBar）
/// * L2 确认（本组件 showConfirmSheet / showDangerConfirm）
/// * L3 操作抽屉（showDraggableSheet 内容自定）
/// * L4 表单抽屉（showDraggableSheet + 表单）
///
/// [body] 在危险确认时必须包含影响数量（强确认口径，debug 断言拦截）；
/// 中性确认无数量语义，不受此约束（偏差登记：规格书原文未区分中性/危险）。
Future<bool> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String body,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool danger = false,
  IconData? icon,
}) {
  assert(
    !danger || RegExp(r'\d').hasMatch(body),
    'L2 强确认口径：danger 弹层的 body 后果行必须包含影响数量（如「删除 3 笔账单」）',
  );
  assert(cancelLabel.isNotEmpty || confirmLabel.isNotEmpty,
      '确认与取消按钮不能同时为空');
  final effectiveIcon = icon ??
      (danger ? AppIcons.trash : AppIcons.check);
  return showDraggableSheet<bool>(
    context: context,
    initialChildSize: 0.38,
    minChildSize: 0.25,
    maxChildSize: 0.55,
    builder: (sheetContext, scrollController) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: danger
                        ? scheme.error.withValues(alpha: 0.12)
                        : scheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(effectiveIcon,
                      size: 26,
                      color: danger ? scheme.error : scheme.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (cancelLabel.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (danger) HapticFeedback.heavyImpact();
                      Navigator.of(sheetContext).pop(true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: danger ? scheme.error : scheme.primary,
                      foregroundColor:
                          danger ? scheme.onError : scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  ).then((v) => v ?? false);
}

/// L2 危险确认快捷入口：红盘 + 红确认钮 + heavyImpact。
Future<bool> showDangerConfirm({
  required BuildContext context,
  required String title,
  required String body,
  String confirmLabel = '删除',
  String cancelLabel = '取消',
  IconData? icon,
}) =>
    showConfirmSheet(
      context: context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      danger: true,
      icon: icon,
    );
