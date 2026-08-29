/// 图片渲染门面：原生用 Image.file 读文件路径；Web 用 Image.network 渲染
/// image_picker 返回的 blob URL（会话内有效，跨刷新不持久——Web 端已知限制）。
library;
import 'package:flutter/widgets.dart';

import 'file_image_io.dart'
    if (dart.library.js_interop) 'file_image_web.dart' as impl;

Widget fileImage(String uri, {BoxFit? fit}) => impl.fileImage(uri, fit: fit);