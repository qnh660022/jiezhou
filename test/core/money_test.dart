import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/money.dart';

void main() {
  group('parseMoney 严格解析（元 -> 分）', () {
    test('合法整数元', () {
      expect(parseMoney('0'), 0);
      expect(parseMoney('12'), 1200);
      expect(parseMoney('007'), 700);
      expect(parseMoney(' 12 '), 1200, reason: '首尾空白允许');
    });

    test('合法小数元（最多两位）', () {
      expect(parseMoney('12.5'), 1250);
      expect(parseMoney('12.34'), 1234);
      expect(parseMoney('0.99'), 99);
      expect(parseMoney('0.05'), 5);
    });

    test('非法格式返回 null', () {
      for (final bad in ['', '   ', '.5', '1.', '-1', '+1',
          '1.234', 'abc', '1,000', '12.3.4', '１２']) {
        expect(parseMoney(bad), isNull, reason: '"$bad" 应非法');
      }
    });
  });

  group('formatMoney 千分位两位小数', () {
    test('基础与分组', () {
      expect(formatMoney(0), '0.00');
      expect(formatMoney(5), '0.05');
      expect(formatMoney(50), '0.50');
      expect(formatMoney(100), '1.00');
      expect(formatMoney(1234567), '12,345.67');
      expect(formatMoney(999999999), '9,999,999.99');
    });

    test('负数带符号', () {
      expect(formatMoney(-50), '-0.50');
      expect(formatMoney(-1234567), '-12,345.67');
    });

    test('parse/format 往返一致', () {
      const samples = ['0', '3.07', '128.99', '1024', '99999.99'];
      for (final s in samples) {
        final cents = parseMoney(s)!;
        expect(parseMoney(formatMoney(cents)), cents, reason: s);
      }
    });
  });
}
