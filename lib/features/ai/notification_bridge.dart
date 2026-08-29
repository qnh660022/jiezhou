/// 本地系统通知门面。
///
/// 原生端走 flutter_local_notifications 发预算预警系统通知；
/// Web 端浏览器不提供该插件能力，使用空实现（预警看板本身与状态仍照常工作）。
library;

export 'notification_bridge_io.dart'
    if (dart.library.js_interop) 'notification_bridge_web.dart';