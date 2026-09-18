/// 启动锁持久化后端（Web 实现）。
///
/// 与 io 端的唯一实质差异在「数据存活边界」，故只把这一点做成平台分支：
/// Web 端 PIN 落在 `localStorage`（SharedPreferences 的 Web 后端），
/// **清除浏览器站点数据即失效**——设置页必须把这一点讲清楚，
/// 否则用户会以为锁能挡住「清一下浏览器数据」的人。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 用户可见的数据存活说明（设置页直接展示）。
const String kAppLockPlatformNote =
    'PIN 只存在本机浏览器；清除站点数据或换浏览器后锁会失效，需要重新设置。';

/// Web 端清站点数据即失效。
const bool kAppLockVolatileWithSiteData = true;

Future<SharedPreferences> appLockPrefs() => SharedPreferences.getInstance();
