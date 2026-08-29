/// 平台探测门面：在不同运行环境解析为对应实现。
library;

import 'detect_env_io.dart' if (dart.library.js_interop) 'detect_env_web.dart'
    as impl;

/// 当前是否运行在 flutter test 环境（用于数据库等测试旁路）。
bool get isTestEnv => impl.isTestEnv;