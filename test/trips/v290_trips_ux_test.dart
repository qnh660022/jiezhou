// V2.9.0 行程域 UX 修复轮回归测试（小而实，纯函数/组件层）：
// * sanitizeFileName 文件名清洗（trips_home 备份导出，正则 raw string 回归）；
// * DayPickList 选天数据映射（1 基 D 序号 + 月日星期 + 安排数 + 当前天高亮）；
// * RangeCalendarSheet 单日模式（起=终一次点击）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/features/trips/trip_utils.dart';
import 'package:travel_assistant/features/trips/widgets/day_pick_sheet.dart';
import 'package:travel_assistant/features/trips/widgets/range_calendar_sheet.dart';

void main() {
  group('V2.9.0 sanitizeFileName（备份文件名清洗）', () {
    test('正常中英文名保持不变（小写 r/n/t 不被误替换）', () {
      // 回归：此前 raw string 正则把字面 `\\r\\n\\t` 当成字符类成员，
      // 名字里的小写 r/n/t 会被替换成下划线。
      expect(sanitizeFileName('travel'), 'travel');
      expect(sanitizeFileName('north trip'), 'north trip');
      expect(sanitizeFileName('东京五日游'), '东京五日游');
    });

    test('路径非法字符替换为下划线', () {
      expect(sanitizeFileName(r'a/b\c:d*e?f"g<h>i|j'), 'a_b_c_d_e_f_g_h_i_j');
    });

    test('真实回车/换行/制表符替换为下划线', () {
      expect(sanitizeFileName('a\tb'), 'a_b');
      expect(sanitizeFileName('a\rb'), 'a_b');
      expect(sanitizeFileName('a\nb'), 'a_b');
    });

    test('首尾空白裁剪；全空白回落空串（调用方负责兜底命名）', () {
      expect(sanitizeFileName('  东京  '), '东京');
      expect(sanitizeFileName('   '), '');
    });
  });

  group('V2.9.0 DayPickList 选天数据映射', () {
    late int start;
    setUp(() {
      // 2026-09-25（周五）起的三天行程
      start = dateToEpochDay(DateTime(2026, 9, 25));
    });

    Future<void> pumpList(WidgetTester tester,
        {int? selectedDay, int Function(int)? itemCountOf}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayPickList(
            startDay: start,
            endDay: start + 2,
            selectedDay: selectedDay,
            itemCountOf: itemCountOf,
            onPicked: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('1 基 D 序号 + 月日 + 星期（V2.8 0 基 D0 口径不再出现）',
        (tester) async {
      await pumpList(tester);
      expect(find.text('D1'), findsOneWidget);
      expect(find.text('D2'), findsOneWidget);
      expect(find.text('D3'), findsOneWidget);
      expect(find.text('D0'), findsNothing);
      expect(find.text('9月25日 周五'), findsOneWidget);
      expect(find.text('9月26日 周六'), findsOneWidget);
      expect(find.text('9月27日 周日'), findsOneWidget);
    });

    testWidgets('当天安排数透传渲染（N 项）', (tester) async {
      await pumpList(tester, itemCountOf: (day) => (day - start) * 2);
      expect(find.text('0 项'), findsOneWidget);
      expect(find.text('2 项'), findsOneWidget);
      expect(find.text('4 项'), findsOneWidget);
    });

    testWidgets('selectedDay 命中当天高亮（勾标）且只标一天', (tester) async {
      await pumpList(tester, selectedDay: start + 1);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await pumpList(tester);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('V2.9.0 RangeCalendarSheet 单日模式', () {
    testWidgets('一次点击即可确定（起=终），返回所选 epochDay', (tester) async {
      RangeCalendarResult? got;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  got = await showRangeCalendarSheet(
                    context,
                    initialMonth: DateTime(2026, 9),
                    mode: RangeCalendarMode.single,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 未选择时确认钮显示占位文案且不可点
      expect(find.text('请选择日期'), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      // 选择后按钮立即变为可确认态（单日模式一次点击即选中）
      expect(find.textContaining('确定 · 9月15日'), findsOneWidget);
      await tester.tap(find.textContaining('确定 · 9月15日'));
      await tester.pumpAndSettle();

      expect(got, isNotNull);
      expect(got!.startDay, epochDayOf(DateTime(2026, 9, 15)));
      expect(got!.endDay, got!.startDay);
    });
  });
}
