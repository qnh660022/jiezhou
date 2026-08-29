/// 原生 / 桌面：dart:io GZipCodec。
library;
import 'dart:io';
import 'dart:typed_data';

Uint8List gzipEncode(List<int> input) =>
    Uint8List.fromList(GZipCodec().encode(input));

List<int> gzipDecode(Uint8List input) => GZipCodec().decode(input);