import 'package:flutter/material.dart';

import '../platform/open_external.dart';
import 'app_meta.dart';
import 'widgets/sheet.dart';

/// 「检查更新」抽屉：展示当前版本，最新版本与下载以官网为准。
/// 官网按钮在 Android/iOS 上通过系统浏览器打开，Web 上开新标签页。
///
/// V2.8.3.3：由 AlertDialog 改为 L3 操作抽屉。
/// 本组件原是 `lib/shared` 域**唯一**的 AlertDialog —— V2.8.2 B7 的
/// 「全 App 模态唯一形态 = 抽屉」门禁只扫 `lib/features`，故该处被
/// 遗留为存量（V2.8.2 偏差 D-6 自述「建议下版收编」）。现收编，
/// 全仓 AlertDialog 归零。
Future<void> showCheckUpdateDialog(BuildContext context) async {
  await showDraggableSheet<void>(
    context: context,
    initialChildSize: 0.42,
    minChildSize: 0.30,
    maxChildSize: 0.60,
    builder: (sheetContext, scrollController) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
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
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.system_update_alt_rounded,
                      size: 26, color: scheme.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  '检查更新',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '当前版本：$kAppVersionLabel',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  '最新版本与安装包请以官网发布为准',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            scheme.outlineVariant.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 15, color: scheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          kOfficialWebsite,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      openExternal(kOfficialWebsite);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('前往官网'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
