/// drift 数据库连接门面：原生用文件库 / 测试用内存库，Web 用 sqlite-WASM。
library;

import 'package:drift/drift.dart';

import 'db_connection_io.dart'
    if (dart.library.js_interop) 'db_connection_web.dart' as impl;

/// 打开本平台适用的 QueryExecutor（供 AppDatabase 构造函数使用）。
QueryExecutor openDbConnection() => impl.create();