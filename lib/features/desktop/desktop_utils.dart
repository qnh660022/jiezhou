/// 桌面 Web 布局的通用工具。
library;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 是否为「桌面 Web 大屏」：仅 Web 端且窗口宽度 >= 1024 时启用桌面布局。
/// 安卓 / 桌面原生 / 窄屏 Web 一律走移动布局 → 保证安卓零回归。
bool isDesktopWeb(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= DesktopLayout.breakpoint;

/// 在桌面态把现有全屏页面/编辑屏以居中 Dialog 打开（复用既有页面，勿重写）。
Future<T?> openAsDialog<T>(
  BuildContext context,
  Widget child, {
  double width = DesktopLayout.dialogWidth,
  bool barrierDismissible = true,
}) {
  final size = MediaQuery.sizeOf(context);
  final scheme = Theme.of(context).colorScheme;
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black54,
    barrierDismissible: barrierDismissible,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(
          horizontal: DesktopLayout.dialogInset, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width,
            maxHeight: size.height * 0.86,
          ),
          child: Material(color: scheme.surface, child: child),
        ),
      ),
    ),
  );
}