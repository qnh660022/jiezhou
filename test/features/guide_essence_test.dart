// V2.7.2 S10：攻略精要随卡 Widget 用例（spots/food 渲染、漂移降级、折叠态）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/guide/guide_providers.dart';
import 'package:travel_assistant/features/trips/widgets/guide_essence_section.dart';

Widget _host<T extends Map<String, dynamic>?>(T Function(String raw)? resolver,
    {required String ref, required String name}) {
  return ProviderScope(
    overrides: [
      if (resolver != null)
        guideRowByRefProvider.overrideWith((ref, raw) async => resolver(raw)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          GuideEssenceSection(guideRef: ref, itemName: name),
        ]),
      ),
    ),
  );
}

void main() {
  const spotRow = <String, dynamic>{
    'name': '西湖',
    'addr': '龙井路1号',
    'tag': '必去',
    'note': '环湖步行 2 小时起，断桥—白堤—孤山—雷峰塔是经典动线。',
  };

  testWidgets('1. spots：折叠态显示头，展开后 addr/tag/note 全文', (tester) async {
    await tester.pumpWidget(_host((_) => spotRow,
        ref: 'hz#spots#0', name: '西湖'));
    await tester.pumpAndSettle();
    expect(find.text('攻略精要'), findsOneWidget);
    expect(find.text('必去'), findsOneWidget, reason: '头部 tag 徽记');
    expect(find.text('环湖步行 2 小时起，断桥—白堤—孤山—雷峰塔是经典动线。'),
        findsNothing, reason: '默认折叠，note 不显示');
    await tester.tap(find.text('攻略精要'));
    await tester.pumpAndSettle();
    expect(find.text('龙井路1号'), findsOneWidget);
    expect(find.text('环湖步行 2 小时起，断桥—白堤—孤山—雷峰塔是经典动线。'),
        findsOneWidget, reason: 'note 全文完整不截断');
  });

  testWidgets('2. food：area + note（无 addr/tag）', (tester) async {
    await tester.pumpWidget(_host((_) => {
          'name': '知味观',
          'area': '湖滨银泰 in77',
          'note': '做强项杭帮菜，人均 90。',
        }, ref: 'hz#food#2', name: '知味观'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('攻略精要'));
    await tester.pumpAndSettle();
    expect(find.text('湖滨银泰 in77'), findsOneWidget);
    expect(find.text('做强项杭帮菜，人均 90。'), findsOneWidget);
  });

  testWidgets('3. 名称漂移（行名≠卡名）→ 整段不渲染', (tester) async {
    await tester.pumpWidget(_host((_) => spotRow, ref: 'hz#spots#9', name: '灵隐寺'));
    await tester.pumpAndSettle();
    expect(find.text('攻略精要'), findsNothing);
  });

  testWidgets('4. 反查失败（null 行）→ 不渲染', (tester) async {
    await tester.pumpWidget(_host<Map<String, dynamic>?>((_) => null,
        ref: 'gone#spots#0', name: '任何'));
    await tester.pumpAndSettle();
    expect(find.text('攻略精要'), findsNothing);
  });

  testWidgets('5. 非法 ref → 不渲染', (tester) async {
    await tester.pumpWidget(_host((_) => spotRow, ref: 'bad-ref', name: '西湖'));
    await tester.pumpAndSettle();
    expect(find.text('攻略精要'), findsNothing);
  });

  testWidgets('6. 空内容行（note/addr/tag 全空）→ 不渲染', (tester) async {
    await tester.pumpWidget(_host((_) => {'name': '西湖'}, ref: 'hz#spots#0', name: '西湖'));
    await tester.pumpAndSettle();
    expect(find.text('攻略精要'), findsNothing);
  });
}
