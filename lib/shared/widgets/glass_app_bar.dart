import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// 毛玻璃吸顶导航栏：
/// - BackdropFilter 实时模糊 + 半透明表面色，覆盖状态栏区域；
/// - 可选 [largeTitle]：传入 [scrollController] 后随滚动收缩为居中标题（iOS 风）。
class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.largeTitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.scrollController,
  });

  final String? title;
  final String? largeTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  /// 绑定页面主滚动控制器后启用大标题收缩动效
  final ScrollController? scrollController;

  /// 大标题区高度：34 号 display 字 + 底部 Spacing.xs 余量，
  /// 留足字体度量浮动空间（配合 FittedBox 兜底），避免 BOTTOM OVERFLOWED 条纹。
  static const double _largeTitleArea = 50;

  /// 底部描边宽度：Container 的 border 会从内部布局中扣除对应像素，
  /// 若不计入 preferredSize.height，标题工具条会被压出 0.6px 的 BOTTOM OVERFLOWED 条纹。
  static const double _bottomBorderWidth = 0.6;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight +
        _bottomBorderWidth +
        (largeTitle != null ? _largeTitleArea : 0) +
        (bottom?.preferredSize.height ?? 0),
      );

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends State<GlassAppBar> {
  /// 滚动偏移走 ValueNotifier：滚动帧只重建标题相关子树，
  /// 不再 setState 整个 AppBar（消除失活元素被标记重建的框架断言隐患）。
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _bind(widget.scrollController);
    _syncOffset();
  }

  @override
  void didUpdateWidget(covariant GlassAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _unbind(oldWidget.scrollController);
      _bind(widget.scrollController);
      _syncOffset();
    }
  }

  @override
  void dispose() {
    _unbind(widget.scrollController);
    _offset.dispose();
    super.dispose();
  }

  void _bind(ScrollController? c) {
    if (c == null) return;
    c.addListener(_syncOffset);
  }

  void _unbind(ScrollController? c) {
    if (c == null) return;
    c.removeListener(_syncOffset);
  }

  void _syncOffset() {
    final c = widget.scrollController;
    _offset.value = (c != null && c.hasClients) ? c.offset : 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusBar = MediaQuery.paddingOf(context).top;
    final compactTitle = widget.title ?? widget.largeTitle ?? '';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
                width: GlassAppBar._bottomBorderWidth,
              ),
            ),
          ),
          height: widget.preferredSize.height + statusBar,
          padding: EdgeInsets.only(top: statusBar),
          child: Column(
            children: [
              SizedBox(
                height: kToolbarHeight,
                child: NavigationToolbar(
                  leading: widget.leading ??
                      ((widget.automaticallyImplyLeading && Navigator.canPop(context))
                          ? BackButton(color: scheme.onSurface)
                          : null),
                  middle: widget.largeTitle == null
                      ? _buildCompactTitle(context, compactTitle, 1)
                      : ValueListenableBuilder<double>(
                          valueListenable: _offset,
                          builder: (context, offset, _) => _buildCompactTitle(
                              context, compactTitle, (offset / 36).clamp(0.0, 1.0)),
                        ),
                  trailing: widget.actions == null
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: widget.actions!),
                  centerMiddle: true,
                  middleSpacing: Spacing.sm,
                ),
              ),
              if (widget.largeTitle != null)
                // Loose Flexible：父层高度被边框等扣除亚像素时（如测试字体度量），
                // 标题区按剩余空间收缩，杜绝 BOTTOM OVERFLOWED 断言。
                Flexible(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _offset,
                    builder: (context, offset, _) {
                      final t = (offset / 36).clamp(0.0, 1.0);
                      return SizedBox(
                        height: GlassAppBar._largeTitleArea,
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(0, 6 * t),
                            child: Opacity(
                              opacity: 1 - t,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    Spacing.xl, 0, Spacing.xl, Spacing.xs),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.largeTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.display(scheme),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (widget.bottom != null) widget.bottom!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTitle(BuildContext context, String text, double t) {
    return Opacity(
      opacity: t,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).appBarTheme.titleTextStyle,
      ),
    );
  }
}
