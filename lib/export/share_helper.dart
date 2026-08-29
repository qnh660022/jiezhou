/// 文件分享门面：原生写临时文件后走系统分享；Web 走浏览器下载/分享。
library;

export 'share_helper_io.dart' if (dart.library.js_interop) 'share_helper_web.dart';