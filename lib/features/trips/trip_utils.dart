// 行程线特性内工具函数：日期/金额/状态机/类型元信息。
import 'package:flutter/material.dart';
import 'package:travel_assistant/data/seed/item_types.dart';
import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../data/seed/currencies.dart';
import '../../theme/tokens.dart';

/// 五类安排的可视化元信息
class TripTypeVisual {
  const TripTypeVisual(this.key, this.name, this.icon, this.color);
  final String key;
  final String name;
  final String icon;
  final Color color;
}

const List<String> kTripTypeKeys = ['attraction','food','transport','stay','note'];

final Map<String, TripTypeVisual> _fallbackTypes = {
  'attraction': TripTypeVisual('attraction', '景点', '🏛️', AvatarPalette.colors[0]),
  'food': TripTypeVisual('food', '餐饮', '🍜', AvatarPalette.colors[2]),
  'transport': TripTypeVisual('transport', '交通', '🚗', AvatarPalette.colors[1]),
  'stay': TripTypeVisual('stay', '住宿', '🏨', AvatarPalette.colors[4]),
  'note': TripTypeVisual('note', '备注', '📝', AvatarPalette.colors[7]),
};

TripTypeVisual tripTypeVisual(String key) {
  for (final t in kItemTypes) {
    if (t.key == key) return TripTypeVisual(t.key, t.name, t.icon, AvatarPalette.colors[t.colorIndex % AvatarPalette.colors.length]);
  }
  return _fallbackTypes[key] ?? _fallbackTypes['note']!;
}

List<TripTypeVisual> allTripTypes() => kTripTypeKeys.map(tripTypeVisual).toList();

// ============================ 币种 ============================
class CurrencyOption {
  const CurrencyOption(this.code, this.symbol, this.name, this.defaultRate);
  final String code;
  final String symbol;
  final String name;
  final double defaultRate;
}

const List<CurrencyOption> kCurrencyOptions = [
  CurrencyOption('CNY', '¥', '人民币', 1),
  CurrencyOption('USD', r'$', '美元', 7.20),
  CurrencyOption('EUR', '€', '欧元', 7.80),
  CurrencyOption('JPY', 'JP¥', '日元', 0.048),
  CurrencyOption('GBP', '£', '英镑', 8.90),
  CurrencyOption('HKD', r'HK$', '港币', 0.92),
  CurrencyOption('KRW', '₩', '韩元', 0.0053),
  CurrencyOption('THB', '฿', '泰铢', 0.21),
  CurrencyOption('SGD', r'S$', '新加坡元', 5.40),
  CurrencyOption('AUD', r'A$', '澳元', 4.70),
  CurrencyOption('CAD', r'C$', '加元', 5.20),
  CurrencyOption('MYR', 'RM', '林吉特', 1.55),
  CurrencyOption('VND', '₫', '越南盾', 0.00028),
];

CurrencyOption? findCurrencyOption(String code) {
  for (final c in kCurrencyOptions) { if (c.code == code) return c; }
  return null;
}

CurrencyOption? currencyByCode(String code) => findCurrencyOption(code);

// ============================ 日期格式化 ============================

/// epochDay -> 「X月X日 周X」
String cnFullDate(int epochDay) => fmtFullDateOfEpoch(epochDay);

/// epochDay -> 「X月X日」
String cnMonthDay(int epochDay) => fmtMonthDayOfEpoch(epochDay);

/// 起止 epochDay -> 「8月25日-8月30日」
String cnDateRange(int start, int end) {
  final s = epochDayToDate(start);
  final e = epochDayToDate(end);
  if (s.year == e.year && s.month == e.month) {
    return '${s.month}月${s.day}日-${e.day}日';
  }
  return '${s.month}月${s.day}日-${e.month}月${e.day}日';
}

/// 行程总天数
int tripTotalDays(int startEpochDay, int endEpochDay) => tripDays(startEpochDay, endEpochDay);

/// epochDay -> DateTime
DateTime dateTimeFromEpochDay(int epochDay) => epochDayToDate(epochDay);

/// DateTime -> epochDay
int epochDayOf(DateTime dt) => dateToEpochDay(dt);

/// 分钟数 -> 「8h 30m」或「30分钟」
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes分钟';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}小时' : '${h}h ${m}m';
}

/// 分钟数 -> 「08:30」
String hhmm(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

// ============================ 行程状态机 ============================

enum TripLifeStatus { ongoing, upcoming, planning, ended, archived }

TripLifeStatus classifyTrip({
  required int startEpochDay,
  required int endEpochDay,
  required bool archived,
  required int today,
}) {
  if (archived) return TripLifeStatus.archived;
  if (today >= startEpochDay && today <= endEpochDay) return TripLifeStatus.ongoing;
  if (today < startEpochDay) return TripLifeStatus.upcoming;
  if (startEpochDay == 0 && endEpochDay == 0) return TripLifeStatus.planning;
  return TripLifeStatus.ended;
}

/// 行程进度 0.0~1.0；规划中/已归档返回 null
double? tripProgress(TripLifeStatus status, int start, int end, int today) {
  if (status == TripLifeStatus.planning || status == TripLifeStatus.archived) return null;
  if (today < start) return 0.0;
  if (today > end) return 1.0;
  final total = end - start;
  if (total <= 0) return 1.0;
  return (today - start) / total;
}

/// 状态徽章文案
String statusBadgeText(TripLifeStatus status, int startEpochDay, int today) {
  switch (status) {
    case TripLifeStatus.ongoing:
      final dayIdx = today - startEpochDay + 1;
      return '进行中 · Day $dayIdx';
    case TripLifeStatus.upcoming:
      final diff = startEpochDay - today;
      if (diff == 1) return '明天出发';
      return '${diff}天后出发';
    case TripLifeStatus.planning:
      return '规划中';
    case TripLifeStatus.ended:
      return '已结束';
    case TripLifeStatus.archived:
      return '已归档';
  }
}