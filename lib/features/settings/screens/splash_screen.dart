import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../platform/app_lock.dart';
import '../../../theme/theme_provider.dart';
import '../../../shared/copy_tokens.dart';
import '../../../shared/widgets/brand_waves.dart';
import '../../../theme/tokens.dart';

/// 开屏页：青山 Logo 分层入场，短暂停留后自动进入行程 Tab。
///
/// 路由位于 `/`（顶层，不在底部导航壳内），到时 context.go('/trips')
/// 以替换语义离开，返回键不会回到本页。
/// V2.8.3.5：品牌图形由代码绘制的舟形（_BoatStroke）改为用户提供的青山
/// Logo 资源图 `assets/img/logo.png`；入场节奏、光环扩散、双波纹母题不变。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// 开屏总停留时长：入场动画 600ms + 品牌展示缓冲
  static const Duration splashDuration = Duration(milliseconds: 1200);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // V2.8.2 S2：900ms（舟身描边生长 900ms easeOutCubic）；总停留 1200ms 不变
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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

  // 简洁风附加动效：Logo 入场时向外扩散一圈淡淡的光环（一次性，不循环，
  // 不增加无谓的常驻动画 —— 保持 pumpAndSettle 可收敛）。
  late final Animation<double> _ringScale = Tween<double>(begin: 0.62, end: 2.1).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.72, curve: Curves.easeOutCubic),
    ),
  );

  late final Animation<double> _ringFade = Tween<double>(begin: 0.5, end: 0.0).animate(
    CurvedAnimation(parent: _controller, curve: const Interval(0.25, 1.0)),
  );

  // V2.8.2 S2：双波纹扩散（错峰 Interval，于 1200ms 停留内收敛）
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

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

  Future<void> _enterApp() async {
    if (!mounted) return;
    // 停留期内用户可能已通过底部胶囊导航切走（过渡帧里 HomeShell 与本页
    // 同树共存）：当前路由不再是 '/' 时放弃跳转，避免把用户拽回行程 Tab。
    if (GoRouterState.of(context).uri.path != '/') return;
    // V2.7.1 S7.2：冷启动读一次启动锁状态（失败/无插件一律视为未开启）。
    // 与 `appLockRedirect` 是同一判据的两次读取，二者不会互相打架：
    // 这里只负责「首跳去哪」，redirect 负责「拦住任何其它入口」。
    await AppLockGate.load();
    if (!mounted) return;
    context.go(AppLockGate.locked ? '/lock' : '/trips');
  }

  @override
  void dispose() {
    _waves.dispose();
    _dwell.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 跟随全局主题：surface 底色与用户所选配色一致，衔接原生启动底色
    ref.watch(themeProvider);
    final scheme = Theme.of(context).colorScheme;

    // V2.8.2 S2：底色 primary 4% → surface 垂直渐变
    return Scaffold(
      body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary.withValues(alpha: 0.04),
            scheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变圆 Logo：primary -> tertiary，内放 ✈️；光环扩散一圈后淡出
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 外层扩散光环（一次入场完成，见 _ringScale/_ringFade）
                  FadeTransition(
                    opacity: _ringFade,
                    child: ScaleTransition(
                      scale: _ringScale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // V2.8.3.5：青山 Logo（用户提供，透明底圆角方形）；光环扩散保留
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.22),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.asset(
                            'assets/img/logo.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
                    Text('芥舟', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            // 副标题：更晚一拍淡入（芥舟品牌诗句）
            FadeTransition(
              opacity: _subtitleAnimation,
              child: Text(
                copy(CopyTokens.splashSubtitle),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            // V2.8.2 S2：双波纹母题（错峰展开，opacity 16%）
            AnimatedBuilder(
              animation: _waves,
              builder: (context, _) => SizedBox(
                width: 220,
                child: BrandWaves(
                  progress: Curves.easeOutCubic.transform(_waves.value),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
