import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'main.dart' show attachStartupServices;
import 'router.dart';
import 'theme/theme_provider.dart';
import 'theme/tokens.dart';

/// 应用入口 Widget：组合路由 + 中文 locale（含控件文案中文委托）+ 全局主题
class TravelAssistantApp extends ConsumerStatefulWidget {
  const TravelAssistantApp({super.key, this.router});

  /// 测试注入用：默认使用全局 [appRouter]；传入独立实例可避免跨测试导航状态污染。
  final GoRouter? router;

  @override
  ConsumerState<TravelAssistantApp> createState() => _TravelAssistantAppState();
}

class _TravelAssistantAppState extends ConsumerState<TravelAssistantApp> {
  bool _startupAttached = false;
  void Function()? _closeStartupBridge;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首帧后挂一次：预警→系统通知桥 + 汇率静默刷新。
    // FLUTTER_TEST 环境跳过（通知插件无平台通道，测试也不该有网络副作用）。
    if (!_startupAttached) {
      _startupAttached = true;
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        _closeStartupBridge = attachStartupServices(ref);
      }
    }
  }

  @override
  void dispose() {
    _closeStartupBridge?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeKey = ref.watch(themeProvider);
    final isDark = themeKey == ThemeKeys.dark;
    final isSystem = themeKey == ThemeKeys.system;
    return MaterialApp.router(
      title: '旅途助手',
      debugShowCheckedModeBanner: false,
      routerConfig: widget.router ?? appRouter,
      // theme: 浅色基准——选中石墨夜或跟随系统时给默认薄荷绿浅色方案
      theme: buildAppTheme(isDark || isSystem ? ThemeKeys.green : themeKey),
      darkTheme: buildAppTheme(ThemeKeys.dark),
      themeMode:
          isDark ? ThemeMode.dark : (isSystem ? ThemeMode.system : ThemeMode.light),
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
