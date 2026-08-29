import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/app.dart';
import 'package:travel_assistant/router.dart';
import 'package:travel_assistant/theme/theme_provider.dart';

void main() {
  Future<SharedPreferences> pumpApp(WidgetTester tester) async {
    // 高视口：让「我的」页所有设置项都在可视区内（ListView 懒构建）
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // 每测注入全新 GoRouter，避免全局 appRouter 的导航状态跨测试残留
    final router = GoRouter(initialLocation: '/', routes: buildAppRoutes());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: TravelAssistantApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> gotoProfile(WidgetTester tester) async {
    // 首帧 Splash 会触发导航到行程 Tab；以底栏 emoji 定位「我的」
    final emoji = find.text('👤').first;
    await tester.tap(emoji);
    await tester.pumpAndSettle();
    expect(find.text('我的'), findsWidgets); // 页面大标题出现
  }

  testWidgets('我的页：新增设置项全部渲染', (tester) async {
    await pumpApp(tester);
    await gotoProfile(tester);

    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('数据与隐私'), findsOneWidget);
    expect(find.text('预算预警'), findsOneWidget);
    expect(find.text('隐私说明'), findsOneWidget);
    expect(find.text('清除本地缓存'), findsOneWidget);
    expect(find.text('恢复默认设置'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('意见反馈'), findsOneWidget);
  });

  testWidgets('预算预警开关：切换后持久化', (tester) async {
    final prefs = await pumpApp(tester);
    await gotoProfile(tester);

    expect(await prefs.getBool('budget_alerts_enabled'), isNull); // 默认开启
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(await prefs.getBool('budget_alerts_enabled'), isFalse);
  });

  testWidgets('关于页：从我的页进入并渲染完整内容', (tester) async {
    await pumpApp(tester);
    await gotoProfile(tester);

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(find.text('旅途助手'), findsWidgets);
    expect(find.text('v2.1.1'), findsWidgets);
    expect(find.text('功能亮点'), findsOneWidget);
    expect(find.text('数据与隐私'), findsOneWidget);
    expect(find.text('开源致谢'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('意见反馈'), findsOneWidget);
  });

  testWidgets('隐私说明页：从我的页进入', (tester) async {
    await pumpApp(tester);
    await gotoProfile(tester);

    await tester.tap(find.text('隐私说明'));
    await tester.pumpAndSettle();

    expect(find.text('我们的承诺'), findsOneWidget);
    expect(find.text('数据存储'), findsOneWidget);
  });
}
