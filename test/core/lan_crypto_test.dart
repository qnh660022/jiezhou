// V2.7.1 S2 · G6（最小可接受实现）：口令派生校验值 + HMAC-SHA256 完整性校验。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/core/lan_crypto.dart';

void main() {
  group('口令派生校验值', () {
    test('同口令两端派生同值、不同口令不同值', () {
      expect(lanPasscodeCheck('123456'), lanPasscodeCheck('123456'));
      expect(lanPasscodeCheck('123456'), isNot(lanPasscodeCheck('654321')));
    });

    test('校验值不含明文口令，且为 16 位十六进制', () {
      final v = lanPasscodeCheck('123456');
      expect(v, hasLength(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(v), isTrue);
      expect(v.contains('123456'), isFalse);
    });
  });

  group('HMAC 完整性校验', () {
    test('正确签名通过；篡改载荷失败', () {
      const payload = '{"group":{"id":"g1"}}';
      final mac = lanPayloadMac('123456', payload);
      expect(() => verifyLanPayloadMac('123456', payload, mac), returnsNormally);
      expect(
        () => verifyLanPayloadMac('123456', '$payload ', mac),
        throwsA(isA<FormatException>()),
      );
    });

    test('口令不一致 → 校验失败', () {
      const payload = '{"a":1}';
      final mac = lanPayloadMac('111111', payload);
      expect(() => verifyLanPayloadMac('222222', payload, mac),
          throwsA(isA<FormatException>()));
    });

    test('缺签名（老版本）→ 提示升级，禁止静默降级', () {
      expect(() => verifyLanPayloadMac('123456', '{}', null),
          throwsA(isA<FormatException>()));
      expect(() => verifyLanPayloadMac('123456', '{}', ''),
          throwsA(isA<FormatException>()));
    });
  });

  group('常量时间比较', () {
    test('相等/不等/长度不同', () {
      expect(constantTimeEquals('abc123', 'abc123'), isTrue);
      expect(constantTimeEquals('abc123', 'abc124'), isFalse);
      expect(constantTimeEquals('abc', 'abc123'), isFalse);
      expect(constantTimeEquals('', ''), isTrue);
    });
  });

  test('协议版本常量锁定为 2', () {
    expect(kLanProtoVersion, 2);
  });
}
