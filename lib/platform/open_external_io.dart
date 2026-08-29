/// Android / 桌面：通过主 Activity 的 URL 打开通道（Intent.ACTION_VIEW）调起系统浏览器。
/// Web 端在 open_external_web.dart 用 window.open 实现。
library;
import 'package:flutter/services.dart';

void openExternal(String url) async {
  try {
    await const MethodChannel('app/open_external').invokeMethod('open', url);
  } catch (_) {
    // 无浏览器 / 通道失败时静默降级（官网跳转失败不影响主流程）。
  }
}