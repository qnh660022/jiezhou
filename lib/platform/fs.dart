/// 文件系统门面：原生读写真实文件系统，Web 端相应能力降级/禁用。
library;
import 'dart:typed_data';

import 'fs_io.dart' if (dart.library.js_interop) 'fs_web.dart' as impl;

/// 按路径读取文件字节。仅在原生端可用；Web 端请改用选中文件自带的字节。
Future<Uint8List> readFileBytes(String path) => impl.readFileBytes(path);

/// 清空临时目录。Web 端为无操作。
Future<void> clearTempDir() => impl.clearTempDir();

/// 把错误日志追写入本地存储。Web 端当前为无操作（错误仍会走错误屏提示）。
Future<void> persistErrorLog(String detail) => impl.persistErrorLog(detail);