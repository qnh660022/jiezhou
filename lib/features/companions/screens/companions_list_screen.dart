/// 我的空间列表页（V2.6.6.2 §6.1：路由 `/companions`，可由旅伴中心锚点跳转）。
///
/// 与旅伴中心的「我的空间」分区共用同一份空间卡样式，但这里是**全屏列表**
/// （旅伴中心只展示前若干个，避免门厅页变成列表页）。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/sync/sync_control_providers.dart';
import '../../../shared/widgets/collab_polling_scope.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/skeleton_box.dart';
import '../../../theme/tokens.dart';
import '../widgets/space_widgets.dart';

class CompanionsListScreen extends ConsumerWidget {
  const CompanionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(travelSpacesRepoProvider);
    final uid = ref.watch(currentUserIdProvider);
    return CollabPollingScope(
      child: Scaffold(
        appBar: GlassAppBar(
          title: '我的空间',
          actions: [
            IconButton(
              tooltip: '新建空间',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _create(context),
            ),
          ],
        ),
        body: StreamBuilder<List<TravelSpace>>(
          stream: repo.watchAllSpaces(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(Spacing.xl),
                child: SkeletonBox(height: 96, radius: AppRadius.cardValue),
              );
            }
            final spaces = snap.data!;
            if (spaces.isEmpty) {
              return EmptyState(
                emoji: '🧭',
                title: '还没有旅伴空间',
                message: '建一个空间，把行程和账本分享给同行的旅伴。',
                actionLabel: '新建空间',
                onAction: () => _create(context),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xxxl),
              children: [
                for (final s in spaces)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
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
                            return SpaceCard(
                              space: s,
                              members: members,
                              myRole: _roleOf(members, uid) ??
                                  ref
                                      .read(syncEngineProvider)
                                      ?.mySpaceRoleOf(s.id),
                              onTap: () => context.push('/companions/space/${s.id}'),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: Spacing.lg),
                PrimaryButton(
                  label: '新建空间',
                  icon: Icons.add_rounded,
                  expanded: true,
                  onPressed: () => _create(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String? _roleOf(List<SpaceMember> members, String? uid) {
    if (uid == null) return null;
    for (final m in members) {
      if (m.userId == uid) return m.role;
    }
    return null;
  }

  static Future<void> _create(BuildContext context) async {
    final spaceId = await showCreateSpaceSheet(context);
    if (spaceId != null && spaceId.isNotEmpty && context.mounted) {
      context.push('/companions/space/$spaceId');
    }
  }
}
