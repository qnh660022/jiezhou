import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/ai/screens/ai_chat_screen.dart';
import 'features/ai/screens/ai_settings_screen.dart';
import 'features/checklist/screens/checklist_screen.dart';
import 'features/checklist/screens/item_edit_screen.dart';
import 'features/ledger/screens/budget_screen.dart';
import 'features/ledger/screens/categories_screen.dart';
import 'features/ledger/screens/expense_edit_screen.dart';
import 'features/ledger/screens/expenses_screen.dart';
import 'features/ledger/screens/group_edit_screen.dart';
import 'features/ledger/screens/group_list_screen.dart';
import 'features/ledger/screens/ledger_home_screen.dart';
import 'features/ledger/screens/members_screen.dart';
import 'features/ledger/screens/settle_screen.dart';
import 'features/ledger/screens/stats_screen.dart';
import 'features/settings/screens/about_screen.dart';
import 'features/settings/screens/privacy_screen.dart';
import 'features/settings/screens/profile_screen.dart';
import 'features/settings/screens/splash_screen.dart';
import 'features/settings/screens/theme_screen.dart';
import 'features/trips/screens/map_settings_screen.dart';
import 'features/trips/screens/trip_album_screen.dart';
import 'features/trips/screens/trip_detail_screen.dart';
import 'features/trips/screens/trip_edit_screen.dart';
import 'features/trips/screens/trip_export_screen.dart';
import 'features/trips/screens/trip_map_screen.dart';
import 'features/trips/screens/trip_share_screen.dart';
import 'features/trips/screens/trip_templates_screen.dart';
import 'features/trips/screens/trips_home_screen.dart';
import 'shared/widgets/floating_capsule_nav_bar.dart';

/// 应用根路由表：
/// `/` 开屏页（顶层）+ 5 个 Tab 分支（StatefulShellRoute.indexedStack 保持各分支状态）
/// /ai /checklist /trips /ledger /profile
/// `/expenses` 子树为顶层全屏路由（从账本页打开，不占 Tab）
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: buildAppRoutes(),
);

/// 应用路由表（独立函数便于测试注入全新 GoRouter 实例，避免跨测试共享导航状态）
List<RouteBase> buildAppRoutes() => [
    // ============ 开屏 ============
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => HomeShell(shell: navigationShell),
      branches: [
        // ============ AI 助手 ============
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/ai',
            name: 'ai',
            builder: (context, state) => const AiChatScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                name: 'ai-settings',
                builder: (context, state) => const AiSettingsScreen(),
              ),
            ],
          ),
        ]),
        // ============ 清单 ============
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/checklist',
            name: 'checklist',
            builder: (context, state) => const ChecklistScreen(),
            routes: [
              GoRoute(
                path: 'item-edit',
                name: 'item-edit',
                builder: (context, state) => const ItemEditScreen(),
              ),
            ],
          ),
        ]),
        // ============ 行程 ============
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/trips',
            name: 'trips',
            builder: (context, state) => const TripsHomeScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'trip-edit',
                builder: (context, state) => const TripEditScreen(),
              ),
              GoRoute(
                path: 'detail',
                name: 'trip-detail',
                builder: (context, state) => const TripDetailScreen(),
              ),
              GoRoute(
                path: 'map',
                name: 'trip-map',
                builder: (context, state) => const TripMapScreen(),
              ),
              GoRoute(
                path: 'album',
                name: 'trip-album',
                builder: (context, state) => const TripAlbumScreen(),
              ),
              GoRoute(
                path: 'export',
                name: 'trip-export',
                builder: (context, state) => const TripExportScreen(),
              ),
              GoRoute(
                path: 'share',
                name: 'trip-share',
                builder: (context, state) => const TripShareScreen(),
              ),
              GoRoute(
                path: 'map-settings',
                name: 'map-settings',
                builder: (context, state) => const MapSettingsScreen(),
              ),
              GoRoute(
                path: 'templates',
                name: 'trip-templates',
                builder: (context, state) => const TripTemplatesScreen(),
              ),
            ],
          ),
        ]),
        // ============ 账本（群组） ============
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/ledger',
            name: 'ledger',
            builder: (context, state) => const LedgerHomeScreen(),
            routes: [
              GoRoute(
                path: 'groups',
                name: 'group-list',
                builder: (context, state) => const GroupListScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'group-edit',
                    builder: (context, state) => const GroupEditScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'members',
                name: 'members',
                builder: (context, state) => const MembersScreen(),
              ),
            ],
          ),
        ]),
        // ============ 我的 ============
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'theme',
                name: 'theme-screen',
                builder: (context, state) => const ThemeScreen(),
              ),
              GoRoute(
                path: 'about',
                name: 'about',
                builder: (context, state) => const AboutScreen(),
              ),
              GoRoute(
                path: 'privacy',
                name: 'privacy',
                builder: (context, state) => const PrivacyScreen(),
              ),
            ],
          ),
        ]),
      ],
    ),
    // ============ 消费账单流（顶层全屏，从账本页打开） ============
    GoRoute(
      path: '/expenses',
      name: 'expenses',
      // 页面自身无 Scaffold（原为 Tab 壳内嵌），顶层打开时在此补 Material 祖先
      builder: (context, state) => const Scaffold(body: ExpensesScreen()),
      routes: [
        GoRoute(
          path: 'edit',
          name: 'expense-edit',
          builder: (context, state) => const ExpenseEditScreen(),
        ),
        GoRoute(
          path: 'stats',
          name: 'stats',
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: 'settle',
          name: 'settle',
          builder: (context, state) => const SettleScreen(),
        ),
        GoRoute(
          path: 'budget',
          name: 'budget',
          builder: (context, state) => const BudgetScreen(),
        ),
        GoRoute(
          path: 'categories',
          name: 'categories',
          builder: (context, state) => const CategoriesScreen(),
        ),
      ],
    ),
];

/// 底部外壳：承载 5 分支导航壳 + 悬浮胶囊底栏
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const List<CapsuleTabItem> _tabs = [
    CapsuleTabItem(emoji: '🤖', label: 'AI'),
    CapsuleTabItem(emoji: '📋', label: '清单'),
    CapsuleTabItem(emoji: '🧳', label: '行程'),
    CapsuleTabItem(emoji: '💰', label: '账本'),
    CapsuleTabItem(emoji: '👤', label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: FloatingCapsuleNavBar(
        items: _tabs,
        currentIndex: shell.currentIndex,
        onTap: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}
