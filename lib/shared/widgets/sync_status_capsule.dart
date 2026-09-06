/// 首页云同步状态小点（V2.6.1）：账本/行程等页面仅展示一个彩色圆点表示同步状态。
/// 配色（红黄绿灰）：绿=已同步 / 黄=同步中 / 红=失败(offline) / 灰=未登录或云未启用。
/// 文字原则：除「未登录」外尽量不显示文字；点击小点进同步中心。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/sync/sync_control_providers.dart';
import '../../data/sync/sync_models.dart';
import '../../shared/copy_tokens.dart';
import '../../theme/tokens.dart';

/// 状态点颜色（同步中心状态卡、我的页用户卡与全局小点共用同一口径）。
Color syncStatusColor(ColorScheme scheme, SyncStatusKind kind) =>
    switch (kind) {
      SyncStatusKind.syncing => SemanticColors.warning, // 黄：同步中
      SyncStatusKind.offline => SemanticColors.expense, // 红：同步失败
      SyncStatusKind.idle => SemanticColors.income, // 绿：已同步
      SyncStatusKind.signedOut ||
      SyncStatusKind.unconfigured =>
        scheme.outline, // 灰：未登录 / 云未启用
    };

/// 状态文字（idle 且带时间戳时显示"已同步 HH:mm"）。
String syncStatusLabelText(SyncStatus status) {
  if (status.kind == SyncStatusKind.idle && status.lastSyncedAt != null) {
    final last = status.lastSyncedAt!;
    return '${copy('sync.lastSynced')} '
        '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
  }
  return switch (status.kind) {
    SyncStatusKind.unconfigured => copy('sync.status.unconfigured'),
    SyncStatusKind.signedOut => copy('sync.status.signedOut'),
    SyncStatusKind.syncing => copy('sync.status.syncing'),
    SyncStatusKind.idle => copy('sync.status.idle'),
    SyncStatusKind.offline => copy('sync.status.offline'),
  };
}

/// 状态小点 + 可选文字（默认仅未登录态显示「未登录」，其余纯点）。
class SyncStatusCapsule extends ConsumerWidget {
  const SyncStatusCapsule({super.key, this.showTextWhenSignedOut = true});

  /// 未登录时是否附「未登录」小字（页面顶部默认显示，引导点击登录）。
  final bool showTextWhenSignedOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ??
        const SyncStatus(kind: SyncStatusKind.unconfigured);
    final scheme = Theme.of(context).colorScheme;
    final color = syncStatusColor(scheme, status.kind);
    final label = syncStatusLabelText(status);

    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    final showText =
        showTextWhenSignedOut && status.kind == SyncStatusKind.signedOut;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkResponse(
          radius: 24,
          onTap: () => context.push('/profile/cloud/sync'),
          child: Padding(
            padding: EdgeInsets.all(showText ? 4 : 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot,
                if (showText) ...[
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: AppFontSizes.caption,
                          color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
