import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// SharedPreferences 注入点：main() 中初始化后 override
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('必须在 main 中 override sharedPreferencesProvider');
});

const String _kThemeStorageKey = 'app.theme.key';

/// 全局主题状态：riverpod + SharedPreferences 持久化，即时切换
class ThemeNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_kThemeStorageKey);
    return ThemeKeys.all.contains(saved) ? saved! : ThemeKeys.green;
  }

  /// 切换主题并落盘（非法 key 直接忽略）
  Future<void> setTheme(String key) async {
    if (!ThemeKeys.all.contains(key) || key == state) return;
    state = key;
    await ref.read(sharedPreferencesProvider).setString(_kThemeStorageKey, key);
  }
}

/// 全局主题 Provider（state = ThemeKeys 之一）
final themeProvider =
    NotifierProvider<ThemeNotifier, String>(ThemeNotifier.new);
