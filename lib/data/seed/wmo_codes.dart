// 数据来源: D:\AI\money\utils\weather.js · 条数(代码) 28 · 条数(分组) 11
// 由 travel-assistant-v2/integrator 从旧版小程序数据层迁移生成；纯常量，无任何第三方/flutter 依赖。
// WMO weather_code -> 天气图标与文案。源 CODE_MAP 为 11 个连续段分组，全量搬运；
// 另派生按单个代码查询的映射表（28 个代码，满足 >=12 组粒度要求）。

/// 一段连续的 WMO 天气代码分组。
class WmoGroup {
  /// 该组覆盖的 weather_code 列表
  final List<int> codes;

  /// 图标（emoji）
  final String icon;

  /// 文案
  final String text;

  const WmoGroup(this.codes, this.icon, this.text);
}

/// 单个天气代码对应的展示信息。
class WmoWeather {
  /// 图标（emoji）
  final String icon;

  /// 文案
  final String text;

  const WmoWeather(this.icon, this.text);
}

/// WMO 代码分组全集（与旧版 utils/weather.js 的 CODE_MAP 一一对应）。
const List<WmoGroup> kWmoCodeGroups = [
  WmoGroup([0], '☀️', '晴'),
  WmoGroup([1], '🌤️', '晴间多云'),
  WmoGroup([2], '⛅', '多云'),
  WmoGroup([3], '☁️', '阴'),
  WmoGroup([45, 48], '🌫️', '雾'),
  WmoGroup([51, 53, 55, 56, 57], '🌦️', '毛毛雨'),
  WmoGroup([61, 63, 65, 66, 67], '🌧️', '雨'),
  WmoGroup([71, 73, 75, 77], '🌨️', '雪'),
  WmoGroup([80, 81, 82], '🌦️', '阵雨'),
  WmoGroup([85, 86], '🌨️', '阵雪'),
  WmoGroup([95, 96, 99], '⛈️', '雷雨'),
];

/// 未知代码的兜底展示（对齐旧版 weatherInfo 默认值）。
const WmoWeather kWmoUnknown = WmoWeather('🌡️', '未知');

/// weather_code -> 展示信息映射（由分组展开派生）。
final Map<int, WmoWeather> kWmoWeatherByCode = {
  for (final group in kWmoCodeGroups)
    for (final code in group.codes) code: WmoWeather(group.icon, group.text),
};

/// 查询 WMO 天气代码的图标与文案；未知代码返回 🌡️/未知。
WmoWeather wmoWeatherInfo(int code) => kWmoWeatherByCode[code] ?? kWmoUnknown;
