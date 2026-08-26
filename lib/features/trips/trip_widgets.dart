// 行程线特性内通用小件：动效、卡片容器、抽屉动作项、表单包装。
// 仅服务 lib/features/trips/**；若需升级为全 App 通用组件，向队长申请后迁入 lib/shared/widgets/。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';
import '../../shared/widgets/sheet.dart';
import '../../theme/tokens.dart';

/// 列表条目 stagger 入场：透明度 0→1 + 上移归位，按 index 级联延迟
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  /// 延迟入场计时器：可取消，State 销毁后不再触发回调（Future.delayed 无法撤销）
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(
      Duration(milliseconds: 55 * math.min(widget.index, 10)),
      () { if (mounted) _controller.forward(); },
    );
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.07),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// 滚动视差：child 随页面滚动做反向轻位移（封面大 emoji 专属质感）
class ParallaxBox extends StatelessWidget {
  const ParallaxBox({
    super.key,
    required this.scrollController,
    required this.child,
    this.speed = 0.16,
    this.maxShift = 26,
  });

  final ScrollController scrollController;
  final Widget child;
  final double speed;
  final double maxShift;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        double shift = 0;
        final box = context.findRenderObject();
        if (box is RenderBox && box.hasSize && scrollController.hasClients) {
          final dy = box.localToGlobal(Offset.zero).dy;
          shift = (-dy * speed).clamp(-maxShift, maxShift);
        }
        return Transform.translate(offset: Offset(0, shift), child: child);
      },
    );
  }
}

/// 区块卡片容器：圆角 24 + 细描边 + 轻投影
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        borderRadius: AppRadius.card,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}


/// 底部抽屉里的整行动作项（图标圆底 + 标题 + 说明），danger 时转错误色
class SheetActionTile extends StatelessWidget {
  const SheetActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = danger ? scheme.error : scheme.primary;
    final onTone = danger ? scheme.onError : scheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.input,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: tone),
                  child: Icon(icon, size: 20, color: onTone),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: AppFontSizes.bodyLarge,
                              fontWeight: FontWeight.w600,
                              color: danger ? scheme.error : scheme.onSurface)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: AppFontSizes.caption,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 危险操作二次确认抽屉（统一走底部抽屉脸，不用系统对话框）
Future<void> showDangerConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
  required Future<void> Function() onConfirm,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showDraggableSheet(
    context: context,
    initialChildSize: 0.42,
    minChildSize: 0.32,
    builder: (sheetContext, _) => Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 46)),
          const SizedBox(height: Spacing.md),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: Spacing.sm),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Spacing.xxl),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: '取消',
                  expanded: true,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: PrimaryButton(
                  label: confirmLabel,
                  expanded: true,
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await onConfirm();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


/// 「标签 + 内容」纵向表单包装
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: AppFontSizes.caption,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.2)),
        const SizedBox(height: Spacing.sm),
        SizedBox(width: double.infinity, child: child),
      ],
    );
  }
}

/// 类型色节点圆点（时间轴 / 地图图例共用）
class TypeDot extends StatelessWidget {
  const TypeDot({
    super.key,
    required this.color,
    required this.icon,
    this.size = 40,
  });

  final Color color;
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Text(icon, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// 迷你数字步进器（时长等场景）
class MiniStepper extends StatelessWidget {
  const MiniStepper({
    super.key,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
  });

  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.button,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              valueText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSizes.body,
                fontWeight: FontWeight.w600,
                fontFeatures: AppTextStyles.tabularFigures,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
