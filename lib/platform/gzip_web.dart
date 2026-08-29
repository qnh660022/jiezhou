/// Web：archive 包的 GZip 编解码（标准 gzip，与原生互通）。
library;
import 'dart:typed_data';
import 'package:archive/archive.dart';

Uint8List gzipEncode(List<int> input) =>
    Uint8List.fromList(GZipEncoder().encode(Uint8List.fromList(input)));

List<int> gzipDecode(Uint8List input) =>
    Uint8List.fromList(GZipDecoder().decodeBytes(input));