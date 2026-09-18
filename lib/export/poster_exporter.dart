/// 海报渲染基建（V2.7.1 S5 抽取）。
///
/// 原链路散落在 `trip_share_screen.dart`（RepaintBoundary → toImage → share_plus）；
/// 现抽为共用工具，行程海报与**结算分享卡**共同调用（禁止复制两份）。
///
/// 渲染口径：`pixelRatio = 3.0`（三倍图，保证文字锐利，与既有行程海报一致）。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'share_helper.dart';

/// 把 [key] 对应的 RepaintBoundary 渲染为 PNG 字节；失败返回 null。
Future<Uint8List?> captureBoundaryPng(
  GlobalKey key, {
  double pixelRatio = 3.0,
}) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

/// 保存到相册/下载目录；返回人类可读结果文案。
Future<String> savePosterPng(GlobalKey key, String fileName,
    {double pixelRatio = 3.0}) async {
  final bytes = await captureBoundaryPng(key, pixelRatio: pixelRatio);
  if (bytes == null) return '截图失败';
  return saveImageBytes(bytes, fileName);
}

/// 调用系统分享；返回是否成功（失败时调用方可提示用户重试）。
Future<bool> sharePosterPng(
  GlobalKey key,
  String fileName, {
  String? text,
  double pixelRatio = 3.0,
}) async {
  final bytes = await captureBoundaryPng(key, pixelRatio: pixelRatio);
  if (bytes == null) return false;
  await shareFile(bytes, fileName, 'image/png', text: text);
  return true;
}
