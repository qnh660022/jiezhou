/// 专有二进制备份信封。
///
/// 把备份数据（一个 JSON 对象）包成一段不易手改的二进制：
///   [magic 4B][version 1B][flags 1B][payloadLen 4B BE][payload]
/// 其中 payload = GZip(JSON)。这样导出的文件既不是 .json，也不是明文，
/// 而是「旅途助手」自己的格式，无法被其它软件直接打开。
///
/// 两种备份用不同魔数区分（即「另一格式」）：
///   * 旅游团备份  → 魔数 "TA1G"，建议扩展名 `.tav`
///   * 行程备份    → 魔数 "TA1T"，建议扩展名 `.tat`
library;

import 'dart:convert';
import 'dart:typed_data';

import '../platform/gzip.dart';

/// 旅游团备份魔数 "TA1G"
const List<int> kGroupBackupMagic = <int>[0x54, 0x41, 0x31, 0x47];

/// 行程备份魔数 "TA1T"
const List<int> kTripBackupMagic = <int>[0x54, 0x41, 0x31, 0x54];

/// 全量备份魔数 "TA1A"
const List<int> kFullBackupMagic = <int>[0x54, 0x41, 0x31, 0x41];

const int _kVersion = 1;
const int _kFlagGzip = 1 << 0;

/// 把备份 Map 编码为专有二进制文件内容。
Uint8List encodeBackup(List<int> magic, Map<String, dynamic> data) {
  final jsonBytes = utf8.encode(jsonEncode(data));
  final payload = gzipEncode(jsonBytes);
  final out = ByteData(10 + payload.length);
  for (var i = 0; i < 4; i++) {
    out.setUint8(i, magic[i]);
  }
  out.setUint8(4, _kVersion);
  out.setUint8(5, _kFlagGzip);
  out.setUint32(6, payload.length, Endian.big);
  for (var i = 0; i < payload.length; i++) {
    out.setUint8(10 + i, payload[i]);
  }
  return out.buffer.asUint8List();
}

/// 解码专有二进制备份内容。
///
/// [acceptedMagics] 为 null 时接受任意已识别魔数；传入则只接受指定类型。
/// 魔数不匹配 / 版本不支持 / 载荷损坏时抛 [FormatException]。
Map<String, dynamic> decodeBackup(Uint8List bytes,
    {List<List<int>>? acceptedMagics}) {
  if (bytes.length < 10) {
    throw const FormatException('备份文件长度不足');
  }
  final magic = <int>[bytes[0], bytes[1], bytes[2], bytes[3]];
  final all = acceptedMagics ?? <List<int>>[kGroupBackupMagic, kTripBackupMagic];
  if (!all.any((m) => _sameMagic(m, magic))) {
    throw const FormatException('不是「旅途助手」识别的备份文件');
  }
  final version = bytes[4];
  if (version != _kVersion) {
    throw FormatException('不支持的备份版本: $version');
  }
  final flags = bytes[5];
  final len = _u32(bytes, 6);
  if (bytes.length < 10 + len) {
    throw const FormatException('备份文件长度不匹配');
  }
  final payload = bytes.sublist(10, 10 + len);
  final jsonBytes =
      (flags & _kFlagGzip) != 0 ? gzipDecode(payload) : payload;
  final decoded = jsonDecode(utf8.decode(jsonBytes));
  if (decoded is! Map) {
    throw const FormatException('备份根节点必须是对象');
  }
  return (decoded as Map).cast<String, dynamic>();
}

/// 判断一段字节是否本应用专有备份信封（导入时区分旧 JSON 文本 / 二进制）。
bool looksLikeBackupEnvelope(Uint8List bytes,
    {List<List<int>>? acceptedMagics}) {
  if (bytes.length < 4) return false;
  final magic = <int>[bytes[0], bytes[1], bytes[2], bytes[3]];
  final all = acceptedMagics ?? <List<int>>[kGroupBackupMagic, kTripBackupMagic];
  return all.any((m) => _sameMagic(m, magic));
}

bool _sameMagic(List<int> a, List<int> b) =>
    a.length == 4 &&
    b.length == 4 &&
    a[0] == b[0] &&
    a[1] == b[1] &&
    a[2] == b[2] &&
    a[3] == b[3];

int _u32(Uint8List b, int off) =>
    (b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];
