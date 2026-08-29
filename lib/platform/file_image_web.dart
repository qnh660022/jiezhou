/// Web：blob URL 用 Image.network 渲染。
library;
import 'package:flutter/widgets.dart';

Widget fileImage(String uri, {BoxFit? fit}) =>
    Image.network(uri, fit: fit, errorBuilder: (_, __, ___) => const SizedBox());