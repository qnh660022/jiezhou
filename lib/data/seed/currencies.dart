// 数据来源: D:\AI\money\utils\currencies.js · 条数 13
// 由 travel-assistant-v2/integrator 从旧版小程序数据层迁移生成；纯常量，无任何第三方/flutter 依赖。
// 币种与默认汇率（手动汇率口径：1 单位外币 = rate 元人民币）。

/// 币种信息。
class CurrencyInfo {
  /// ISO 4217 货币代码
  final String code;

  /// 货币符号
  final String symbol;

  /// 中文名称
  final String name;

  /// 默认汇率：1 外币 = rate 元
  final double rate;

  const CurrencyInfo(this.code, this.symbol, this.name, this.rate);
}

/// 内置币种全集（首项为基准币种人民币）。
const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo('CNY', '¥', '人民币', 1),
  CurrencyInfo('USD', '\$', '美元', 7.2),
  CurrencyInfo('EUR', '€', '欧元', 7.8),
  CurrencyInfo('JPY', '¥', '日元', 0.05),
  CurrencyInfo('GBP', '£', '英镑', 9.1),
  CurrencyInfo('HKD', 'HK\$', '港币', 0.92),
  CurrencyInfo('KRW', '₩', '韩元', 0.0053),
  CurrencyInfo('THB', '฿', '泰铢', 0.2),
  CurrencyInfo('SGD', 'S\$', '新加坡元', 5.4),
  CurrencyInfo('AUD', 'A\$', '澳元', 4.7),
  CurrencyInfo('CAD', 'C\$', '加元', 5.3),
  CurrencyInfo('MYR', 'RM', '马来西亚林吉特', 1.6),
  CurrencyInfo('VND', '₫', '越南盾', 0.0003),
];

/// 按货币代码查找币种（忽略大小写）；未命中返回 null。
CurrencyInfo? findCurrency(String code) {
  final upper = code.trim().toUpperCase();
  for (final c in kCurrencies) {
    if (c.code == upper) return c;
  }
  return null;
}
