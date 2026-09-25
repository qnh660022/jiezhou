/// 窄窗拦截页：Web 版仅支持桌面宽屏布局。
///
/// 两种场景（V2.9.0 起区分文案，此前桌面窄窗也提示「请使用电脑浏览器」自相矛盾）：
/// * 手机浏览器打开 → 引导使用电脑或前往官网下载 APK；
/// * 桌面浏览器窗口过窄 → 提示拉宽窗口即可进入。
library;
import 'package:flutter/material.dart';

import '../../platform/open_external.dart';
import '../../shared/app_meta.dart';
import '../../theme/tokens.dart';

/// 官网下载页地址（Flutter 侧兜底拦截页跳转用；
/// 首屏 HTML 层的拦截在 web/index.html，两处口径保持一致）。
const String kWebsiteDownloadUrl = kOfficialWebsite;

class MobileNotSupportedScreen extends StatelessWidget {
  const MobileNotSupportedScreen({super.key, this.narrowDesktop = false});

  /// true = 桌面浏览器窗口过窄（提示拉宽）；false = 手机浏览器（引导下载）。
  final bool narrowDesktop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: CoverGradients.forest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    narrowDesktop
                        ? Icons.desktop_windows_rounded
                        : Icons.smartphone_rounded,
                    size: 34,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                    narrowDesktop
                        ? '浏览器窗口太窄了'
                        : 'Web 版暂不支持手机端访问',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 12),
                Text(
                    narrowDesktop
                        ? '芥舟 Web 版为桌面宽屏布局，\n请把窗口拉宽到 1024px 以上再访问。'
                        : '请使用电脑浏览器访问，\n或前往官网下载 APK 安装到手机。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.6, color: scheme.onSurfaceVariant)),
                if (!narrowDesktop) ...[
                  const SizedBox(height: 28),
                  if (kWebsiteDownloadUrl.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () => openExternal(kWebsiteDownloadUrl),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14)),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text('前往官网下载 APK'),
                    )
                  else
                    Text('官网地址配置中…',
                        style:
                            TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
