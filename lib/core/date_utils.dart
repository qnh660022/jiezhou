/// 日期核心工具：工程内部日期一律用 epochDay(int) 存储——
/// 即「本地日期」距 1970-01-01 的天数。无时区歧义、可比较可运算，
/// 展示层再用本文件函数转中文文案或 ISO 字符串。
library;

const List<String> _weekdayText = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 本地 DateTime -> epochDay（丢弃时分秒）
int dateToEpochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// epochDay -> 本地零点 DateTime
DateTime epochDayToDate(int epochDay) {
  final u = DateTime.utc(1970, 1, 1).add(Duration(days: epochDay));
  return DateTime(u.year, u.month, u.day);
}

/// 今天（本地时区）的 epochDay
int todayEpochDay() => dateToEpochDay(DateTime.now());

/// 「X月X日」：8月25日
String fmtMonthDay(DateTime d) => '${d.month}月${d.day}日';

/// 「周X」：周一…周日
String fmtWeekday(DateTime d) => _weekdayText[d.weekday - 1];

/// 「X月X日 周X」：8月25日 周一
String fmtFullDate(DateTime d) => '${fmtMonthDay(d)} ${fmtWeekday(d)}';

/// ISO 短格式 yyyy-MM-dd（CSV/排序友好）
String fmtIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// epochDay 版便捷包装
String fmtMonthDayOfEpoch(int epochDay) => fmtMonthDay(epochDayToDate(epochDay));

/// epochDay 版完整中文文案
String fmtFullDateOfEpoch(int epochDay) => fmtFullDate(epochDayToDate(epochDay));

/// 行程天数：起止闭区间天数，起晚于止返回 0
int tripDays(int startEpochDay, int endEpochDay) {
  if (endEpochDay < startEpochDay) return 0;
  return endEpochDay - startEpochDay + 1;
}

/// 行程内第几天（1 起）；越界夹到 [1, 天数]
int dayIndexOf(int startEpochDay, int endEpochDay, int targetEpochDay) {
  final days = tripDays(startEpochDay, endEpochDay);
  if (days == 0) return 0;
  final idx = targetEpochDay - startEpochDay + 1;
  if (idx < 1) return 1;
  if (idx > days) return days;
  return idx;
}

/// 把任意 epochDay 夹紧进 [start, end] 区间（行程缩区间时保数据用）
int clampEpochDay(int day, int startEpochDay, int endEpochDay) {
  if (day < startEpochDay) return startEpochDay;
  if (day > endEpochDay) return endEpochDay;
  return day;
}

/// 是否同一天（本地时区比较）
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
