// V2.7.1 S7.2 · F3：启动锁（PBKDF2-HMAC-SHA256 / 常量时间比较 / 失败冷却 / 冷启动门控）。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/core/app_lock_crypto.dart';
import 'package:travel_assistant/platform/app_lock.dart';

String _pbkdf2Hex(String password, String salt, int iterations) {
  final out = pbkdf2HmacSha256(
    password: password.codeUnits,
    salt: salt.codeUnits,
    iterations: iterations,
    length: 32,
  );
  return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('口令学（可被公开测试向量对齐）', () {
    test('1. PBKDF2-HMAC-SHA256 命中公开向量（c=1 / c=2）', () {
      // password="password", salt="salt", dkLen=32 的标准向量
      expect(_pbkdf2Hex('password', 'salt', 1),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(_pbkdf2Hex('password', 'salt', 2),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    });

    test('2. 迭代次数与 PIN 位数符合规格（100000 / 6 位）', () {
      expect(kPinIterations, 100000);
      expect(kPinLength, 6);
      expect(kMaxPinFailures, 5);
      expect(kPinCooldown.inSeconds, 30);
    });

    test('3. 常量时间比较：等值 / 不等 / 长度不同', () {
      expect(constantTimeEqualsBytes([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeEqualsBytes([1, 2, 3], [1, 2, 4]), isFalse);
      expect(constantTimeEqualsBytes([1, 2, 3], [1, 2, 3, 4]), isFalse);
      expect(constantTimeEqualsBytes(const [], const []), isTrue);
    });

    test('4. 加盐：同 PIN 不同盐得到不同哈希；盐为 16 字节随机', () {
      final s1 = generateSaltHex();
      final s2 = generateSaltHex();
      expect(s1.length, 32, reason: '16 字节 = 32 个十六进制字符');
      expect(s1, isNot(s2));
      expect(hashPin('123456', s1, iterations: 1000),
          isNot(hashPin('123456', s2, iterations: 1000)));
      expect(matchesPin('123456', s1, hashPin('123456', s1, iterations: 1000),
          iterations: 1000), isTrue);
      expect(matchesPin('123457', s1, hashPin('123456', s1, iterations: 1000),
          iterations: 1000), isFalse);
    });

    test('5. 哈希是十六进制且不含明文 PIN', () {
      final salt = generateSaltHex();
      final h = hashPin('654321', salt, iterations: 500);
      expect(hexToBytes(h)!.length, 32);
      expect(h.contains('654321'), isFalse);
    });

    test('6. 损坏的盐/哈希不放行', () {
      expect(matchesPin('123456', 'zz', 'zz'), isFalse);
      expect(hexToBytes('abc'), isNull, reason: '奇数长度非法');
    });
  });

  group('AppLockService（仅本地 SharedPreferences）', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppLockGate.reset();
    });

    tearDown(() => AppLockGate.reset());

    test('7. 未开启锁时：verify 恒通过，enabled=false', () async {
      final svc = await AppLockService.cached();
      expect(svc.enabled, isFalse);
      expect(await svc.verify('000000'), isTrue);
    });

    test('8. 开启后：正确 PIN 通过、错误 PIN 不通过', () async {
      final svc = await AppLockService.cached();
      await svc.setPin('123456');
      expect(svc.enabled, isTrue);
      expect(svc.saltHex, isNotNull);
      expect(svc.hashHex, isNotNull);

      AppLockService.sessionUnlocked = false;
      expect(await svc.verify('123456'), isTrue);
      expect(await svc.verify('123457'), isFalse);
      expect(svc.failCount, 1);
    });

    test('9. 连续 5 次失败 → 30 秒冷却，冷却期内正确 PIN 也被拒', () async {
      final svc = await AppLockService.cached();
      await svc.setPin('123456');
      final now = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < kMaxPinFailures; i++) {
        expect(await svc.verify('000000', nowMs: now), isFalse);
      }
      expect(svc.inCooldown(now), isTrue);
      expect(svc.cooldownRemainingMs(now), kPinCooldown.inMilliseconds);
      // 冷却期内即使 PIN 正确也拒绝（且不再累加计数）
      expect(await svc.verify('123456', nowMs: now), isFalse);
      // 冷却结束恢复
      final after = now + kPinCooldown.inMilliseconds + 1;
      expect(svc.inCooldown(after), isFalse);
      expect(await svc.verify('123456', nowMs: after), isTrue);
    });

    test('10. 关闭锁必须先验证当前 PIN；失败不改状态，成功清空全部键', () async {
      final svc = await AppLockService.cached();
      await svc.setPin('123456');
      expect(await svc.disable('999999'), isFalse);
      expect(svc.enabled, isTrue, reason: '验证失败不关锁');

      expect(await svc.disable('123456'), isTrue);
      expect(svc.enabled, isFalse);
      expect(svc.saltHex, isNull);
      expect(svc.hashHex, isNull);
    });

    test('11. PIN 形态校验：非 6 位数字直接拒绝', () async {
      final svc = await AppLockService.cached();
      await expectLater(svc.setPin('12345'), throwsArgumentError);
      await expectLater(svc.setPin('abcdef'), throwsArgumentError);
      await expectLater(svc.setPin('1234567'), throwsArgumentError);
    });
  });

  group('AppLockGate 冷启动门控', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppLockGate.reset();
    });

    tearDown(() => AppLockGate.reset());

    test('12. 未开启锁 → 不锁', () async {
      expect(await AppLockGate.load(), isFalse);
      expect(AppLockGate.ready, isTrue);
      expect(AppLockGate.locked, isFalse);
    });

    test('13. 已开启且本次冷启动未解锁 → 锁', () async {
      final svc = await AppLockService.cached();
      await svc.setPin('123456');
      AppLockService.sessionUnlocked = false; // 模拟重启（内存态清零）
      expect(await AppLockGate.load(), isTrue);
      expect(AppLockGate.locked, isTrue);
    });

    test('14. 解锁后不锁；重新武装后再次锁（下次冷启动语义）', () async {
      final svc = await AppLockService.cached();
      await svc.setPin('123456');
      AppLockService.sessionUnlocked = false;
      await AppLockGate.load();
      expect(AppLockGate.locked, isTrue);

      AppLockGate.markUnlocked();
      expect(AppLockGate.locked, isFalse);
      expect(AppLockService.sessionUnlocked, isTrue);

      AppLockGate.rearm();
      AppLockService.sessionUnlocked = false;
      await AppLockGate.load();
      expect(AppLockGate.locked, isTrue);
    });
  });
}
