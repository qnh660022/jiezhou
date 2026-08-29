/// 文件分享工具。
library;
import "dart:io";
import "dart:typed_data";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

Future<void> shareFile(Uint8List bytes, String filename, String mime,
    {String? text}) async {
  final dir = await getTemporaryDirectory();
  final file = File("${dir.path}/$filename");
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path, mimeType: mime)],
      subject: filename, text: text);
}

/// 把图片字节保存到设备（原生写入 Documents；Web 端触发浏览器下载）。
/// 返回给用户看的提示文案。
Future<String> saveImageBytes(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return '已保存到 ${file.path}';
}
