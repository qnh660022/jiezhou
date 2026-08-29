/// 原生 / 桌面：按文件路径读取图片。
library;
import 'dart:io';
import 'package:flutter/widgets.dart';

Widget fileImage(String uri, {BoxFit? fit}) =>
    Image.file(File(uri), fit: fit, errorBuilder: (_, __, ___) => const SizedBox());