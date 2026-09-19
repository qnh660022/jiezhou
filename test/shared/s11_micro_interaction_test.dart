// V2.8.1 S11 · 微交互包 A（规格 §14，6 例）：
// PressableScale 按压/回调/禁用、EmptyState 玻璃圆盘/降级/emoji 兼容。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/shared/widgets/empty_state.dart';
import 'package:travel_assistant/shared/widgets/glass_surface.dart';
import 'package:travel_assistant/shared/widgets/pressable_scale.dart';

void main() {
  group('PressableScale', () {
    testWidgets('1. 点按回调触发 + 触发缩放动画（无异常）', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableScale(
              onTap: () => tapped++,
              child: const Text('点我'),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('点我'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('2. 按下期间 scale < 1（压缩放生效）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableScale(
              onTap: () {},
              child: const Text('按压'),
            ),
          ),
        ),
      ));
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(find.text('按压')));
      await tester.pump(const Duration(milliseconds: 45));
      final scale =
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale, lessThan(1.0), reason: '按下时缩小到 0.97');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('3. onTap 为 null：不触发且不缩放', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: Center(child: PressableScale(child: Text('禁用'))),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('禁用'));
      await tester.pump(const Duration(milliseconds: 45));
      final scale =
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale, 1.0, reason: '禁用态不缩放');
    });
  });

  group('EmptyState 升级', () {
    testWidgets('4. 传 icon：玻璃圆盘渲染（GlassSurface + Icon）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: EmptyState(icon: Icons.receipt_long_rounded, title: '还没记账'),
        ),
      ));
      await tester.pump();
      expect(find.byType(GlassSurface), findsOneWidget, reason: '玻璃圆盘底座');
      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
      expect(find.text('还没记账'), findsOneWidget);
    });

    testWidgets('5. disableAnimations：微浮动静止（直接终态）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: EmptyState(icon: Icons.receipt_long_rounded, title: '静态'),
          ),
        ),
      ));
      await tester.pump();
      // 降级路径不抛异常且正常渲染
      expect(find.text('静态'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. emoji 兼容参数：未迁移调用点零破坏', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: EmptyState(emoji: '🧾', title: '旧调用', message: '兼容不破坏'),
        ),
      ));
      await tester.pump();
      expect(find.text('🧾'), findsOneWidget, reason: 'emoji 内容岗位保留');
      expect(find.text('旧调用'), findsOneWidget);
      expect(find.byType(GlassSurface), findsNothing, reason: 'emoji 分支无玻璃盘');
    });
  });
}
