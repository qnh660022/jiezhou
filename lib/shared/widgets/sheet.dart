import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import 'glass_surface.dart';

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
    // 使用根 Navigator，确保抽屉盖在 HomeShell 的悬浮底栏之上。
    // 否则分支 Navigator 的 modal 会被 bottomNavigationBar 遮住。
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // V2.8.1 S2：barrier 0.4 → 0.32（预览图的 barrier 模糊为浏览器演示效果，
    // Flutter 端全屏 BackdropFilter 成本过高，不做 —— 偏差登记）。
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        snap: true,
        // 允许用户从初始高度继续上划到最大高度，长操作菜单不会被
        // initialChildSize 卡住；内容列表仍需使用 builder 提供的 controller。
        snapSizes: [minChildSize, initialChildSize, maxChildSize],
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
    // V2.8.1 S2：α0.98 手写底面 → GlassSurface(sheet)。
    // 解决 2026-09-13「字与底面重叠」的正确姿势：σ28 强模糊 + 饱和补偿，非堆不透明度。
    return GlassSurface(
      level: GlassLevel.sheet,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadius.cardValue)),
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
            // V2.8.1 S6：玻璃底面是带色 DecoratedBox，ListTile/InkWell 的水波纹
            // 需要最近的 Material 祖先 —— 内层补一层透明 Material。
            Expanded(
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// 无滚动的底部面板表面：圆角 24 + 表面色（近不透明）。
///
/// 全局 bottomSheetTheme 是透明的（玻璃拟态），直接用 showModalBottomSheet
/// 弹自制内容时必须包一层 [SheetSurface]，否则内容与底层页面文字重叠
/// （2026-09-13 用户反馈「字与底面重叠」的根因）。
/// 内容需要拖拽/滚动时改用 [SheetContainer] + showDraggableSheet。
class SheetSurface extends StatelessWidget {
  const SheetSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // V2.8.1 S2：修复其完全无模糊问题 —— 直接 GlassSurface 包装。
    return GlassSurface(
      level: GlassLevel.sheet,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadius.cardValue)),
      child: child,
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
