// V2.7.2 S12：PDF 行程总览页用例（weekdayCnOf / 摘要规则 / 备胎排除 / 分块）。
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/date_utils.dart';
import 'package:travel_assistant/export/pdf_builder.dart';

Map<String, dynamic> _day(int dayIndex, String date, int? epochDay,
    {List<Map<String, dynamic>>? items}) {
  return {
    'dayIndex': dayIndex,
    'date': date,
    if (epochDay != null) 'epochDay': epochDay,
    'items': items ?? const [],
  };
}

Map<String, dynamic> _item(String name, {String time = '', String? backupOf}) {
  return {'name': name, 'time': time, if (backupOf != null) 'backupOf': backupOf};
}

void main() {
  group('weekdayCnOf（星期唯一入口）', () {
    test('1. epoch 0 = 1970-01-01 周四', () {
      expect(weekdayCnOf(0), '周四');
      expect(weekdayCnOf(1), '周五');
      expect(weekdayCnOf(6), '周三', reason: '跨周样本');
    });

    test('2. 已知日期锚点：2000-01-01 周六（跨世纪）', () {
      // 1970-01-01 起累计天数：10957
      expect(weekdayCnOf(10957), '周六');
    });

    test('3. 跨年：2025-01-01 周三 / 2024-12-31 周二', () {
      // dateToEpochDay(2025-01-01) = 20089
      const d2025 = 20089;
      expect(weekdayCnOf(d2025), '周三');
      expect(weekdayCnOf(d2025 - 1), '周二');
    });

    test('4. 2026-09-19 周六（同年内跨周）', () {
      // 2026-01-01 周四；9/19 为年内第 262 天 → 周六
      const d = 20715; // 1970→2026-09-19 累计
      expect(weekdayCnOf(d), '周六');
    });
  });

  group('buildOverviewRows（摘要规则）', () {
    test('5. 摘要前 3：有时间 → HH:mm 名称；无 → 名称', () {
      final rows = buildOverviewRows([
        _day(1, '10月1日', 20696, items: [
          _item('升旗', time: '05:30'),
          _item('故宫', time: '09:00'),
          _item('酒店入住'),
        ]),
      ]);
      expect(rows, hasLength(1));
      expect(rows.first.summary,
          ['05:30 升旗', '09:00 故宫', '酒店入住']);
      expect(rows.first.count, 3);
    });

    test('6. 超过 3 条取前 3 并尾部「…等 N 项」', () {
      final rows = buildOverviewRows([
        _day(1, '10月1日', 20696, items: [
          _item('A', time: '08:00'),
          _item('B'),
          _item('C'),
          _item('D'),
          _item('E'),
        ]),
      ]);
      // 摘要只列前 3 条；条数 5 > 3 → 追加「…等 2 项」
      expect(rows.first.summary, ['08:00 A', 'B', 'C', '…等 2 项']);
      expect(rows.first.count, 5);
    });

    test('7. 空天 → 摘要「——」且计数 0', () {
      final rows = buildOverviewRows([
        _day(2, '10月2日', 20697),
      ]);
      expect(rows.first.summary, ['——']);
      expect(rows.first.count, 0);
    });

    test('8. 备胎（backupOf 非空含 \'\'）不进摘要也不计数', () {
      final rows = buildOverviewRows([
        _day(1, '10月1日', 20696, items: [
          _item('正式卡'),
          _item('无主备胎', backupOf: ''),
          _item('有主备胎', backupOf: 'card-1'),
        ]),
      ]);
      expect(rows.first.summary, ['正式卡']);
      expect(rows.first.count, 1);
    });

    test('9. 日期/星期透传正确（epochDay 缺省 → 空星期）', () {
      final rows = buildOverviewRows([
        _day(3, '10月3日', 20698),
        _day(4, '10月4日', null),
      ]);
      expect(rows[0].date, '10月3日');
      expect(rows[0].weekday, '周三');
      expect(rows[1].weekday, '');
    });
  });

  group('splitOverviewBlocks（手动分块 22 行/块）', () {
    test('10. 10 天行程 → 单块', () {
      final rows = [
        for (var i = 1; i <= 10; i++)
          OverviewRowData(
              dayIndex: i, date: 'd$i', weekday: '', count: 0, summary: const ['——'])
      ];
      final blocks = splitOverviewBlocks(rows);
      expect(blocks, hasLength(1));
      expect(blocks.first, hasLength(10));
    });

    test('11. 50 天行程 → 22/22/6 三块，行数守恒', () {
      final rows = [
        for (var i = 1; i <= 50; i++)
          OverviewRowData(
              dayIndex: i, date: 'd$i', weekday: '', count: 0, summary: const ['——'])
      ];
      final blocks = splitOverviewBlocks(rows);
      expect(blocks.map((b) => b.length).toList(), [22, 22, 6]);
      expect(blocks.expand((b) => b).length, 50);
    });

    test('12. buildTripPdf 含总览页可正常产出字节（冒烟）', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // 资产字体经 rootBundle 加载；flutter test 下可用
      final days = [
        for (var i = 1; i <= 25; i++)
          _day(i, '10月$i日', 20695 + i, items: [
            _item('景点$i', time: '09:00'),
          ]),
      ];
      final bytes = await buildTripPdf('行程', '测试 · 25 天', days,
          totalDays: 25, dateRange: '10月1日 - 10月25日', totalItems: 25);
      expect(bytes.lengthInBytes, greaterThan(5000));
    });
  });
}
