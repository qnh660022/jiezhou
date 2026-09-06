/// 云后端基址注入。优先级：prefs(`supabase.url`/`supabase.anon_key`) > --dart-define > 空。
///
/// 契约（V2.6 §3.2.2）：
/// - 有效配置 = url 非空且以 https:// 开头、anonKey 非空；无效返回 null；
/// - [saveOverride]/[clearOverride] 供设置页写入（persist），写后需重置运行时实例
///   （`Supabase.initialize(reset:true, ...)`，旧会话被清、新会话空）。
library;
import 'package:shared_preferences/shared_preferences.dart';

abstract final class SupabaseCfg {
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String prefUrl = 'supabase.url';
  static const String prefAnonKey = 'supabase.anon_key';

  /// 返回有效配置；无效返回 null。
  static Future<({String url, String anonKey})?> resolve() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final url = sp.getString(prefUrl) ?? _envUrl;
      final anon = sp.getString(prefAnonKey) ?? _envAnon;
      return _validate(url, anon);
    } catch (_) {
      return _validate(_envUrl, _envAnon);
    }
  }

  /// 同步读取当前已注入内存的配置（main 初始化后使用；不走 prefs IO）。
  static ({String url, String anonKey})? resolveSync(SharedPreferences sp) =>
      _validate(sp.getString(prefUrl) ?? _envUrl, sp.getString(prefAnonKey) ?? _envAnon);

  static ({String url, String anonKey})? _validate(String? url, String? anon) {
    if (url == null || anon == null || url.isEmpty || anon.isEmpty) return null;
    if (!url.startsWith('https://')) return null;
    return (url: url, anonKey: anon);
  }

  /// 设置页写入（persist）；写后需重置运行时实例（§3.2.3）。
  static Future<void> saveOverride(String url, String anonKey) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(prefUrl, url.trim());
    await sp.setString(prefAnonKey, anonKey.trim());
  }

  static Future<void> clearOverride() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(prefUrl);
    await sp.remove(prefAnonKey);
  }
}
