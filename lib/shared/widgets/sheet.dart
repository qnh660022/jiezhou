import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// 统一底部抽屉入口：全 App 模态一律走这里（带拖拽把手，禁用系统对话框脸）。
///
/// 用法：
/// ```dart
/// showDraggableSheet(
///   context: context,
///   builder: (context, scrollController) => Column(children: [...]),
/// );
/// ```
/// [builder] 返回的内容会被放进可拖拽滚动容器；内容自带滚动时请把
/// [scrollController] 交给你的 ListView/SingleChildScrollView。
Future<T?> showDraggableSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, ScrollController scrollController) builder,
  double initialChildSize = 0.62,
  double minChildSize = 0.35,
  double maxChildSize = 0.94,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        snap: true,
        snapSizes: [minChildSize, initialChildSize],
        builder: (context, scrollController) {
          return SheetContainer(
            scrollController: scrollController,
            child: builder(context, scrollController),
          );
        },
      );
    },
  );
}

/// 抽屉容器：圆角 24 + 表面色 + 顶部拖拽把手 + 键盘避让 + 底部安全区
class SheetContainer extends StatelessWidget {
  const SheetContainer({
    super.key,
    required this.child,
    required this.scrollController,
    this.showHandle = true,
  });

  final Widget child;
  final ScrollController scrollController;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.cardValue)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.98),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.cardValue)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom > MediaQuery.viewInsetsOf(context).bottom
                  ? MediaQuery.viewPaddingOf(context).bottom
                  : MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHandle)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
                    child: SheetHandle(color: scheme.onSurfaceVariant),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 独立拖拽把手（32x4 胶囊）
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 4.5,
      decoration: BoxDecoration(
        color: (color ?? scheme.onSurfaceVariant).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
