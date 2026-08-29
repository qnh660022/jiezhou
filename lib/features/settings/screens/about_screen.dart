import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/tokens.dart';

/// 「关于」页：应用信息、功能亮点、数据与隐私、开源致谢、检查更新/反馈。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appName = '旅途助手';
  static const String appVersion = 'v2.1.1';
  static const String appDescription =
      '行程规划、出行清单、多人记账一站式管理，陪你记录每一段旅途。';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const GlassAppBar(title: '关于'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + Spacing.huge + Spacing.xxl,
        ),
        children: [
          // ---- 应用名片 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, 0),
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.card,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primaryContainer,
                      ),
                      child: const Text('✈️', style: TextStyle(fontSize: 42)),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(appName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(appVersion,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: Spacing.md),
                    Text(
                      appDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // ---- 功能亮点 ----
          const SectionHeader(title: '功能亮点'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.input,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: const [
                  _FeatureRow(emoji: '🧳', text: '行程规划：目的地、天数、行程安排与地图'),
                  _FeatureRow(emoji: '📋', text: '出行清单：模板智能导入，打包不遗漏'),
                  _FeatureRow(emoji: '💰', text: '多人 AA 记账：分摊、结算一目了然'),
                  _FeatureRow(emoji: '⏰', text: '预算预警：超支自动提醒'),
                  _FeatureRow(emoji: '🗺️', text: '地图与天气：行程可视化与出行参考'),
                  _FeatureRow(emoji: '📤', text: 'PDF / .tav / .tat 导出，账单 CSV 随时带走'),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // ---- 数据与隐私 ----
          const SectionHeader(title: '数据与隐私'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.input,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.shield_outlined, color: scheme.primary),
                title: const Text('数据只存在你的本机'),
                subtitle: const Text('纯本地离线运行，不上传、不共享你的任何数据'),
                trailing: Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/profile/privacy');
                },
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // ---- 开源致谢 ----
          const SectionHeader(title: '开源致谢'),
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
                    Text('内置字体（Apache-2.0）',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Droid Sans Fallback（简体中文）与 Roboto（西文）用于 PDF 导出与界面排版。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.md),
                    Text('主要开源组件',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Flutter · Riverpod · GoRouter · Drift（SQLite）· flutter_map · fl_chart · pdf · share_plus 等。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // ---- 操作 ----
          const SectionHeader(title: '其他'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('当前已是最新版本')));
                    },
                    icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                    label: const Text('检查更新'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('反馈入口：请通过应用商店留言或联系开发者')));
                    },
                    icon: const Icon(Icons.feedback_outlined, size: 18),
                    label: const Text('意见反馈'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Center(
            child: Text('© 旅途助手 · 陪你记录每一段旅途',
                style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md + 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
