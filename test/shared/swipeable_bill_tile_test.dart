// V2.8.1 S6 · SwipeableBillTile（规格 §9.3 部分，3 例）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/shared/widgets/swipeable_bill_tile.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester,
      {required VoidCallback onEdit, required VoidCallback onDelete}) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SwipeableBillTile(
            onEdit: onEdit,
            onDelete: onDelete,
            child: const ListTile(title: Text('午饭')),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('1. 左滑超过阈值露出删除背景并触发 onDelete', (tester) async {
    var deleted = false;
    var edited = false;
    await pumpTile(tester,
        onEdit: () => edited = true, onDelete: () => deleted = true);
    // 左滑（负向）超过 84px
    final gesture = await tester.startGesture(tester.getCenter(find.text('午饭')));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(deleted, isTrue, reason: '左滑 100px > 84 阈值触发删除');
    expect(edited, isFalse);
  });

  testWidgets('2. 右滑超过阈值触发 onEdit', (tester) async {
    var deleted = false;
    var edited = false;
    await pumpTile(tester,
        onEdit: () => edited = true, onDelete: () => deleted = true);
    final gesture = await tester.startGesture(tester.getCenter(find.text('午饭')));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(edited, isTrue, reason: '右滑 100px > 84 阈值触发编辑');
    expect(deleted, isFalse);
  });

  testWidgets('3. 滑动 40px（<84 阈值）回弹且不触发动作', (tester) async {
    var fired = false;
    await pumpTile(tester, onEdit: () => fired = true, onDelete: () => fired = true);
    final gesture = await tester.startGesture(tester.getCenter(find.text('午饭')));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fired, isFalse, reason: '未达阈值只回弹不触发');
  });
}
