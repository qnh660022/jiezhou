/// 云后端基址注入。密钥唯一来源：构建时 --dart-define（默认注入，§3.2.2）。
///
/// 契约（V2.6.1 起）：
/// - 不再支持端点手填（端点配置入口已移除）；prefs 中的历史残留键按需清理；
/// - 有效配置 = url 非空且以 https:// 开头、anonKey 非空；无效返回 null（云功能按未启用处理）。
library;
import 'package:shared_preferences/shared_preferences.dart';

abstract final class SupabaseCfg {
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// 历史版本（端点手填）遗留的 prefs 键，启动清理用。
  static const String legacyPrefUrl = 'supabase.url';
  static const String legacyPrefAnonKey = 'supabase.anon_key';

  /// 返回有效配置；无效返回 null。顺带清理旧版本端点手填残留。
  static Future<({String url, String anonKey})?> resolve() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.containsKey(legacyPrefUrl)) await sp.remove(legacyPrefUrl);
      if (sp.containsKey(legacyPrefAnonKey)) {
        await sp.remove(legacyPrefAnonKey);
      }
    } catch (_) {}
    return _validate(_envUrl, _envAnon);
  }

  /// 同步读取当前注入的配置（main 初始化后使用；不走 IO）。
  static ({String url, String anonKey})? resolveSync(SharedPreferences sp) =>
      _validate(_envUrl, _envAnon);

  static ({String url, String anonKey})? _validate(String? url, String? anon) {
    if (url == null || anon == null || url.isEmpty || anon.isEmpty) return null;
    if (!url.startsWith('https://')) return null;
    return (url: url, anonKey: anon);
  }
}
