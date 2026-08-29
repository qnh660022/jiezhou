/// 局域网离线协作记账门面。
///
/// 原生端提供完整的 UDP/TCP 局域网同步；Web 端因浏览器无法监听 UDP 广播
/// 或绑定端口，故提供「网页版不支持」的占位实现（入口界面会提示退回备份同步）。
library;

export 'lan_sync_service_io.dart'
    if (dart.library.js_interop) 'lan_sync_service_web.dart';