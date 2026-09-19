import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_icons.dart';
import 'features/ai/screens/ai_chat_screen.dart';
import 'features/ai/screens/ai_settings_screen.dart';
import 'features/checklist/desktop_checklist_workbench.dart';
import 'features/checklist/screens/checklist_screen.dart';
import 'features/checklist/screens/item_edit_screen.dart';
import 'features/desktop/desktop_shell.dart';
import 'features/desktop/desktop_utils.dart' show isDesktopWeb;
import 'features/lock/lock_screen.dart';
import 'platform/app_lock.dart' show AppLockGate;
import 'features/ledger/desktop_ledger_workbench.dart';
import 'features/trips/desktop_trips_workbench.dart' as trips_wb;
import 'features/ledger/screens/audit_log_screen.dart';
import 'features/ledger/screens/budget_screen.dart';
import 'features/ledger/screens/categories_screen.dart';
import 'features/ledger/screens/expense_edit_screen.dart';
import 'features/ledger/screens/expenses_screen.dart';
import 'features/ledger/screens/fund_screen.dart';
import 'features/ledger/screens/inbox_screen.dart';
import 'features/ledger/screens/group_edit_screen.dart';
import 'features/ledger/screens/group_list_screen.dart';
import 'features/ledger/screens/invite_screen.dart';
import 'features/ledger/screens/lan_sync_screen.dart';
import 'features/ledger/screens/share_view_screen.dart';
import 'features/ledger/screens/ledger_home_screen.dart';

import 'features/ledger/screens/members_screen.dart';
import 'features/ledger/screens/settle_screen.dart';
import 'features/ledger/screens/stats_screen.dart';
import 'features/companions/screens/companions_list_screen.dart';
import 'features/companions/screens/legacy_shared_redirect_screen.dart';
import 'features/companions/screens/space_detail_screen.dart';
import 'features/today/screens/today_cockpit_screen.dart';
import 'features/today/screens/today_plan_screen.dart';
import 'features/today/screens/today_spend_screen.dart';
import 'features/settings/screens/about_screen.dart';
import 'features/settings/screens/app_lock_screen.dart';
import 'features/settings/screens/cloud_account_screen.dart';
import 'features/settings/screens/share_center_screen.dart';
import 'features/settings/screens/sync_center_screen.dart';
import 'features/settings/screens/privacy_screen.dart';
import 'features/settings/screens/profile_screen.dart';
import 'features/settings/screens/splash_screen.dart';
import 'features/settings/screens/theme_screen.dart';
import 'features/trips/screens/map_settings_screen.dart';
import 'features/trips/screens/trip_album_screen.dart';
import 'features/trips/screens/trip_detail_screen.dart';
import 'features/trips/screens/trip_edit_screen.dart';
import 'features/trips/screens/trip_export_screen.dart';
import 'features/trips/guide_widgets.dart' show GuideRouteArgs;
import 'features/trips/screens/trip_guide_screen.dart';
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
  redirect: appLockRedirect,
  routes: buildAppRoutes(),
);

/// V2.7.1 S7.2（F3）：启动锁的**唯一**拦截点。
///
/// * 锁状态未加载（`AppLockGate.ready == false`）时不拦——开屏页负责 `load()`；
/// * `lockEnabled && !unlocked` → 重定向 `/lock`；
/// * `/lock` 自身放行，避免自锁循环；锁已解除时把 `/lock` 弹回开屏。
/// * 只拦冷启动这一次，**不做**「进入账本二级校验」（§S7.2 不做清单）。
String? appLockRedirect(BuildContext context, GoRouterState state) {
  if (!AppLockGate.ready) return null;
  final onLock = state.matchedLocation == '/lock';
  if (AppLockGate.locked && !onLock) return '/lock';
  if (!AppLockGate.locked && onLock) return '/';
  return null;
}

/// 应用路由表（独立函数便于测试注入全新 GoRouter 实例，避免跨测试共享导航状态）
List<RouteBase> buildAppRoutes() => [
    // ============ 开屏 ============
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // ============ 启动锁屏（V2.7.1 S7.2，顶层：独立于底部 Tab 壳） ============
    GoRoute(
      path: '/lock',
      name: 'app-lock',
      builder: (context, state) => const LockScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => HomeShell(shell: navigationShell),
      branches: [
        // ============ AI 助手（Web 端屏蔽：不注册分支，免暴露） ============
        if (!kIsWeb)
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
            builder: (context, state) => isDesktopWeb(context)
                ? const DesktopChecklistWorkbench()
                : const ChecklistScreen(),
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
            builder: (context, state) => isDesktopWeb(context)
                ? const trips_wb.DesktopTripsWorkbench()
                : const TripsHomeScreen(),
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
              // 目的地攻略（任务5）：仅 Android 注册；Web 端隐藏入口不注册路由（§7.8）
              if (!kIsWeb)
                GoRoute(
                  path: 'guide',
                  name: 'trip-guide',
                  builder: (context, state) {
                    // 兼容旧调用（extra 传 tripId 字符串）与新调用（GuideRouteArgs）
                    final extra = state.extra;
                    if (extra is GuideRouteArgs) {
                      return extra.tripId != null
                          ? TripGuideScreenBuilder(
                              tripId: extra.tripId!, focusRef: extra.focusRef)
                          : TripGuideScreen(
                              cityKey: extra.cityKey, focusRef: extra.focusRef);
                    }
                    final tripId = extra as String? ?? '';
                    return TripGuideScreenBuilder(tripId: tripId);
                  },
                ),
            ],
          ),
        ]),
        // ============ 账本（群组） ============
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/ledger',
            name: 'ledger',
            builder: (context, state) => isDesktopWeb(context)
                ? const DesktopLedgerWorkbench()
                : const LedgerHomeScreen(),
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
                path: 'lan-sync',
                name: 'lan-sync',
                builder: (context, state) => const LanSyncScreen(),
              ),
              GoRoute(
                path: 'members',
                name: 'members',
                builder: (context, state) => const MembersScreen(),
              ),
              // 共享团详情（受邀端镜像）：**V2.6.6.2 §7.2 起已退役**。
              // 旧四 Tab 页不再渲染，改为解析出对应旅伴空间后重定向到
              // `/companions/space/:spaceId?tab=ledger`（能力已抽成组件嵌进空间账本区）。
              // 保留 path 是为了让老客户端分享出去的深链继续可用。
              GoRoute(
                path: 'shared/:id',
                name: 'shared-group',
                builder: (context, state) => LegacySharedRedirectScreen(
                    groupId: state.pathParameters['id'] ?? ''),
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
              // V2.7.1 S7.2：启动锁设置（仅本地 PIN，不参与云同步）
              GoRoute(
                path: 'app-lock',
                name: 'app-lock-settings',
                builder: (context, state) => const AppLockScreen(),
              ),
              // 分享与协作中心：邀请旅伴 / 只读链接 / 加团 / 局域网，一处收口。
              GoRoute(
                path: 'share',
                name: 'share-center',
                builder: (context, state) => const ShareCenterScreen(),
              ),
              GoRoute(
                path: 'cloud',
                name: 'cloud-account',
                builder: (context, state) => const CloudAccountScreen(),
                routes: [
                  GoRoute(
                    path: 'sync',
                    name: 'sync-center',
                    builder: (context, state) => const SyncCenterScreen(),
                  ),
                ],
              ),
            ],
          ),
        ]),
      ],
    ),
    // ============ 邀请加入（Web 深链，需登录后跳转） ============
    GoRoute(
      path: '/invite',
      name: 'invite',
      builder: (context, state) =>
          InviteScreen(code: state.uri.queryParameters['c']),
    ),
    // ============ 旅伴空间（V2.6.6.2 §11，顶层全屏：从首页/旅伴中心打开都不切 Tab） ============
    GoRoute(
      path: '/companions',
      name: 'companions',
      builder: (context, state) => const CompanionsListScreen(),
      routes: [
        GoRoute(
          path: 'space/:id',
          name: 'companion-space',
          // ?tab=trip|ledger|members|events（缺省 trip）
          builder: (context, state) => SpaceDetailScreen(
            spaceId: state.pathParameters['id'] ?? '',
            initialTab: state.uri.queryParameters['tab'],
          ),
        ),
      ],
    ),
    // ============ 今日驾驶舱（V2.6.6.2 §11 / D2~D3，顶层全屏） ============
    GoRoute(
      path: '/today/:tripId',
      name: 'today',
      builder: (context, state) =>
          TodayCockpitScreen(tripId: state.pathParameters['tripId'] ?? ''),
      routes: [
        GoRoute(
          path: 'plan',
          name: 'today-plan',
          builder: (context, state) =>
              TodayPlanScreen(tripId: state.pathParameters['tripId'] ?? ''),
        ),
        GoRoute(
          path: 'spend',
          name: 'today-spend',
          builder: (context, state) =>
              TodaySpendScreen(tripId: state.pathParameters['tripId'] ?? ''),
        ),
      ],
    ),
    // ============ 目的地攻略（2026-09 需求 3：多入口） ============
    //
    // 顶层注册而不是挂在 /trips 分支下：从「行程列表页卡片」「我的」「账本」
    // 等任意位置打开都不会切走当前 Tab。参数走 extra（GuideRouteArgs），
    // 支持只有城市 key、没有行程上下文的用法。
    // Web 端不注册：浏览器 CORS 无法直连国内源，且该功能定位纯本地（§7.8）。
    if (!kIsWeb)
      GoRoute(
        path: '/guide',
        name: 'guide',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is GuideRouteArgs) {
            return extra.tripId != null
                ? TripGuideScreenBuilder(
                    tripId: extra.tripId!, focusRef: extra.focusRef)
                : TripGuideScreen(cityKey: extra.cityKey, focusRef: extra.focusRef);
          }
          final cityKey = state.uri.queryParameters['city'];
          return TripGuideScreen(cityKey: cityKey);
        },
      ),
    // ============ 只读分享页（Web 顶层，匿名可访问，无桌面宽度要求） ============
    GoRoute(
      path: '/s/:token',
      name: 'share-view',
      builder: (context, state) =>
          ShareViewScreen(token: state.pathParameters['token'] ?? ''),
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
        // ===== V2.7.1：记账收件箱（S10）与公款池（S8） =====
        GoRoute(
          path: 'inbox',
          name: 'inbox',
          builder: (context, state) => const InboxScreen(),
        ),
        GoRoute(
          path: 'fund',
          name: 'fund',
          builder: (context, state) => const FundScreen(),
        ),
        GoRoute(
          path: 'categories',
          name: 'categories',
          builder: (context, state) => const CategoriesScreen(),
        ),
        // ===== V2.7.1 S12.3：变更记录页（仅本地审计；入口对 viewer 不渲染）=====
        GoRoute(
          path: 'audit',
          name: 'audit-log',
          builder: (context, state) => const AuditLogScreen(),
        ),
      ],
    ),
];

/// 底部外壳：承载 5 分支导航壳 + 悬浮胶囊底栏
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // 原生含 AI Tab，共 5 项；Web 屏蔽 AI，仅 4 项（需与 branches 个数一一对应）。
  static List<CapsuleTabItem> get _tabs {
    final base = <CapsuleTabItem>[
      const CapsuleTabItem(emoji: '📋', label: '清单', icon: AppIcons.clip),
      const CapsuleTabItem(emoji: '🧳', label: '行程', icon: AppIcons.compass),
      const CapsuleTabItem(emoji: '💰', label: '账本', icon: AppIcons.wallet),
      const CapsuleTabItem(emoji: '👤', label: '我的', icon: AppIcons.user),
    ];
    if (kIsWeb) return base;
    return [const CapsuleTabItem(emoji: '🤖', label: 'AI', icon: AppIcons.spark), ...base];
  }

  @override
  Widget build(BuildContext context) {
    // 桌面 Web 大屏：左侧导航栏外壳；其余（安卓/窄屏 Web）沿用移动底栏。
    if (isDesktopWeb(context)) {
      return DesktopShell(shell: shell, tabs: _tabs);
    }
    // 让导航栏成为真正的悬浮层，而不是 Scaffold 的 bottomNavigationBar
    // 布局子项。后者会先缩短 StatefulNavigationShell 的高度，分支内页面
    // 再按 navBarHeight / safe area 让位时就会重复留白，尤其影响行程详情
    // 的「时间线 / 攻略」停靠条和新建行程的提交区。
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          shell,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingCapsuleNavBar(
              items: _tabs,
              currentIndex: shell.currentIndex,
              onTap: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
