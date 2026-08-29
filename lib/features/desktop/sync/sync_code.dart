/// 多端同步「同步码」：快照 JSON → gzip → base64url 文本；可分块（二维码/口令）。
///
/// 纯 Dart 无 IO，编解码可在单测覆盖。分块头格式：
///   `TSQ1|<total>|<index>|<chunk>`（index 从 1 开始）。
library;

import 'dart:convert';

import '../../../platform/gzip.dart';

/// 单块内容最大字符数（保证单张二维码可容纳，且便于复制粘贴）
const int kSyncCodeChunkLen = 800;

/// 允许的最大块数（超出则提示改用文件互传）
const int kSyncCodeMaxChunks = 12;

/// 分块头版本
const String _kChunkTag = 'TSQ1';

/// 快照 JSON → 同步码（gzip + base64url）。
String encodeSyncCode(String json) {
  final bytes = utf8.encode(json);
  final zipped = gzipEncode(bytes);
  return base64Url.encode(zipped);
}

/// 同步码 → 快照 JSON（base64url 解码 + gunzip）。非法输入抛 [FormatException]。
String decodeSyncCode(String code) {
  final trimmed = code.trim();
  if (trimmed.isEmpty) throw const FormatException('同步码为空');
  try {
    final zipped = base64Url.decode(trimmed);
    final bytes = gzipDecode(zipped);
    return utf8.decode(bytes);
  } catch (e) {
    throw FormatException('同步码无法解码，请核对内容');
  }
}

/// 把同步码切分为带块头的分块列表。
List<String> chunkSyncCode(String code) {
  final total = (code.length / kSyncCodeChunkLen).ceil();
  if (total > kSyncCodeMaxChunks) {
    throw StateError('同步码过长（$total 块，超过 $kSyncCodeMaxChunks 块上限），请改用备份文件互传');
  }
  final out = <String>[];
  for (var i = 0; i < total; i++) {
    final start = i * kSyncCodeChunkLen;
    final end = (start + kSyncCodeChunkLen).clamp(0, code.length);
    final chunk = code.substring(start, end);
    out.add('$_kChunkTag|$total|${i + 1}|$chunk');
  }
  return out;
}

/// 解析一块：返回 (total, index, data)；非分块头返回 null。
(int, int, String)? parseChunk(String raw) {
  final s = raw.trim();
  if (!s.startsWith('$_kChunkTag|')) return null;
  final parts = s.split('|');
  if (parts.length < 4) return null;
  final total = int.tryParse(parts[1]);
  final index = int.tryParse(parts[2]);
  if (total == null || index == null) return null;
  return (total, index, parts.sublist(3).join('|'));
}

/// 把分块合并回完整同步码（按 index 排序，缺失块抛 [StateError]）。
String combineChunks(List<String> chunks) {
  final map = <int, String>{};
  var total = -1;
  for (final c in chunks) {
    final parsed = parseChunk(c);
    if (parsed == null) continue;
    final (t, i, data) = parsed;
    if (total < 0) {
      total = t;
    } else if (total != t) {
      throw StateError('分块总数不一致');
    }
    map[i] = data;
  }
  if (map.isEmpty) throw StateError('没有有效的同步码分块');
  final buf = StringBuffer();
  for (var i = 1; i <= total; i++) {
    final data = map[i];
    if (data == null) throw StateError('缺少第 $i 块，请重新扫码/粘贴');
    buf.write(data);
  }
  return buf.toString();
}

/// 同步码是否可被二维码承载（未分块或分块数在限制内）。
bool syncCodeFitsQr(String code) {
  final total = (code.length / kSyncCodeChunkLen).ceil();
  return total <= kSyncCodeMaxChunks;
}
