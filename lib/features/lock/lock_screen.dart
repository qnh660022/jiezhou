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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../platform/app_lock.dart';
import '../../theme/tokens.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
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
    await _refreshCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text('芥舟已上锁', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.sm),
            Text('输入 6 位数字 PIN 继续',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.xxl),
            _Dots(count: _input.length, error: _error.isNotEmpty),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count
                  ? (error ? scheme.error : scheme.primary)
                  : Colors.transparent,
              border: Border.all(
                color: i < count ? scheme.primary : scheme.outlineVariant,
                width: 1.4,
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

class _KeyButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBack = label == '<';
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.buttonValue),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.buttonValue),
          onTap: enabled
              ? () {
                  if (!reduceMotion) {
                    Feedback.forTap(context);
                  }
                  onTap();
                }
              : null,
          child: Center(
            child: isBack
                ? Icon(Icons.backspace_outlined, size: 21, color: scheme.onSurface)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
