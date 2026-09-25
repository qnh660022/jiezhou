import 'package:flutter/material.dart';

import 'empty_state.dart';

/// 加载失败统一形态（V2.9.0）：错误图标 + 固定标题 + 友好文案 + 可选重试。
///
/// 收口此前各页自绘的「加载失败 / 加载失败了 / 成员加载失败」三口径，并
/// 杜绝两处反模式：错误分支无重试按钮却提示「下拉重试」、把
/// `snapshot.error.toString()` 原始异常直接拼给用户。原始异常只进调试日志。
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = '加载失败了',
    this.message = '数据暂时取不到，请稍后重试。',
    this.onRetry,
    this.actionLabel,
    this.error,
    this.stackTrace,
  });

  final String title;
  final String message;

  /// 传入即渲染「重试」按钮（[actionLabel] 可覆盖默认文案）。
  final VoidCallback? onRetry;

  final String? actionLabel;

  /// 原始异常（仅调试日志用，绝不进 UI 文案）。
  final Object? error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    assert(() {
      if (error != null) {
        debugPrint('ErrorState: $error\n$stackTrace');
      }
      return true;
    }());
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      actionLabel: onRetry != null ? (actionLabel ?? '重试') : null,
      onAction: onRetry,
    );
  }
}
