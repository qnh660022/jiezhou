/// 文件分享工具（Web）：直接以字节分享 / 触发浏览器下载。
library;
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

Future<void> shareFile(Uint8List bytes, String filename, String mime,
    {String? text}) async {
  await Share.shareXFiles([
    XFile.fromData(bytes, mimeType: mime, name: filename),
  ], subject: filename, text: text);
}

/// 把图片字节保存：Web 端无相册写入权限，改为触发浏览器下载。
Future<String> saveImageBytes(Uint8List bytes, String filename) async {
  _downloadBlob(bytes, filename, 'image/png');
  return '已开始下载 $filename';
}

/// 通过 Blob + 临时 <a download> 触发浏览器下载。
void _downloadBlob(Uint8List bytes, String filename, String mime) {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}