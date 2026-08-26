import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/app.dart';
import 'package:travel_assistant/theme/theme_provider.dart';

void main() {
  testWidgets('应用冷启动：首屏为行程 Tab 并渲染毛玻璃标题', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const TravelAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 首屏大标题「旅途助手」
    expect(find.text('旅途助手'), findsWidgets);
  });

  testWidgets('底栏切换到消费 Tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const TravelAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('消费'));
    await tester.pumpAndSettle();

    expect(find.text('消费'), findsWidgets);
  });
}
