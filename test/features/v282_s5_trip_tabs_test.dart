// V2.8.2 S5 行程详情页签层（配额 ≥6）：
// 玻璃 SegmentedTab —— GlassSurface(navBar)+圆角18 / 内滑移选中胶囊 / 四页签
// AppIcons.clock·clip·bolt·bag / 240ms easeOutCubic 切换 / 组件下沉文件断言。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/features/trips/widgets/trip_detail_tabs.dart';
import 'package:travel_assistant/shared/widgets/glass_surface.dart';
import 'package:travel_assistant/theme/app_icons.dart';
import 'package:travel_assistant/theme/tokens.dart' show GlassLevel;

/// 提供 vsync 的宿主（TabController 需要 TickerProvider）。
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController ctrl =
      TabController(length: 4, vsync: this, initialIndex: 0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(bottom: TripDetailTabs(controller: ctrl)),
        body: const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  group('S5 TripDetailTabs 玻璃 SegmentedTab', () {
    testWidgets('四页签 label 全部渲染（时间轴/大纲/装配/锦囊）', (tester) async {
      await tester.pumpWidget(const _Host());
      for (final label in ['时间轴', '大纲', '装配', '锦囊']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('四页签 icon = AppIcons.clock/clip/bolt/bag', (tester) async {
      await tester.pumpWidget(const _Host());
      expect(find.byIcon(AppIcons.clock), findsOneWidget);
      expect(find.byIcon(AppIcons.clip), findsOneWidget);
      expect(find.byIcon(AppIcons.bolt), findsOneWidget);
      expect(find.byIcon(AppIcons.bag), findsOneWidget);
    });

    testWidgets('玻璃底座：GlassSurface(navBar) + 圆角 18', (tester) async {
      await tester.pumpWidget(const _Host());
      final glass = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(glass.level, GlassLevel.navBar);
      expect(glass.borderRadius, BorderRadius.circular(18));
    });

    testWidgets('implements PreferredSizeWidget：preferredSize = 高度档', (tester) async {
      await tester.pumpWidget(const _Host());
      final bar = tester.widget<TripDetailTabs>(find.byType(TripDetailTabs));
      expect(bar.preferredSize, const Size.fromHeight(44));
      expect(bar.height, 44);
    });

    testWidgets('点按切页签 → animateTo(240ms easeOutCubic)，动画后 index 到位',
        (tester) async {
      await tester.pumpWidget(const _Host());
      final state = tester.state<_HostState>(find.byType(_Host));
      final ctrl = state.ctrl;
      expect(ctrl.index, 0);
      await tester.tap(find.text('大纲'));
      expect(ctrl.indexIsChanging, isTrue, reason: 'animateTo 进行中（非跳变）');
      await tester.pumpAndSettle();
      expect(ctrl.index, 1);
    });

    testWidgets('选中胶囊位置随 index 滑移（left ≈ itemWidth×index + 4）',
        (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      double capsuleLeft() {
        final stack = tester.widgetList<Positioned>(find.descendant(
          of: find.byType(TripDetailTabs),
          matching: find.byWidgetPredicate(
              (w) => w is Positioned && w.width != null && w.left != null),
        ));
        return stack.first.left!;
      }

      // 初始：index 0 → left ≈ 4（条内 insets）
      final w0 = capsuleLeft();
      expect(w0, lessThan(30));

      await tester.tap(find.text('锦囊'));
      await tester.pumpAndSettle();
      final w3 = capsuleLeft();
      expect(w3, greaterThan(w0), reason: '胶囊向右滑移到第 4 格');
    });
  });

  group('S5 组件下沉（文件断言）', () {
    test('trip_detail_tabs.dart 独立组件存在，宿主不再使用裸 TabBar', () {
      final tabsSrc =
          File('lib/features/trips/widgets/trip_detail_tabs.dart').readAsStringSync();
      expect(tabsSrc.contains('class TripDetailTabs'), isTrue);
      expect(tabsSrc.contains('GlassSurface('), isTrue);
      expect(tabsSrc.contains('Curves.easeOutCubic'), isTrue);
      expect(tabsSrc.contains('Duration(milliseconds: 240)'), isTrue);

      final screenSrc =
          File('lib/features/trips/screens/trip_detail_screen.dart').readAsStringSync();
      expect(screenSrc.contains('TripDetailTabs('), isTrue);
      // 页签层替换后，宿主 AppBar 不再挂裸 TabBar
      expect(screenSrc.contains('child: TabBar('), isFalse);
      // viewer/editor 口径维持：四页签仍在宿主装配
      expect(screenSrc.contains('OutlineTab(tripId: id)'), isTrue);
      expect(screenSrc.contains('AssemblePanel(tripId: id'), isTrue);
      expect(screenSrc.contains('KitTab(tripId: id)'), isTrue);
    });
  });
}
