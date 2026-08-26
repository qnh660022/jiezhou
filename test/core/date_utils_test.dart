import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/date_utils.dart';

void main() {
  group('epochDay 互转', () {
    test('Unix 纪元锚点', () {
      expect(dateToEpochDay(DateTime(1970, 1, 1)), 0);
      expect(epochDayToDate(0), DateTime(1970, 1, 1));
    });

    test('已知日期：2024-01-01 = 19723', () {
      expect(dateToEpochDay(DateTime(2024, 1, 1)), 19723);
      expect(epochDayToDate(19723), DateTime(2024, 1, 1));
    });

    test('随机区间往返稳定', () {
      var d = dateToEpochDay(DateTime(2020, 1, 1));
      final end = dateToEpochDay(DateTime(2035, 1, 1));
      while (d <= end) {
        expect(dateToEpochDay(epochDayToDate(d)), d, reason: 'epochDay=$d');
        d += 97; // 步进采样
      }
    });

    test('todayEpochDay 与本地今天一致', () {
      expect(todayEpochDay(), dateToEpochDay(DateTime.now()));
    });
  });

  group('行程天数与夹紧', () {
    test('tripDays 闭区间', () {
      expect(tripDays(10, 20), 11);
      expect(tripDays(10, 10), 1);
      expect(tripDays(20, 10), 0, reason: '起晚于止为空行程');
    });

    test('dayIndexOf 夹到 [1, 天数]', () {
      expect(dayIndexOf(10, 20, 10), 1);
      expect(dayIndexOf(10, 20, 15), 6);
      expect(dayIndexOf(10, 20, 20), 11);
      expect(dayIndexOf(10, 20, 1), 1);
      expect(dayIndexOf(10, 20, 99), 11);
      expect(dayIndexOf(20, 10, 15), 0, reason: '空行程');
    });

    test('clampEpochDay 缩区间保数据', () {
      expect(clampEpochDay(5, 10, 20), 10);
      expect(clampEpochDay(15, 10, 20), 15);
      expect(clampEpochDay(30, 10, 20), 20);
    });
  });

  group('中文文案', () {
    test('周几与月日（2000-01-01 是周六）', () {
      final d = DateTime(2000, 1, 1);
      expect(fmtWeekday(d), '周六');
      expect(fmtMonthDay(d), '1月1日');
      expect(fmtFullDate(d), '1月1日 周六');
      expect(fmtIsoDate(d), '2000-01-01');
    });

    test('周日文案', () {
      // 2000-01-02 周日
      expect(fmtWeekday(DateTime(2000, 1, 2)), '周日');
    });

    test('epochDay 包装函数', () {
      final e = dateToEpochDay(DateTime(2000, 1, 1));
      expect(fmtMonthDayOfEpoch(e), '1月1日');
      expect(fmtFullDateOfEpoch(e), '1月1日 周六');
    });
  });

  test('isSameDay 忽略时分秒', () {
    expect(isSameDay(DateTime(2025, 8, 25, 8), DateTime(2025, 8, 25, 23)), isTrue);
    expect(isSameDay(DateTime(2025, 8, 25), DateTime(2025, 8, 26)), isFalse);
  });
}
