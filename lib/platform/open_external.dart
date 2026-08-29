/// 外部链接打开门面：Web 用 window.open(_blank)；原生为空实现。
library;

export 'open_external_io.dart' if (dart.library.js_interop) 'open_external_web.dart';