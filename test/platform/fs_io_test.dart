/// 回归测试：fs_io.writeFileString 自动创建缺失的父目录。
/// 背景：攻略缓存写入 guide_cache/city/<key>.json 时因父目录不存在抛
/// FileSystemException，导致 Android 端首次打开攻略页整页失败。
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/platform/fs_io.dart' as fs;

void main() {
  test('writeFileString 对不存在的多级父目录自动创建并写入成功', () async {
    final base = await Directory.systemTemp.createTemp('fs_io_test');
    try {
      final target =
          '${base.path}/level1/level2/city/beijing.json';
      await fs.writeFileString(target, '{"k":"v"}');
      expect(File(target).readAsStringSync(), '{"k":"v"}');
      // 无临时文件残留
      expect(File('$target.tmp').existsSync(), isFalse);
    } finally {
      base.deleteSync(recursive: true);
    }
  });
}
