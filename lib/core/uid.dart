/// 轻量唯一 id 生成：前缀 + 时间戳(36 进制) + 6 位随机(36 进制)。
///
/// 无需任何三方包；同毫秒内多次调用靠随机段区分，
/// 时间戳段保证 id 大体按创建时间有序，便于调试与导出对齐。
library;

import 'dart:math';

const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

/// 生成形如 `trip_lxq3z9k1ab12xy` 的 id。
///
/// [prefix] 建议使用实体短名：trip / item / check / photo / group /
/// member / expense / settle / category。传入 [random] 仅供测试注入。
String newId(String prefix, {Random? random}) {
  assert(prefix.isNotEmpty, 'id 前缀不能为空');
  final rng = random ?? Random.secure();
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rand = String.fromCharCodes(
    List.generate(6, (_) => _alphabet.codeUnitAt(rng.nextInt(_alphabet.length))),
  );
  return '${prefix}_$ts$rand';
}
