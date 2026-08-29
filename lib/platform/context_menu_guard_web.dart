/// Web：屏蔽浏览器原生右键菜单，避免与自定义桌面右键菜单叠加弹出。
library;
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void disableBrowserContextMenu() {
  web.window.addEventListener('contextmenu', (web.Event e) {
    e.preventDefault();
  }.toJS);
}