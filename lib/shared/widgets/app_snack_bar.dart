import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// V2.8.1 S3：L1 轻提示 —— 全 App SnackBar 唯一形态。
///
/// 语义左缘条 3.5px：success 收入绿 / destructive error 红 / info 主色。
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackTone tone = SnackTone.info,
  SnackBarAction? action,
}) {
  final scheme = Theme.of(context).colorScheme;
  final toneColor = switch (tone) {
    SnackTone.success => SemanticColors.income,
    SnackTone.destructive => scheme.error,
    SnackTone.info => scheme.primary,
  };
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        duration: const Duration(milliseconds: 2600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: action,
        content: Row(
          children: [
            // 语义左缘条 3.5px
            Container(
              width: 3.5,
              height: 40,
              decoration: BoxDecoration(
                color: toneColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

enum SnackTone { success, destructive, info }
