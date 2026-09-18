/// 启动锁口令学（V2.7.1 S7.2 · F3）：PBKDF2-HMAC-SHA256 + 常量时间比较。
///
/// 纯 Dart、无 IO、无插件依赖，因此可被 `flutter test` 完整覆盖，也能在
/// Android / Web 上跑出**逐位一致**的结果（规格 §S7.2「Android/Web 行为一致」）。
///
/// 与 S2.4（G6 局域网）共用 `crypto` 包的 Hmac/sha256 原语；本版**不引入**
/// `cryptography` 包（仅为一个 PBKDF2 拉入额外依赖不划算，且 RFC 2898 的
/// PBKDF2 用 HMAC 原语 20 行即可正确实现，已有单测对齐公开测试向量）。
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// HMAC-SHA256 输出长度（字节）。
const int _kSha256Bytes = 32;

/// RFC 2898 PBKDF2-HMAC-SHA256。
///
/// [length] 不足一个块时截断；[iterations] 必须 ≥ 1。
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  required int length,
}) {
  if (iterations < 1) throw ArgumentError.value(iterations, 'iterations', '必须 ≥ 1');
  if (length < 1) throw ArgumentError.value(length, 'length', '必须 ≥ 1');
  final mac = Hmac(sha256, password);
  final blocks = (length + _kSha256Bytes - 1) ~/ _kSha256Bytes;
  final out = Uint8List(blocks * _kSha256Bytes);

  for (var i = 1; i <= blocks; i++) {
    // U1 = PRF(P, S || INT_BE32(i))
    final seed = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..[salt.length] = (i >> 24) & 0xff
      ..[salt.length + 1] = (i >> 16) & 0xff
      ..[salt.length + 2] = (i >> 8) & 0xff
      ..[salt.length + 3] = i & 0xff;

    var u = mac.convert(seed).bytes;
    final t = List<int>.from(u);
    for (var j = 1; j < iterations; j++) {
      u = mac.convert(u).bytes;
      for (var k = 0; k < _kSha256Bytes; k++) {
        t[k] ^= u[k];
      }
    }
    out.setRange((i - 1) * _kSha256Bytes, i * _kSha256Bytes, t);
  }
  return Uint8List.sublistView(out, 0, length);
}

/// 生成 [bytes] 字节密码学随机盐（十六进制字符串）。
String generateSaltHex([int bytes = 16]) {
  final rnd = Random.secure();
  final buf = Uint8List(bytes);
  for (var i = 0; i < bytes; i++) {
    buf[i] = rnd.nextInt(256);
  }
  return _toHex(buf);
}

/// 十六进制解码；非法输入返回 null（不抛，调用方按「锁损坏」处理）。
Uint8List? hexToBytes(String hex) {
  if (hex.isEmpty || hex.length.isOdd) return null;
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final b = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (b == null) return null;
    out[i] = b;
  }
  return out;
}

/// 常量时间比较（逐字节 XOR 累积；长度差异同样纳入结果）。
///
/// 规格 §S7.2 硬性要求：**禁止**用 `==` 直接比对哈希串。
bool constantTimeEqualsBytes(List<int> a, List<int> b) {
  var diff = a.length ^ b.length;
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

String _toHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
