/// Web：无真实文件系统，按路径读写与错误日志落盘均为空实现/抛错。
library;
import 'dart:typed_data';

Future<Uint8List> readFileBytes(String path) async =>
    throw UnsupportedError('网页端不提供按路径读取文件');

Future<void> clearTempDir() async {}

Future<void> persistErrorLog(String detail) async {}

Future<String?> writableDir() async => null;

Future<void> writeFileString(String path, String content) async {}

Future<String?> readFileString(String path) async => null;

Future<void> deleteFile(String path) async {}