/// 启动锁屏（V2.7.1 S7.2 · F3）。路由 `/lock`（顶层，独立于底部 Tab 壳）。
///
/// 行为（规格 §S7.2）：
/// * 仅 6 位数字 PIN，自绘数字键盘（Android / Web 表现一致）；
/// * 连续 5 次失败 → 30s 冷却（禁用输入 + 倒计时），**不擦除任何数据**；
/// * 忘记 PIN → 只能用备份恢复，**无后门、不上云、无找回码**（页面直接写明）；
/// * 动效遵循 `MediaQuery.disableAnimations`（prefers-reduced-motion）。
///
/// 锁屏期间不发起任何同步：本页不读任何同步 Provider，也不触发 syncNow。
library;

import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../platform/app_lock.dart';
import '../../theme/tokens.dart';
import '../../../shared/widgets/brand_waves.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with TickerProviderStateMixin {
  // V2.8.2 S2：错误抖动（整盘 translateX ±6 衰减 320ms）+ 波纹展开
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  String _input = '';
  String _error = '';
  bool _busy = false;
  Timer? _ticker;
  int _cooldownLeftMs = 0;

  @override
  void initState() {
    super.initState();
    _refreshCooldown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshCooldown() async {
    try {
      final svc = await AppLockService.cached();
      final left = svc.cooldownRemainingMs();
      if (!mounted) return;
      setState(() => _cooldownLeftMs = left);
      if (left > 0) {
        _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) async {
          final svc2 = await AppLockService.cached();
          final l = svc2.cooldownRemainingMs();
          if (!mounted) return;
          setState(() => _cooldownLeftMs = l);
          if (l <= 0) {
            _ticker?.cancel();
            _ticker = null;
          }
        });
      } else {
        _ticker?.cancel();
        _ticker = null;
      }
    } catch (_) {
      if (mounted) setState(() => _cooldownLeftMs = 0);
    }
  }

  bool get _coolingDown => _cooldownLeftMs > 0;

  void _push(String digit) {
    if (_busy || _coolingDown || _input.length >= kPinLength) return;
    setState(() {
      _input += digit;
      _error = '';
    });
    if (_input.length == kPinLength) _submit();
  }

  void _backspace() {
    if (_busy || _coolingDown || _input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = '';
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    bool ok = false;
    int failsLeft = kMaxPinFailures;
    try {
      final svc = await AppLockService.cached();
      ok = await svc.verify(_input);
      failsLeft = kMaxPinFailures - svc.failCount;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      AppLockGate.markUnlocked();
      context.go('/trips');
      return;
    }
    setState(() {
      _busy = false;
      _input = '';
      _error = _coolingDown || failsLeft <= 0
          ? '错误次数过多，请稍后再试'
          : 'PIN 不对，还可以再试 $failsLeft 次';
    });
    // V2.8.2 S2 收尾：错误时整盘 ±6 衰减抖动 320ms（disableAnimations 直显）
    final reduceMotionNow =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotionNow) _shake.forward(from: 0);
    await _refreshCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final reduceMotionShake = reduceMotion;
    return Scaffold(
      backgroundColor: scheme.surface,
      // V2.8.3.4：`/lock` 是顶层路由。若允许系统返回键把它 pop 掉，根 Navigator
      // 会立即变成**空栈**——整屏全黑、无法恢复（只能杀进程重开）。锁屏期间
      // 一律吞掉返回手势；离开本页的唯一途径是输对 PIN（`_submit` 里
      // `markUnlocked()` + `go('/trips')`）。
      body: PopScope(
        canPop: false,
        child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text('芥舟已上锁', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            Text('输入 6 位数字 PIN 继续',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.xxl),
            // V2.8.2 S2：错误时整盘 ±6 衰减抖动 320ms（disableAnimations 直显）
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                if (reduceMotionShake || _shake.value == 0) return child!;
                final t = _shake.value;
                final dx = sin(t * pi * 4) * 6 * (1 - t);
                return Transform.translate(
                    offset: Offset(dx, 0), child: child);
              },
              child: _Dots(count: _input.length, error: _error.isNotEmpty),
            ),
            const SizedBox(height: Spacing.md),
            SizedBox(
              height: 24,
              child: _coolingDown
                  ? Text(
                      '尝试过于频繁，请 ${(_cooldownLeftMs / 1000).ceil()} 秒后再试',
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          fontWeight: FontWeight.w700,
                          color: scheme.error),
                    )
                  : Text(
                      _error,
                      style: TextStyle(
                          fontSize: AppFontSizes.caption, color: scheme.error),
                    ),
            ),
            const SizedBox(height: Spacing.lg),
            _Keypad(
              enabled: !_busy && !_coolingDown,
              reduceMotion: reduceMotion,
              onDigit: _push,
              onBackspace: _backspace,
            ),
            const Spacer(),
            // V2.8.2 S2：波纹母题（两道弧线 opacity 16%，与开屏共享组件）
            AnimatedBuilder(
              animation: _waves,
              builder: (context, _) => SizedBox(
                width: 260,
                child: BrandWaves(
                    progress:
                        Curves.easeOutCubic.transform(_waves.value)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
              child: Text(
                '忘了 PIN 只能通过备份恢复数据；芥舟不提供后门、不上云、不设找回码。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppFontSizes.caption,
                    color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: Spacing.xl),
          ],
        ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.error});

  final int count;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kPinLength; i++)
          // V2.8.2 S2：胶囊分段条（26×5，填充段 160ms easeOutBack 生长）
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 26,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i < count
                  ? (error ? scheme.error : scheme.primary)
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                color: i < count
                    ? (error ? scheme.error : scheme.primary)
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.reduceMotion,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final bool reduceMotion;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final rows = const [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final key in row)
                    SizedBox(
                      width: 76,
                      height: 60,
                      child: key.isEmpty
                          ? const SizedBox.shrink()
                          : _KeyButton(
                              label: key,
                              enabled: enabled,
                              reduceMotion: reduceMotion,
                              onTap: key == '<'
                                  ? onBackspace
                                  : () => onDigit(key),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.label,
    required this.enabled,
    required this.reduceMotion,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.enabled;
    final reduceMotion = widget.reduceMotion;
    final isBack = widget.label == '<';
    // V2.8.3.1：实色 mini 键帽 + 按压 scale 0.94 + selectionClick（原玻璃键帽见下注）
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          // V2.8.3.1：去伪玻璃 —— PIN 键盘背景是不透明 surface，玻璃键帽
          // 「无背景可糊」，12 个 BackdropFilter 纯 GPU 开销且观感碎片化；
          // 改实色键帽 + 细描边（与全 App 实色条目语言一致）。
          color: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.buttonValue),
            side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.buttonValue),
              onTapDown:
                  enabled ? (_) => setState(() => _pressed = true) : null,
              onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
              onTapCancel:
                  enabled ? () => setState(() => _pressed = false) : null,
              onTap: enabled
                  ? () {
                      if (!reduceMotion) {
                        HapticFeedback.selectionClick();
                      }
                      widget.onTap();
                    }
                  : null,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: isBack
                      ? Icon(Icons.backspace_outlined,
                          size: 21, color: scheme.onSurface)
                      : Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}
