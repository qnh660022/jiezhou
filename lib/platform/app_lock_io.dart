/// 启动锁持久化后端（io 实现：Android / iOS / 桌面）。
///
/// 与 Web 端的唯一实质差异在「数据存活边界」，故只把这一点做成平台分支：
/// io 端 PIN 落在应用私有存储（SharedPreferences），清缓存不丢，
/// 只有卸载 / 清除应用数据才丢——这是规格 §S7.2「仅存本地」的自然结果。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 用户可见的数据存活说明（设置页直接展示）。
const String kAppLockPlatformNote = 'PIN 只存在本机；卸载 App 或清除应用数据后锁会失效，需要重新设置。';

/// Web 端清站点数据即失效；io 端不适用。
const bool kAppLockVolatileWithSiteData = false;

Future<SharedPreferences> appLockPrefs() => SharedPreferences.getInstance();
