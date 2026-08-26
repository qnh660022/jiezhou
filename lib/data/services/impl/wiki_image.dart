/// 维基百科配图获取：按词条标题拉取缩略图 URL。
///
/// 用于行程安排的 POI 选中后异步补图（photoUri）。
/// 失败返回空串，绝不抛异常。
library;
import "package:dio/dio.dart";

/// 通过中文维基百科词条标题获取缩略图 URL。
///
/// [title] 为维基百科页面标题（如 "浅草寺"）；
/// 返回 480px 宽缩略图的完整 URL；无词条或失败返回空串。
Future<String> fetchWikiImage(String title, {Dio? dio}) async {
  if (title.trim().isEmpty) return "";
  final client = dio ?? Dio();
  try {
    final r = await client.get(
      "https://zh.wikipedia.org/w/api.php",
      queryParameters: {
        "action": "query",
        "prop": "pageimages",
        "piprop": "thumbnail",
        "pithumbsize": "480",
        "format": "json",
        "redirects": "1",
        "titles": title,
      },
      options: Options(
        headers: {"User-Agent": "TravelAssistant2/2.0"},
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    final pages = (r.data["query"]?["pages"] as Map?) ?? {};
    if (pages.isEmpty) return "";
    // pages 以 pageid 为 key，取第一个
    final page = pages.values.firstOrNull;
    final thumbnail = page?["thumbnail"]?["source"];
    if (thumbnail is String && thumbnail.isNotEmpty) return thumbnail;
    return "";
  } catch (_) {
    return "";
  }
}
