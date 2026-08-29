import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/features/desktop/desktop_utils.dart';

void main() {
  testWidgets('isDesktopWeb 在非 Web（安卓/测试）环境恒为 false —— 安卓零回归契约',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        // flutter test 运行在 VM，kIsWeb 恒为 false ⇒ 任何宽度都不启用桌面布局。
        expect(isDesktopWeb(context), isFalse);
        return const SizedBox.shrink();
      }),
    ));
    expect(tester.takeException(), isNull);
  });
}