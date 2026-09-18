/// 局域网同步安全工具（V2.7.1 S2.4 · G6「最小可接受实现」）。
///
/// 【本版裁定】采用规格书 §S2.4.8 的最小可接受实现：
///   * 口令派生短校验值（发现包不再出现明文口令特征）；
///   * 载荷 HMAC-SHA256 完整性校验（GET/POST /snapshot）；
///   * 协议版本协商（[kLanProtoVersion]，不匹配明确提示升级，**禁止静默降级**）；
///   * 界面明示「快照仍为明文传输」的风险（不加密载荷）。
///
/// ⚠️ 已知风险（已按 §17.4 登记为规格偏差）：
/// 快照体**未加密**——同 Wi-Fi 下具备抓包能力的第三方可读到账本明文；
/// 本实现只保证「口令不直接暴露」与「篡改可被发现」。
/// 完整方案（PBKDF2-HMAC-SHA256 派生会话密钥 + AES-256-GCM 二进制信封
/// `[magic 'LSYE'][ver][salt][nonce][ciphertext+tag]`）见规格书 §S2.4.2~3，
/// 后续版本可直接替换本文件而不影响调用方。
///
/// 本文件纯 Dart 无 IO，可被 `flutter test` 完全覆盖。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 局域网同步协议版本（发现包与 HTTP 头携带）。
///
/// 收到与本值不一致的 `proto` 时，双端必须明确提示「对方版本过旧，请双方升级」，
/// **不得**降级为无校验明文。
const int kLanProtoVersion = 2;

/// 派生域分隔（避免与 PIN 哈希等其它用途共用同一 MAC 输入）。
const String kLanCheckDomain = 'jiezhou-lan-v2';

/// 口令派生短校验值：`HMAC-SHA256(domain, passcode)` 的十六进制前 16 字符。
///
/// 两端用同一 6 位口令可算出同值 → 发现包只带校验值，**不出现明文口令**。
String lanPasscodeCheck(String passcode) {
  final mac = Hmac(sha256, utf8.encode(kLanCheckDomain)).convert(utf8.encode(passcode));
  return mac.toString().substring(0, 16);
}

/// 载荷 HMAC（以口令为密钥），返回十六进制字符串。
String lanPayloadMac(String passcode, String payload) {
  final mac = Hmac(sha256, utf8.encode(passcode)).convert(utf8.encode(payload));
  return mac.toString();
}

/// 常量时间相等比较（逐字节 XOR 累积；长度差异也纳入结果）。
bool constantTimeEquals(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var diff = x.length ^ y.length;
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    diff |= x[i] ^ y[i];
  }
  return diff == 0;
}

/// 校验载荷完整性；缺失或不匹配抛 [FormatException]（调用方转成友好文案）。
void verifyLanPayloadMac(String passcode, String payload, String? mac) {
  if (mac == null || mac.isEmpty) {
    throw const FormatException('对方版本过旧或未带完整性校验，请双方升级后再同步');
  }
  if (!constantTimeEquals(lanPayloadMac(passcode, payload), mac)) {
    throw const FormatException('快照完整性校验失败：口令不一致或数据已被改动');
  }
}
