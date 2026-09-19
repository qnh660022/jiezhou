/// 行程详情页签栏（V2.8.2 S5 · B5 仅页签层）。
///
/// 从 V2.7.2 的裸 `TabBar` 下沉为独立组件（偏差登记选型：组件下沉）：
/// * 玻璃吸顶底座：`GlassSurface(navBar)` + 圆角 18；
/// * 内滑移选中胶囊：主色填充，位置跟随 `controller.animation` 连续滑移，
///   点按 animateTo 用 240ms easeOutCubic（规格口径）；
/// * 四页签 icon = `AppIcons.clock/clip/bolt/bag` + 文字；
/// * viewer 与 editor 页签可见性维持 V2.7.2 口径（由宿主决定传入哪些页签）；
/// * 页签切换无内容转场动画（保持 V2.7.2 行为，仅选中胶囊滑移）。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/glass_surface.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/tokens.dart';

/// 行程详情四页签（时间轴 / 大纲 / 装配 / 锦囊）的玻璃 SegmentedTab。
///
/// 实现 [PreferredSizeWidget]：可直接放进 `GlassAppBar(bottom:)`。
class TripDetailTabs extends StatefulWidget implements PreferredSizeWidget {
  const TripDetailTabs({
    super.key,
    required this.controller,
    this.height = 44,
    this.horizontalPadding = 12,
  });

  final TabController controller;

  /// 胶囊条自身高度（不含外边距）。
  final double height;

  /// 左右留白（玻璃条与 AppBar 边缘的间距）。
  final double horizontalPadding;

  /// 页签定义（icon + 文字）。默认四页签；宿主可按 viewer/editor 口径裁剪。
  static const List<({IconData icon, String label})> kTabs = [
    (icon: AppIcons.clock, label: '时间轴'),
    (icon: AppIcons.clip, label: '大纲'),
    (icon: AppIcons.bolt, label: '装配'),
    (icon: AppIcons.bag, label: '锦囊'),
  ];

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  State<TripDetailTabs> createState() => _TripDetailTabsState();
}

class _TripDetailTabsState extends State<TripDetailTabs> {
  void _select(int index) {
    HapticFeedback.selectionClick();
    widget.controller.animateTo(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = TripDetailTabs.kTabs;
    assert(
      widget.controller.length == tabs.length,
      'TripDetailTabs 页签数与 TabController.length 不一致',
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding, 0, widget.horizontalPadding, 6),
      child: GlassSurface(
        level: GlassLevel.navBar,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: widget.height,
          child: Material(
            type: MaterialType.transparency,
            child: LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth / tabs.length;
              return AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  final pos =
                      (widget.controller.animation?.value ??
                              widget.controller.index.toDouble())
                          .clamp(0.0, (tabs.length - 1).toDouble());
                  return Stack(
                    children: [
                      // 内滑移选中胶囊（主色填充，位置随 controller 连续插值）
                      Positioned(
                        left: pos * w + 4,
                        width: w - 8,
                        top: 4,
                        bottom: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            SizedBox(
                              width: w,
                              height: widget.height,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _select(i),
                                child: IconTheme.merge(
                                  data: IconThemeData(
                                    size: 16,
                                    color: i == widget.controller.index
                                        ? scheme.onPrimary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  child: DefaultTextStyle.merge(
                                    style: TextStyle(
                                      fontSize: AppFontSizes.caption,
                                      fontWeight: i == widget.controller.index
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: i == widget.controller.index
                                          ? scheme.onPrimary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(tabs[i].icon),
                                        const SizedBox(height: 1),
                                        Text(tabs[i].label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}
