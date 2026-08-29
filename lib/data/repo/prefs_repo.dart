/// 偏好仓储：themeKey/activeGroupId/currencyRates/mapConfig 读写。
library;
import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

import "../../platform/fs.dart" show clearTempDir;

class PrefsRepository {
  Future<SharedPreferences> get _sp async => SharedPreferences.getInstance();

  Future<String> getThemeKey() async => (await _sp).getString("theme_key") ?? "green";
  Future<void> setThemeKey(String k) async => (await _sp).setString("theme_key", k);

  Future<String?> getActiveGroupId() async => (await _sp).getString("active_group_id");
  Future<void> setActiveGroupId(String? id) async { if (id==null) await (await _sp).remove("active_group_id"); else await (await _sp).setString("active_group_id", id); }

  Future<String?> getLastChecklistTripId() async => (await _sp).getString("last_checklist_trip");
  Future<void> setLastChecklistTripId(String? id) async { if (id==null) await (await _sp).remove("last_checklist_trip"); else await (await _sp).setString("last_checklist_trip", id); }

  Future<Map<String,double>> getCurrencyRates() async { final s=(await _sp).getString("currency_rates"); if (s==null) return {}; final m=jsonDecode(s) as Map; return m.map((k,v)=>MapEntry(k as String,(v as num).toDouble())); }
  Future<void> setCurrencyRates(Map<String,double> r) async => (await _sp).setString("currency_rates", jsonEncode(r));

  /// AI 助手配置（OpenAI 兼容接口）：{baseUrl, apiKey, model}，未配置时 baseUrl 为空串。
  Future<Map<String,dynamic>> getAiConfig() async { final s=(await _sp).getString("ai_config"); if (s==null) return {"baseUrl":"","apiKey":"","model":""}; return jsonDecode(s) as Map<String,dynamic>; }
  Future<void> setAiConfig(Map<String,dynamic> c) async => (await _sp).setString("ai_config", jsonEncode(c));

  Future<Map<String,dynamic>> getMapConfig() async { final s=(await _sp).getString("map_config"); if (s==null) return {"provider":"none","key":""}; return jsonDecode(s) as Map<String,dynamic>; }

  /// 预算预警总开关：关闭后红点与预警中心都不再提示（默认开启）。
  Future<bool> getBudgetAlertsEnabled() async => (await _sp).getBool("budget_alerts_enabled") ?? true;
  Future<void> setBudgetAlertsEnabled(bool enabled) async => (await _sp).setBool("budget_alerts_enabled", enabled);

  /// 清除可重建的本地缓存（航班缓存 + 临时目录文件）；不影响任何用户数据。
  Future<void> clearTemporaryCache() async {
    await clearFlightCache();
    await clearTempDir();
  }

  /// 预算预警已读级别集合（0=info 1=warning 2=danger），按团隔离。
  Future<Set<int>> getBudgetAlertSeenLevels(String gid) async {
    final s = (await _sp).getString("budget_alert_seen_$gid");
    if (s == null) return const {};
    try { final list = jsonDecode(s) as List; return {for (final e in list) e as int}; } catch (_) { return const {}; }
  }
  Future<void> setBudgetAlertSeenLevels(String gid, Set<int> levels) async => (await _sp).setString("budget_alert_seen_$gid", jsonEncode(levels.toList()));

  /// 清单模板收藏（场景 key 列表，置顶展示）
  Future<Set<String>> getChecklistTplFavs() async {
    final s = (await _sp).getString("checklist_tpl_favs");
    if (s == null) return const {};
    try { final list = jsonDecode(s) as List; return {for (final e in list) e as String}; } catch (_) { return const {}; }
  }
  Future<void> setChecklistTplFavs(Set<String> keys) async => (await _sp).setString("checklist_tpl_favs", jsonEncode(keys.toList()));
  Future<void> setMapConfig(Map<String,dynamic> c) async => (await _sp).setString("map_config", jsonEncode(c));

  Future<Map<String,dynamic>> getFlightCache() async { final s=(await _sp).getString("flight_cache"); if (s==null) return {}; return jsonDecode(s) as Map<String,dynamic>; }
  Future<void> setFlightCache(Map<String,dynamic> c) async => (await _sp).setString("flight_cache", jsonEncode(c));
  Future<void> clearFlightCache() async => (await _sp).remove("flight_cache");
  Future<void> setCurrencyRate(String code, double rate) async { final rates=await getCurrencyRates(); rates[code]=rate; await setCurrencyRates(rates); }
}
