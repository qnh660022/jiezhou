// 主题外观页 widget 测试：
// - 七选一画廊渲染完整性与默认选中态；
// - 点击卡片即时切换 provider 状态并持久化到 SharedPreferences；
// - 冷启动恢复上次持久化选择；
// - 应用层 ThemeMode 三态解析（dark / system / light）与石墨夜暗色基准。
//
// 写法对齐 test/widget_test.dart：SharedPreferences.setMockInitialValues +
// sharedPreferencesProvider.overrideWithValue 包 ProviderScope。
// 页面用例统一采用超高视口，避免 ListView/GridView 懒构建导致离屏卡片查找不到。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/app.dart';
import 'package:travel_assistant/features/settings/screens/theme_screen.dart';
import 'package:travel_assistant/theme/theme_provider.dart';
import 'package:travel_assistant/theme/tokens.dart';

void main() {
  /// 主题持久化键（theme_provider 内为私有常量，这里按存储契约复述）
  const kThemeStorageKey = 'app.theme.key';

  /// 构建注入 mock prefs 的独立容器（调用方负责 addTearDown(container.dispose)）
  Future<ProviderContainer> makeContainer(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// 直接拉起主题页（不经路由）：超高视口让七张卡一次性进入懒加载可视区。
  Future<void> pumpThemeScreen(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ThemeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 拉起完整应用（首屏 splash 会自动跳转，需 pumpAndSettle 到稳态）
  Future<void> pumpApp(
    WidgetTester tester,
    Map<String, Object> initialValues,
  ) async {
    final container = await makeContainer(initialValues);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TravelAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('主题页渲染：七个主题标签齐全，默认选中薄荷绿', (tester) async {
    final container = await makeContainer({});
    addTearDown(container.dispose);
    await pumpThemeScreen(tester, container);

    // 七个标签逐一可见且各出现一次
    for (final label in ThemeKeys.labels.values) {
      expect(find.text(label), findsOneWidget, reason: '缺少主题标签：$label');
    }
    // 默认选中薄荷绿：provider 状态正确，且全场只有一枚「已选」对勾徽标
    expect(container.read(themeProvider), ThemeKeys.green);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('点击切换即时生效并落盘：天空蓝 → 跟随系统', (tester) async {
    final container = await makeContainer({});
    addTearDown(container.dispose);
    final prefs = container.read(sharedPreferencesProvider);
    await pumpThemeScreen(tester, container);

    // 点天空蓝：状态切换 + 持久化 + 徽标仍唯一
    await tester.tap(find.text('天空蓝'));
    await tester.pumpAndSettle();
    expect(container.read(themeProvider), ThemeKeys.blue);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await prefs.reload(); // 从存储侧复核，确认真落盘而非内存缓存
    expect(prefs.getString(kThemeStorageKey), ThemeKeys.blue);

    // 再点跟随系统：同样状态 + 落盘
    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    expect(container.read(themeProvider), ThemeKeys.system);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await prefs.reload();
    expect(prefs.getString(kThemeStorageKey), ThemeKeys.system);
  });

  testWidgets('冷启动恢复：预置星空紫时选中态正确', (tester) async {
    final container = await makeContainer({kThemeStorageKey: ThemeKeys.purple});
    addTearDown(container.dispose);
    await pumpThemeScreen(tester, container);

    expect(container.read(themeProvider), ThemeKeys.purple);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('应用层亮暗解析：dark / system(+暗色) / 默认 light 三态',
      (tester) async {
    ThemeMode currentMode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

    // 1) 预置石墨夜：强制深色
    await pumpApp(tester, {kThemeStorageKey: ThemeKeys.dark});
    expect(currentMode(), ThemeMode.dark);

    // 2) 预置跟随系统且系统处于暗色：themeMode=system，暗色基准为石墨夜配色
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() => tester.platformDispatcher.platformBrightnessTestValue =
        Brightness.light);
    await pumpApp(tester, {kThemeStorageKey: ThemeKeys.system});
    expect(currentMode(), ThemeMode.system);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme?.colorScheme.surface, const Color(0xFF14161C));

    // 3) 不预置（还原系统亮度后冷启动）：默认浅色
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await pumpApp(tester, {});
    expect(currentMode(), ThemeMode.light);
  });
}
