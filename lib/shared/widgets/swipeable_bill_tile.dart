import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// V2.8.1 S6：可滑动账单行 —— 右滑露出编辑、左滑露出删除。
///
/// * 左右滑动阈值 84 逻辑像素（或快速甩动）；未达阈值回弹 240ms easeOutCubic；
/// * 触发动作时 selectionClick 触觉；
/// * 删除动作由调用方接 L2 危险确认（showDangerConfirm + repo 删 + 墓碑）；
/// * 首页最近账单与本页为同一组件（手势语言统一）。
class SwipeableBillTile extends StatefulWidget {
  const SwipeableBillTile({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.editLabel = '编辑',
    this.deleteLabel = '删除',
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final String deleteLabel;

  /// 滑动触发阈值（逻辑像素）。
  static const double threshold = 84;

  @override
  State<SwipeableBillTile> createState() => _SwipeableBillTileState();
}

class _SwipeableBillTileState extends State<SwipeableBillTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// 拖拽中的实时偏移（含符号：右滑 +）
  double _dx = 0;

  /// 释放时刻的偏移（回弹动画起点）
  double _releasedDx = 0;

  bool _animating = false;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _springBackFrom(double from) {
    setState(() {
      _releasedDx = from;
      _animating = true;
      _dx = 0;
    });
    _spring.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _animating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reveal = _animating ? _releasedDx : _dx;
    return Stack(
      children: [
        // 背景动作层：右滑编辑（mint 主色）、左滑删除（red error）
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: (reveal / SwipeableBillTile.threshold)
                        .clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: scheme.primary),
                          const SizedBox(height: 2),
                          Text(widget.editLabel,
                              style: TextStyle(
                                  fontSize: 11, color: scheme.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: (-reveal / SwipeableBillTile.threshold)
                        .clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: scheme.error),
                          const SizedBox(height: 2),
                          Text(widget.deleteLabel,
                              style: TextStyle(
                                  fontSize: 11, color: scheme.error)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 前景内容层：拖拽跟手，释放后 240ms easeOutCubic 回弹
        AnimatedBuilder(
          animation: _spring,
          builder: (context, child) {
            final offset = _animating
                ? Offset(_releasedDx * (1 - Curves.easeOutCubic.transform(_spring.value)) / 400, 0)
                : Offset(_dx / 400, 0);
            return Transform.translate(
              offset: Offset(offset.dx * 400, 0),
              child: child,
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              if (_animating) _spring.stop();
            },
            onHorizontalDragUpdate: (d) {
              setState(() {
                _dx = (_dx + d.delta.dx).clamp(-140.0, 140.0);
              });
            },
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              final released = _dx;
              if (released > SwipeableBillTile.threshold || v > 700) {
                HapticFeedback.selectionClick();
                widget.onEdit();
              } else if (released < -SwipeableBillTile.threshold || v < -700) {
                HapticFeedback.selectionClick();
                widget.onDelete();
              }
              _springBackFrom(released);
            },
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
