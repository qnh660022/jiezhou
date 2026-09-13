/// 今日驾驶舱的本地状态存储（§8.3）。
///
/// 两类刻意**只存本地、不上云**的个人素材：
/// * 行程项完成勾选：按 `tripId + 当地日期 + itemId` 记忆——不写 trip_items、
///   不上云（本期取舍，规格固定）。别人看不到"我今天打卡了清水寺"。
/// * 今日备注便签：按 `tripId + 当地日期` 存一段多行文本。
///
/// 用 SharedPreferences（跨设备不同步、卸载即失），所以这里没有同步语义。
library;
import 'package:shared_preferences/shared_preferences.dart';

class TodayLocalStore {
  TodayLocalStore(this.prefs);

  final SharedPreferences prefs;

  static const String _kDone = 'today.done.';
  static const String _kNote = 'today.note.';

  String _doneKey(String tripId, int day) => '$_kDone$tripId.$day';
  String _noteKey(String tripId, int day) => '$_kNote$tripId.$day';

  /// 当天已勾选的行程项 id 集合（不存在返回空集）。
  Set<String> doneIds(String tripId, int day) =>
      (prefs.getStringList(_doneKey(tripId, day)) ?? const <String>[]).toSet();

  bool isDone(String tripId, int day, String itemId) =>
      doneIds(tripId, day).contains(itemId);

  /// 写入勾选态；返回写入后的集合（UI 直接 setState 用，避免再读一次盘）。
  Future<Set<String>> setDone(
      String tripId, int day, String itemId, bool done) async {
    final ids = doneIds(tripId, day);
    if (done) {
      ids.add(itemId);
    } else {
      ids.remove(itemId);
    }
    final list = ids.toList()..sort();
    final key = _doneKey(tripId, day);
    if (list.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setStringList(key, list);
    }
    return ids;
  }

  /// 清空某天全部勾选（"重置今日打卡"）。
  Future<void> clearDone(String tripId, int day) =>
      prefs.remove(_doneKey(tripId, day));

  /// 今日备注（多行文本）。
  String note(String tripId, int day) => prefs.getString(_noteKey(tripId, day)) ?? '';

  Future<void> setNote(String tripId, int day, String text) async {
    final key = _noteKey(tripId, day);
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, trimmed);
    }
  }

  // ===== 旅伴空间动态未读游标（§6 动态角标） =====

  static const String _kSpaceSeen = 'space.events.seen.';

  /// 某空间动态流上次已读时刻（毫秒）；从未打开返回 0。
  int spaceEventsSeenMs(String spaceId) =>
      prefs.getInt('$_kSpaceSeen$spaceId') ?? 0;

  Future<void> markSpaceEventsSeen(String spaceId, int ms) =>
      prefs.setInt('$_kSpaceSeen$spaceId', ms);

  // ===== 驾驶舱入场动效一次性标记（避免每次进页面都重放） =====

  static const String _kCockpitEntered = 'today.cockpit.entered.';

  bool cockpitEntered(String tripId) =>
      prefs.getBool('$_kCockpitEntered$tripId') ?? false;

  Future<void> markCockpitEntered(String tripId) =>
      prefs.setBool('$_kCockpitEntered$tripId', true);
}
