import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/uid.dart';

void main() {
  group('newId 格式', () {
    test('前缀 + 下划线 + 时间戳36进制 + 6位随机', () {
      final id = newId('trip');
      expect(id.startsWith('trip_'), isTrue);
      final body = id.substring('trip_'.length);
      // 时间戳段至少 7 位（当前毫秒数 36 进制约 8 位）+ 随机 6 位
      expect(body.length, greaterThanOrEqualTo(13));
      expect(RegExp(r'^[0-9a-z]+$').hasMatch(body), isTrue,
          reason: '只能含小写字母与数字');
    });

    test('自定义前缀原样保留', () {
      expect(newId('expense').startsWith('expense_'), isTrue);
      expect(newId('checklist').startsWith('checklist_'), isTrue);
    });

    test('大量生成基本不碰撞', () {
      final seen = <String>{};
      for (var i = 0; i < 5000; i++) {
        seen.add(newId('x'));
      }
      expect(seen.length, 5000);
    });
  });
}
