/// gzip 门面：原生用 dart:io 的 GZipCodec，Web 用 archive 包。
/// 两种实现均为标准 gzip，跨端数据可互读互导。
library;
import 'dart:typed_data';

import 'gzip_io.dart' if (dart.library.js_interop) 'gzip_web.dart' as impl;

/// gzip 压缩（原始二进制载荷）。
Uint8List gzipEncode(List<int> input) => impl.gzipEncode(input);

/// gzip 解压。
List<int> gzipDecode(Uint8List input) => impl.gzipDecode(input);