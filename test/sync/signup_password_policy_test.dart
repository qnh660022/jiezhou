/// 密码强度策略单测（V2.6.2）：注册密码 ≥8 位且须同时含字母与数字。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/sync/sync_account.dart';

void main() {
  group('signupPasswordIssue', () {
    test('合规密码返回 null', () {
      expect(signupPasswordIssue('abcd1234'), isNull);
      expect(signupPasswordIssue('Abcd1234!@#'), isNull);
      expect(signupPasswordIssue('a1b2c3d4e5'), isNull);
      expect(signupPasswordIssue('12345678a'), isNull);
      expect(signupPasswordIssue('AAAAAAAA1'), isNull);
    });

    test('不足 8 位 → password_short（即使含字母+数字）', () {
      expect(signupPasswordIssue('a1'), 'password_short');
      expect(signupPasswordIssue('ab12'), 'password_short');
      expect(signupPasswordIssue('abc123'), 'password_short');
      expect(signupPasswordIssue('abc1234'), 'password_short');
    });

    test('缺字母 → password_weak', () {
      expect(signupPasswordIssue('12345678'), 'password_weak');
      expect(signupPasswordIssue('1234567890'), 'password_weak');
    });

    test('缺数字 → password_weak', () {
      expect(signupPasswordIssue('abcdefgh'), 'password_weak');
      expect(signupPasswordIssue('Abcdefghij'), 'password_weak');
    });

    test('8 位边界值判定正确', () {
      expect(signupPasswordIssue('1234567a'), isNull); // 恰好 8 位合规
      expect(signupPasswordIssue('1234567'), 'password_short'); // 7 位
      expect(signupPasswordIssue('12345678'), 'password_weak'); // 8 位纯数字
    });
  });
}
