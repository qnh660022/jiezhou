/// 桌面右键上下文菜单：以鼠标位置弹出（`showMenu`），替代移动端长按抽屉。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopAction {
  const DesktopAction({
    required this.label,
    this.icon,
    this.danger = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool danger;
  final bool enabled;
  final VoidCallback? onTap;
}

/// 在 [globalPosition] 弹出右键菜单。条目点击执行后自动关闭。
Future<void> showDesktopContextMenu(
  BuildContext context, {
  required Offset globalPosition,
  required List<DesktopAction> actions,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay == null || overlay is! RenderBox) return;
  final local = overlay.globalToLocal(globalPosition);
  final scheme = Theme.of(context).colorScheme;
  await showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(local.dx, local.dy, local.dx, local.dy),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: scheme.surfaceContainerLow,
    elevation: 8,
    items: [
      for (final a in actions)
        PopupMenuItem<void>(
          enabled: a.enabled,
          height: 40,
          onTap: a.onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (a.icon != null) ...[
                Icon(a.icon,
                    size: 18,
                    color: a.danger ? scheme.error : scheme.onSurfaceVariant),
                const SizedBox(width: 10),
              ],
              Text(a.label,
                  style: TextStyle(
                      fontSize: 14,
                      color: a.danger ? scheme.error : scheme.onSurface)),
            ],
          ),
        ),
    ],
  );
  HapticFeedback.selectionClick();
}