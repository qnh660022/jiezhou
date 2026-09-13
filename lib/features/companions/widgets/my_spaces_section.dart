/// 首页「我的空间」置顶卡（V2.6.6.2 §7.3，替代原 `SharedLedgerSection`）。
///
/// 与旧「共享账本」分组卡的区别：
/// * 数据源从 `shared_groups`（受邀端镜像）升级为 `travel_spaces`（我创建 + 我加入）；
/// * 卡片样式复用旅伴中心的空间卡（同一份 [SpaceCard]），保证三处观感一致；
/// * 空态不渲染（首页不该出现空分组占位）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/tokens.dart';
import 'space_widgets.dart';

class MySpacesSection extends ConsumerWidget {
  const MySpacesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(travelSpacesRepoProvider);
    final uid = ref.watch(currentUserIdProvider);
    return StreamBuilder<List<TravelSpace>>(
      stream: repo.watchSpaces(),
      builder: (context, snap) {
        final spaces = snap.data ?? const <TravelSpace>[];
        if (spaces.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: '我的空间',
              trailingLabel: '全部',
              onTrailingTap: () => context.push('/companions'),
            ),
            for (final s in spaces.take(3))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.xl, 0, Spacing.xl, Spacing.md),
                child: Material(
                  color: Theme.of(context).colorScheme.brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHigh
                      : Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: AppRadius.card,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg, vertical: Spacing.sm),
                    child: StreamBuilder<List<SpaceMember>>(
                      stream: repo.watchMembers(s.id),
                      builder: (context, ms) {
                        final members = ms.data ?? const <SpaceMember>[];
                        String? role;
                        if (uid != null) {
                          for (final m in members) {
                            if (m.userId == uid) role = m.role;
                          }
                        }
                        role ??= ref.read(syncEngineProvider)?.mySpaceRoleOf(s.id);
                        return SpaceCard(
                          space: s,
                          members: members,
                          myRole: role,
                          onTap: () => context.push('/companions/space/${s.id}'),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
