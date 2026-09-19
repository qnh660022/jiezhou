import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import 'glass_surface.dart';

/// V2.8.1 S3：权限两段式引导卡（零新依赖，仅前置说明 UI）。
///
/// 两段式：功能页内嵌玻璃卡说明「用途 + 承诺」，用户点击「去开启」才触发
/// 系统权限弹窗链路（由调用方完成实际申请）；系统弹窗拒绝后降级为页内
/// 提示条（denied 态），不做弹窗轰炸。
///
/// 状态机：未申请（initial）→ 已拒（denied）→ 已开（granted，卡片自隐藏）。
class PermissionPrimer extends StatelessWidget {
  const PermissionPrimer({
    super.key,
    required this.state,
    required this.title,
    required this.description,
    required this.onOpenSettings,
    this.grantedMessage,
    this.icon,
  });

  final PermissionPrimerState state;

  /// 权限名称，如「相机权限」。
  final String title;

  /// 用途与隐私承诺，如「用于扫描邀请二维码，照片与数据不会上传」。
  final String description;

  /// 触发真实权限申请 / 跳系统设置。
  final VoidCallback onOpenSettings;

  /// granted 态的展示文案（null → granted 时整卡隐藏）。
  final String? grantedMessage;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (state == PermissionPrimerState.granted && grantedMessage == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final denied = state == PermissionPrimerState.denied;
    return GlassSurface(
      level: GlassLevel.floatingCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (denied ? scheme.error : scheme.primary)
                    .withValues(alpha: 0.12),
              ),
              child: Icon(
                icon ?? (denied ? Icons.error_outline_rounded : Icons.info_outline_rounded),
                size: 22,
                color: denied ? scheme.error : scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    denied ? '$title · 已被拒绝' : '需要$title',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    denied ? '可在系统设置中手动开启后回到本页' : description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (state == PermissionPrimerState.granted &&
                      grantedMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      grantedMessage!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.primary),
                    ),
                  ],
                ],
              ),
            ),
            if (state != PermissionPrimerState.granted)
              FilledButton.tonal(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onOpenSettings();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(denied ? '去设置' : '去开启'),
              ),
          ],
        ),
      ),
    );
  }
}

enum PermissionPrimerState { initial, denied, granted }
