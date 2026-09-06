/// 首页云状态胶囊（V2.6 §3.17.3）：灰=未登录未配置 / 黄=offline / 蓝=syncing / 绿=idle。
/// 账本首页与行程首页顶部各一枚，点击进同步中心。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/sync/sync_control_providers.dart';
import '../../data/sync/sync_models.dart';
import '../../shared/copy_tokens.dart';
import '../../theme/tokens.dart';

class SyncStatusCapsule extends ConsumerWidget {
  const SyncStatusCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ??
        const SyncStatus(kind: SyncStatusKind.unconfigured);
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status.kind) {
      SyncStatusKind.unconfigured => (scheme.outline, copy('sync.status.unconfigured')),
      SyncStatusKind.signedOut => (scheme.outline, copy('sync.status.signedOut')),
      SyncStatusKind.syncing => (const Color(0xFF2F80ED), copy('sync.status.syncing')),
      SyncStatusKind.idle => (const Color(0xFF1E9E6A), copy('sync.status.idle')),
      SyncStatusKind.offline => (SemanticColors.warning, copy('sync.status.offline')),
    };
    final last = status.lastSyncedAt;
    final text = status.kind == SyncStatusKind.idle && last != null
        ? '${copy('sync.lastSynced')} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}'
        : label;
    return ActionChip(
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(text, style: TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurface)),
      onPressed: () => context.push('/profile/cloud/sync'),
    );
  }
}
