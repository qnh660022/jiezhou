/// 浏览器右键菜单门面：Web 端屏蔽原生右键菜单（本应用提供自定义右键菜单）。
library;

export 'context_menu_guard_io.dart'
    if (dart.library.js_interop) 'context_menu_guard_web.dart';