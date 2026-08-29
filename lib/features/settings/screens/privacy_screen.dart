import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/tokens.dart';

/// 「隐私说明」页：向用户说明数据存储与权限使用方式（纯静态文案）。
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlassAppBar(title: '隐私说明'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + Spacing.huge + Spacing.xxl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.card,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我们的承诺', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      '「芥舟」是一款纯本地离线的工具应用。你的行程、清单、账本数据全部存储在你自己的设备上，我们不会收集、上传或共享你的任何个人数据。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          const SectionHeader(title: '数据存储'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.input,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletPoint(text: '行程、清单、账本数据保存在本机数据库（SQLite）中。'),
                    _BulletPoint(text: '外观主题、默认设置等偏好保存在本机。'),
                    _BulletPoint(text: '卸载应用或清除应用数据会一并删除这些记录，请及时备份。'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          const SectionHeader(title: '权限与网络'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.input,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletPoint(text: '相机 / 相册：仅在你想为行程选择图片时使用，图片仅用于应用内展示。'),
                    _BulletPoint(text: '地图：默认不联网；仅当你主动配置并启用在线地图服务时才会发起请求。'),
                    _BulletPoint(text: '导出（PDF / .tav / .tat / CSV）由你主动发起，并经由系统分享给你选择的目标。'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Text(
              '更新日期：2026 年。本说明可能随功能更新而调整。',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
