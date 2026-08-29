/// 原生 / 桌面：Documents 下的 travel_v2.sqlite；测试环境改用内存库。
library;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor create() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    // 测试沙箱没有平台通道；closeStreamsSynchronously 让流查询在最后一个
    // 监听者取消时同步关闭，避免内部 Timer 批处理在 widget 测试收尾遗留定时器。
    return DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    );
  }
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'travel_v2.sqlite'));
    return NativeDatabase(file);
  });
}