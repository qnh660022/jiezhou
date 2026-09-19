import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/money_expression.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../theme/tokens.dart';

/// V2.8.1 S5：记账自定义键盘（玻璃 sheet 档，4×4）。
///
/// `7 8 9 ⌫ / 4 5 6 ＋ / 1 2 3 － / . 0 备注 完成✓`
/// * 键帽 ≥48 逻辑像素高；
/// * `+ −` 长按无效（防误触连发）；
/// * ⌫ 长按 300ms 起以 80ms 连删。
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onOp,
    required this.onDot,
    required this.onNote,
    required this.onDone,
    this.doneEnabled = true,
    this.hasNote = false,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final ValueChanged<MoneyOp> onOp;
  final VoidCallback onDot;
  final VoidCallback onNote;

  /// 「完成」= 保存（键盘即保存，全页无第二个保存主按钮）。
  final VoidCallback onDone;
  final bool doneEnabled;
  final bool hasNote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const keyRadius = 14.0;
    Widget keyCap({
      required Widget child,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      Color? color,
      Color? foreground,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Material(
            // V2.8.3.1：键帽改实色 —— 半透明键帽叠在玻璃 Sheet 上会发灰
            //（玻璃叠玻璃反模式），核心记账流程主视觉优先保对比。
            color: color ?? scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(keyRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: SizedBox(
                height: 52,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      );
    }

    Text keyText(String t, {double size = 22, FontWeight w = FontWeight.w600}) =>
        Text(t,
            style: TextStyle(
                fontSize: size,
                fontWeight: w,
                color: scheme.onSurface,
                height: 1.0));

    return GlassSurface(
      level: GlassLevel.sheet,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                for (final d in const [7, 8, 9])
                  keyCap(
                      child: keyText('$d'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onDigit(d);
                      }),
                keyCap(
                  child: Icon(Icons.backspace_outlined,
                      size: 22, color: scheme.onSurface),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onBackspace();
                  },
                  onLongPress: () {}, // 实际连删由内部计时器处理（见 _BackspaceKey）
                ),
              ]),
              Row(children: [
                for (final d in const [4, 5, 6])
                  keyCap(
                      child: keyText('$d'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onDigit(d);
                      }),
                keyCap(
                  child: keyText('＋', size: 24),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onOp(MoneyOp.add);
                  },
                  // 长按无效：不给 onLongPress 即可（防误触连发）
                ),
              ]),
              Row(children: [
                for (final d in const [1, 2, 3])
                  keyCap(
                      child: keyText('$d'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onDigit(d);
                      }),
                keyCap(
                  child: keyText('－', size: 24),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onOp(MoneyOp.subtract);
                  },
                ),
              ]),
              Row(children: [
                keyCap(
                  child: keyText('.', size: 26, w: FontWeight.w800),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onDot();
                  },
                ),
                keyCap(
                  child: keyText('0'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onDigit(0);
                  },
                ),
                keyCap(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sticky_note_2_outlined,
                          size: 18, color: hasNote ? scheme.primary : scheme.onSurface),
                      Text('备注',
                          style: TextStyle(
                              fontSize: 9.5,
                              color:
                                  hasNote ? scheme.primary : scheme.onSurfaceVariant)),
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onNote();
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    child: Semantics(
                      button: true,
                      label: '完成并保存',
                      child: Material(
                        color: doneEnabled
                            ? scheme.primary
                            : scheme.primary.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(keyRadius),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          // 校验失败也要给按序提示（规格 8.5-1），故完成键始终可点
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onDone();
                          },
                          child: const SizedBox(
                            height: 52,
                            child: Center(
                              child: Icon(Icons.check_rounded,
                                  size: 26, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// ⌫ 长按连删：300ms 起以 80ms 连删（包在 AmountKeypad 的 ⌫ 键外使用）。
class BackspaceRepeatWrapper extends StatefulWidget {
  const BackspaceRepeatWrapper({
    super.key,
    required this.onBackspace,
    required this.child,
  });

  final VoidCallback onBackspace;
  final Widget child;

  @override
  State<BackspaceRepeatWrapper> createState() => _BackspaceRepeatWrapperState();
}

class _BackspaceRepeatWrapperState extends State<BackspaceRepeatWrapper> {
  Timer? _timer;
  int _ticks = 0;

  void _start() {
    _stop();
    _ticks = 0;
    widget.onBackspace();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      _ticks++;
      if (_ticks >= 4) {
        // 300ms 后进入连删（4×80ms − 首次立即删除 ≈ 300ms）
        HapticFeedback.selectionClick();
        widget.onBackspace();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: widget.child,
    );
  }
}
