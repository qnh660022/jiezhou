import 'package:flutter/material.dart';

import '../platform/open_external.dart';
import 'app_meta.dart';

/// 「检查更新」弹窗：展示当前版本，最新版本与下载以官网为准。
/// 官网按钮在 Android/iOS 上通过系统浏览器打开，Web 上开新标签页。
Future<void> showCheckUpdateDialog(BuildContext context) async {
  final scheme = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('检查更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前版本：$kAppVersionLabel'),
          const SizedBox(height: 12),
          Text(
            '最新版本与安装包请以官网发布为准',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.link, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  kOfficialWebsite,
                  style: Theme.of(dialogContext)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            openExternal(kOfficialWebsite);
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('前往官网'),
        ),
      ],
    ),
  );
}