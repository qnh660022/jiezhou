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
    // 只会挂一次：预警→系统通知桥 + 汇率静默刷新。
    // FLUTTER_TEST 环境跳过（通知插件无平台通道，测试也不该有网络副作用）。
    if (!_startupAttached) {
      _startupAttached = true;
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        // 挂载整体挪到首帧渲染之后（addPostFrameCallback）：
        // didChangeDependencies 正处于 build 阶段，此时绑定 listenManual
        // 会同步创建 budgetAlertsProvider 依赖图，首帧与 drift 首回流的
        // flush 级联叠在一起，会触发 riverpod 内部对 _dependencies 的
        // 并发修改（Concurrent modification during iteration）。挪出首帧后
        // 依赖图在稳定期创建，竞态窗口自然消除。
        //
        // 整体兜底：挂载链路里任何同步异常（provider 初始化、插件通道等）
        // 都不能打断首帧构建 —— release 模式下首帧管线一旦抛错就永远渲染
        // 不出来，表现为启动后白屏/灰屏直到杀进程。后台服务挂载失败是
        // 可降级的（仅丢通知提醒与汇率刷新），绝不能换来一块白屏。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _closeStartupBridge = attachStartupServices(ref);
          } catch (e) {
            assert(() {
              // ignore: avoid_print
              print('启动服务挂载失败（不影响首帧）：$e');
              return true;
            }());
          }
        });
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
