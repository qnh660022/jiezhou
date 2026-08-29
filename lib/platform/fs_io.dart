/// 原生 / 桌面：真实文件系统。
library;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<Uint8List> readFileBytes(String path) async => File(path).readAsBytes();

Future<void> clearTempDir() async {
  try {
    final dir = await getTemporaryDirectory();
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        try {
          if (f is File) {
            f.deleteSync();
          } else if (f is Directory) {
            f.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
    }
  } catch (_) {}
}

Future<void> persistErrorLog(String detail) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/startup_error.log');
    await f.writeAsString(
      '==== ${DateTime.now().toIso8601String()} ====\n$detail\n\n',
      mode: FileMode.append,
    );
    // 只保留最近 ~200KB，防止无限增长。
    if (await f.length() > 200 * 1024) {
      final content = await f.readAsString();
      await f.writeAsString(content.substring(content.length ~/ 2));
    }
  } catch (_) {
    // 日志失败不能再抛，否则自愈本身变成错误源。
  }
}