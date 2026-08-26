import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/tokens.dart';

/// 列表 stagger 入场：淡入 + 轻微上移，按 index 递进延迟（封顶防长列表久等）。
///
/// 用法：包住每个列表项即可，无需外部动画控制器。
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
  });

  /// 列表项序号（决定延迟档位）
  final int index;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  static const double _stepPerIndex = 0.055;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560))
        ..forward();

  /// 每项在总时间轴上的起点区间：index 越大起步越晚，最晚 0.72 处必须开跑
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      (widget.index * _stepPerIndex).clamp(0.0, 0.72),
      1.0,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

/// 区块标题行（屏幕内部小节用，避免与 shared SectionHeader 的边距耦合）
class LedgerSectionTitle extends StatelessWidget {
  const LedgerSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xl, Spacing.xl, Spacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 页面级大标题头部（Tab 根页用；右侧挂操作按钮）
class LedgerLargeHeader extends StatelessWidget {
  const LedgerLargeHeader({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.xl,
        right: Spacing.lg,
        top: MediaQuery.paddingOf(context).top + Spacing.md,
        bottom: Spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.display(Theme.of(context).colorScheme),
            ),
          ),
          if (actions != null)
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
        ],
      ),
    );
  }
}

/// 圆形图标按钮（头部动作位：毛玻璃底 + selectionClick 触觉）
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 21, color: scheme.onSurface),
            ),
          ),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.surface, width: 1.4),
              ),
              constraints: const BoxConstraints(minWidth: 17),
              child: Text(
                badgeCount! > 99 ? '99+' : badgeCount!.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onError,
                ),
              ),
            ),
          ),
      ],
    );
    if (tooltip != null) {
      return Padding(
        padding: const EdgeInsets.only(left: Spacing.sm),
        child: Tooltip(message: tooltip!, child: button),
      );
    }
    return Padding(padding: const EdgeInsets.only(left: Spacing.sm), child: button);
  }
}
