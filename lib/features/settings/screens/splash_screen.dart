import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/theme_provider.dart';
import '../../../theme/tokens.dart';

/// 开屏页：渐变圆 Logo 分层入场，短暂停留后自动进入行程 Tab。
///
/// 路由位于 `/`（顶层，不在底部导航壳内），到时 context.go('/trips')
/// 以替换语义离开，返回键不会回到本页。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// 开屏总停留时长：入场动画 600ms + 品牌展示缓冲
  static const Duration splashDuration = Duration(milliseconds: 1200);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // 单一时间轴 600ms：Logo 全程缩放淡入，文案按 Interval 错峰入场
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<double> _logoScale =
      Tween<double>(begin: 0.6, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _titleAnimation = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _subtitleAnimation = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
  );

  // 停留计时用第二时间轴驱动：与 vsync 帧同步推进，避免裸 Timer 在
  // 动画结束到触发之间产生无帧空窗（widget 测试的 pumpAndSettle 会
  // 提前返回，真机上亦消除对 wall-clock 的依赖）。
  late final AnimationController _dwell;

  @override
  void initState() {
    super.initState();
    _dwell = AnimationController(
      vsync: this,
      duration: SplashScreen.splashDuration,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _enterApp();
      })
      ..forward();
  }

  void _enterApp() {
    if (!mounted) return;
    // 停留期内用户可能已通过底部胶囊导航切走（过渡帧里 HomeShell 与本页
    // 同树共存）：当前路由不再是 '/' 时放弃跳转，避免把用户拽回行程 Tab。
    if (GoRouterState.of(context).uri.path != '/') return;
    context.go('/trips');
  }

  @override
  void dispose() {
    _dwell.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 跟随全局主题：surface 底色与用户所选配色一致，衔接原生启动底色
    ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变圆 Logo：primary -> tertiary，内放 ✈️
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.32),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('✈️', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            // 主标题：延迟淡入 + 上滑
            FadeTransition(
              opacity: _titleAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.45),
                  end: Offset.zero,
                ).animate(_titleAnimation),
                child:
                    Text('旅途助手', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            // 副标题：更晚一拍淡入
            FadeTransition(
              opacity: _subtitleAnimation,
              child: Text(
                '记录每一段旅途',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
