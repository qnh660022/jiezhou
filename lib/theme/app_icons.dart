import 'package:flutter/material.dart';

/// V2.8.1 S4：芥舟图标体系唯一常量表（JieZhouIcons 字体）。
///
/// 码点表与 `design/icons/codepoints.json` 一一对应，提交后冻结防漂移；
/// 字体资产 `assets/fonts/JieZhouIcons.ttf` 由 `design/icons/build_font.py`
/// 构建期工具产出（工具链不入 pubspec 依赖树）。
///
/// 岗位规则（概念收口 §1.3-3）：功能图标岗位只允许 `AppIcons.*` 或
/// `Icons.*_rounded` 两族；emoji 仅允许内容岗位。
abstract final class AppIcons {
  static const String fontFamily = 'JieZhouIcons';

  /// 品牌舟形：帆两片 + 梯形船体 + 双波纹底。
  static const IconData boat = IconData(0xe900, fontFamily: fontFamily);

  // ---- 底栏 5 ----
  static const IconData spark = IconData(0xe901, fontFamily: fontFamily);
  static const IconData clip = IconData(0xe902, fontFamily: fontFamily);
  static const IconData compass = IconData(0xe903, fontFamily: fontFamily);
  static const IconData wallet = IconData(0xe904, fontFamily: fontFamily);
  static const IconData user = IconData(0xe905, fontFamily: fontFamily);

  // ---- 内置分类 8 ----
  // 实际内置 7 分类 key：food/transport/stay/ticket/shopping/fun/other
  //（偏差登记：规格书示例的 饮品 cup / 医疗 med 分类在现库不存在，med 作备用位保留）
  static const IconData food = IconData(0xe906, fontFamily: fontFamily);
  static const IconData car = IconData(0xe907, fontFamily: fontFamily);
  static const IconData bed = IconData(0xe908, fontFamily: fontFamily);
  static const IconData ticket = IconData(0xe909, fontFamily: fontFamily);
  static const IconData bag = IconData(0xe90a, fontFamily: fontFamily);
  static const IconData fun = IconData(0xe90b, fontFamily: fontFamily);
  static const IconData med = IconData(0xe90c, fontFamily: fontFamily);
  static const IconData tag = IconData(0xe90d, fontFamily: fontFamily);

  // ---- 功能 15 ----
  static const IconData trash = IconData(0xe90e, fontFamily: fontFamily);
  static const IconData check = IconData(0xe90f, fontFamily: fontFamily);
  static const IconData calendar = IconData(0xe910, fontFamily: fontFamily);
  static const IconData bookmark = IconData(0xe911, fontFamily: fontFamily);
  static const IconData clock = IconData(0xe912, fontFamily: fontFamily);
  static const IconData bolt = IconData(0xe913, fontFamily: fontFamily);
  static const IconData sun = IconData(0xe914, fontFamily: fontFamily);
  static const IconData chart = IconData(0xe915, fontFamily: fontFamily);
  static const IconData coins = IconData(0xe916, fontFamily: fontFamily);
  static const IconData members = IconData(0xe917, fontFamily: fontFamily);
  static const IconData toolbox = IconData(0xe918, fontFamily: fontFamily);
  static const IconData qr = IconData(0xe919, fontFamily: fontFamily);
  static const IconData search = IconData(0xe91a, fontFamily: fontFamily);
  static const IconData tune = IconData(0xe91b, fontFamily: fontFamily);
  static const IconData camera = IconData(0xe91c, fontFamily: fontFamily);

  // ---- 预留 7 ----
  static const IconData reserve1 = IconData(0xe91d, fontFamily: fontFamily);
  static const IconData reserve2 = IconData(0xe91e, fontFamily: fontFamily);
  static const IconData reserve3 = IconData(0xe91f, fontFamily: fontFamily);
  static const IconData reserve4 = IconData(0xe920, fontFamily: fontFamily);
  static const IconData reserve5 = IconData(0xe921, fontFamily: fontFamily);
  static const IconData reserve6 = IconData(0xe922, fontFamily: fontFamily);
  static const IconData reserve7 = IconData(0xe923, fontFamily: fontFamily);

  /// 内置分类 key → 图标映射（必须覆盖全部 7 内置分类 + 自定义兜底）。
  static const Map<String, IconData> categoryIcons = {
    'food': food,
    'transport': car,
    'stay': bed,
    'ticket': ticket,
    'shopping': bag,
    'fun': fun,
    'other': tag,
  };

  /// 分类图标取值：内置 key 查表，自定义分类统一 tag。
  static IconData forCategory(String key) => categoryIcons[key] ?? tag;
}
