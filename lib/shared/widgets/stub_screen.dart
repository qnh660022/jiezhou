import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_provider.dart';
import 'empty_state.dart';
import 'glass_app_bar.dart';

/// 二级路由占位页：Scaffold + GlassAppBar + 居中空状态（接主题 Provider）
class StubPage extends ConsumerWidget {
  const StubPage({
    super.key,
    required this.title,
    this.emoji = '🚧',
    this.hint = '功能建设中，敬请期待',
  });

  final String title;
  final String emoji;
  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 接入全局主题：切换主题时本页即时跟随
    ref.watch(themeProvider);
    return Scaffold(
      appBar: GlassAppBar(title: title),
      body: EmptyState(emoji: emoji, title: title, message: hint),
    );
  }
}

/// Tab 根占位内容（无 Scaffold，由外壳 HomeShell 提供底栏）
class StubTabBody extends ConsumerWidget {
  const StubTabBody({
    super.key,
    required this.title,
    this.largeTitle,
    this.emoji = '✨',
    this.hint = '从这里开始规划你的旅途吧',
  });

  final String title;
  final String? largeTitle;
  final String emoji;
  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    return Center(
      child: EmptyState(emoji: emoji, title: largeTitle ?? title, message: hint),
    );
  }
}
