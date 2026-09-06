// 主题外观页 widget 测试（V2.6 12 卡直选模型）：
// - 浅 5 区 + 深 6 区 + 跟随系统卡渲染完整性与默认选中态（薄荷·山水）；
// - 点击卡片切换 (family,brightness) 并持久化到 app.theme.family/.brightness；
// - 旧键 app.theme.key 迁移：映射正确、旧键删除（§5.2）；
// - 应用层 ThemeMode 三态解析（dark / system+暗色 / light）。
//
// 写法对齐 test/widget_test.dart：SharedPreferences.setMockInitialValues +
// sharedPreferencesProvider.overrideWithValue 包 ProviderScope。
// 页面用例统一采用超高视口，避免 GridView 懒构建导致离屏卡片查找不到。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/app.dart';
import 'package:travel_assistant/features/settings/screens/theme_screen.dart';
import 'package:travel_assistant/theme/theme_provider.dart';
import 'package:travel_assistant/theme/tokens.dart';

void main() {
  const kFamilyKey = 'app.theme.family';
  const kBrightnessKey = 'app.theme.brightness';
  const kLegacyKey = 'app.theme.key';

  Future<ProviderContainer> makeContainer(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  Future<void> pumpThemeScreen(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
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

  testWidgets('主题页渲染：12 张直选卡齐全，默认选中薄荷·山水（浅色）', (tester) async {
    final container = await makeContainer({});
    addTearDown(container.dispose);
    await pumpThemeScreen(tester, container);

    // 浅 5 + 深 6 展示名逐一可见
    final names = [
      ...ThemeStyles.lightStyles.map((s) => s.displayName),
      ...ThemeStyles.darkStyles.map((s) => s.displayName),
    ];
    expect(names.length, 11);
    for (final label in names) {
      expect(find.text(label), findsOneWidget, reason: '缺少主题卡：$label');
    }
    expect(find.text('跟随系统'), findsOneWidget);
    // 默认 mint + light
    expect(container.read(themeFamilyProvider), ThemeFamily.mint);
    expect(container.read(themeBrightnessProvider), ThemeBrightnessMode.light);
  });

  testWidgets('点击切换即时生效并落盘：晴空·天蓝 → 夜航·石墨', (tester) async {
    final container = await makeContainer({});
    addTearDown(container.dispose);
    final prefs = container.read(sharedPreferencesProvider);
    await pumpThemeScreen(tester, container);

    await tester.tap(find.text('晴空·天蓝'));
    await tester.pumpAndSettle();
    expect(container.read(themeFamilyProvider), ThemeFamily.sky);
    expect(container.read(themeBrightnessProvider), ThemeBrightnessMode.light);
    await prefs.reload();
    expect(prefs.getString(kFamilyKey), 'sky');
    expect(prefs.getString(kBrightnessKey), 'light');

    await tester.tap(find.text('夜航·石墨'));
    await tester.pumpAndSettle();
    expect(container.read(themeFamilyProvider), ThemeFamily.night);
    expect(container.read(themeBrightnessProvider), ThemeBrightnessMode.dark);
    await prefs.reload();
    expect(prefs.getString(kFamilyKey), 'night');
    expect(prefs.getString(kBrightnessKey), 'dark');
  });

  testWidgets('旧键迁移：app.theme.key=purple → (nebula, light)，旧键删除', (tester) async {
    final container = await makeContainer({kLegacyKey: ThemeKeys.purple});
    addTearDown(container.dispose);
    final prefs = container.read(sharedPreferencesProvider);
    await pumpThemeScreen(tester, container);

    expect(container.read(themeFamilyProvider), ThemeFamily.nebula);
    expect(container.read(themeBrightnessProvider), ThemeBrightnessMode.light);
    expect(prefs.getString(kFamilyKey), 'nebula');
    expect(prefs.getString(kLegacyKey), isNull); // 旧键删除（§5.2）
  });

  testWidgets('应用层亮暗解析：dark / system(+暗色) / 默认 light 三态',
      (tester) async {
    ThemeMode currentMode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

    // 1) 预置夜航：强制深色
    await pumpApp(tester, {kFamilyKey: 'night'});
    expect(currentMode(), ThemeMode.dark);

    // 2) 预置跟随系统且系统处于暗色：themeMode=system，暗色基准 surface
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() => tester.platformDispatcher.platformBrightnessTestValue =
        Brightness.light);
    await pumpApp(tester, {kBrightnessKey: 'system'});
    expect(currentMode(), ThemeMode.system);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme?.colorScheme.surface, const Color(0xFF14161C));

    // 3) 不预置（还原系统亮度后冷启动）：默认浅色
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await pumpApp(tester, {});
    expect(currentMode(), ThemeMode.light);
  });
}
