/// 文件分享工具。
library;
import "dart:io";
import "dart:typed_data";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

Future<void> shareFile(Uint8List bytes, String filename, String mime) async {
  final dir = await getTemporaryDirectory();
  final file = File("${dir.path}/$filename");
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path, mimeType: mime)], subject: filename);
}
