/// Web：用 window.open 在新标签页打开外部链接。
library;
import 'package:web/web.dart' as web;

void openExternal(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}