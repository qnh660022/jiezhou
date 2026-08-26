/// 海报生成：1080x1920 Canvas 渐变封面+行程摘要→PNG。
library;
import "dart:typed_data";
import "dart:ui" as ui;
import "package:flutter/painting.dart" show TextSpan, TextPainter, TextStyle, TextDirection;

Future<Uint8List> renderPoster({required String name, required String emoji, required String dateRange, required int days, int totalCents = 0}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0,0,1080,1920));
  // 渐变背景
  final paint = ui.Paint()..shader = ui.Gradient.linear(ui.Offset(0,0), ui.Offset(0,1920), [ui.Color(0xFF4F8FF7), ui.Color(0xFF8B5CF6)]);
  canvas.drawRect(ui.Rect.fromLTWH(0,0,1080,1920), paint);
  // emoji
  final emojiPainter = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: 120)), textDirection: TextDirection.ltr)..layout();
  emojiPainter.paint(canvas, ui.Offset((1080-emojiPainter.width)/2, 400));
  // 名称
  final namePainter = TextPainter(text: TextSpan(text: name, style: TextStyle(color: ui.Color(0xFFFFFFFF), fontSize: 60, fontWeight: ui.FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
  namePainter.paint(canvas, ui.Offset((1080-namePainter.width)/2, 600));
  // 日期
  final datePainter = TextPainter(text: TextSpan(text: dateRange, style: TextStyle(color: ui.Color(0xB3FFFFFF), fontSize: 32)), textDirection: TextDirection.ltr)..layout();
  datePainter.paint(canvas, ui.Offset((1080-datePainter.width)/2, 720));
  // 天数
  final dayPainter = TextPainter(text: TextSpan(text: "$days 天", style: TextStyle(color: ui.Color(0xFFFFFFFF), fontSize: 48, fontWeight: ui.FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
  dayPainter.paint(canvas, ui.Offset((1080-dayPainter.width)/2, 820));
  final img = await recorder.endRecording().toImage(1080, 1920);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
