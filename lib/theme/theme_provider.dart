import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// SharedPreferences 注入点：main() 中初始化后 override
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('必须在 main 中 override sharedPreferencesProvider');
});

const String _kFamilyKey = 'app.theme.family';
const String _kBrightnessKey = 'app.theme.brightness';
const String kThemeStorageKey = 'app.theme.key'; // 旧键：迁移后删除

ThemeFamily? _familyFromLegacy(String? legacy) => switch (legacy) {
      'green' || 'mint' || 'system' => ThemeFamily.mint,
      'blue' || 'sky' => ThemeFamily.sky,
      'orange' || 'sun' => ThemeFamily.sun,
      'pink' || 'bloom' => ThemeFamily.bloom,
      'purple' || 'nebula' => ThemeFamily.nebula,
      'dark' || 'night' => ThemeFamily.night,
      _ => null,
    };

/// 主题族状态（持久化 app.theme.family；首次读入时从旧 app.theme.key 迁移，§5.2）。
class ThemeFamilyNotifier extends Notifier<ThemeFamily> {
  @override
  ThemeFamily build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_kFamilyKey);
    final f = saved == null ? null : _familyFromLegacy(saved);
    if (f != null) return f;
    // 兼容迁移：旧单键 → 新二元组，写新键删旧键
    final legacy = prefs.getString(kThemeStorageKey);
    if (legacy != null) {
      final mapped = _familyFromLegacy(legacy);
      if (mapped != null) {
        final b = legacy == 'dark'
            ? ThemeBrightnessMode.dark
            : (legacy == 'system'
                ? ThemeBrightnessMode.system
                : ThemeBrightnessMode.light);
        prefs.setString(_kFamilyKey, mapped.name);
        prefs.setString(_kBrightnessKey, b.name);
        prefs.remove(kThemeStorageKey);
        return mapped;
      }
    }
    return ThemeFamily.mint;
  }

  Future<void> set(ThemeFamily f) async {
    state = f;
    await ref.read(sharedPreferencesProvider).setString(_kFamilyKey, f.name);
  }
}

/// 亮暗三态状态（持久化 app.theme.brightness）。
class ThemeBrightnessNotifier extends Notifier<ThemeBrightnessMode> {
  @override
  ThemeBrightnessMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_kBrightnessKey);
    final f = switch (saved) {
      'light' => ThemeBrightnessMode.light,
      'dark' => ThemeBrightnessMode.dark,
      'system' => ThemeBrightnessMode.system,
      _ => null,
    };
    if (f != null) return f;
    final legacy = prefs.getString(kThemeStorageKey);
    if (legacy == 'dark') return ThemeBrightnessMode.dark;
    if (legacy == 'system') return ThemeBrightnessMode.system;
    return ThemeBrightnessMode.light;
  }

  Future<void> set(ThemeBrightnessMode b) async {
    state = b;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kBrightnessKey, b.name);
  }
}

final themeFamilyProvider =
    NotifierProvider<ThemeFamilyNotifier, ThemeFamily>(ThemeFamilyNotifier.new);
final themeBrightnessProvider =
    NotifierProvider<ThemeBrightnessNotifier, ThemeBrightnessMode>(
        ThemeBrightnessNotifier.new);

/// 旧主题单键外观（legacy facade）：desktop_shell 主题轮换 / AI 换肤工具沿用。
/// 读 = (family,brightness) 折算成旧 key；写 = 旧 key 映射回 (family,brightness)。
class ThemeLegacyNotifier extends Notifier<String> {
  @override
  String build() {
    final family = ref.watch(themeFamilyProvider);
    final brightness = ref.watch(themeBrightnessProvider);
    return _toLegacyKey(family, brightness);
  }

  static String _toLegacyKey(
      ThemeFamily family, ThemeBrightnessMode brightness) {
    if (brightness == ThemeBrightnessMode.system) return ThemeKeys.system;
    if (brightness == ThemeBrightnessMode.dark || family == ThemeFamily.night) {
      return ThemeKeys.dark;
    }
    return switch (family) {
      ThemeFamily.mint => ThemeKeys.green,
      ThemeFamily.sky => ThemeKeys.blue,
      ThemeFamily.sun => ThemeKeys.orange,
      ThemeFamily.bloom => ThemeKeys.pink,
      ThemeFamily.nebula => ThemeKeys.purple,
      ThemeFamily.night => ThemeKeys.dark,
    };
  }

  /// 切换主题（旧 key 入口，非法忽略）。
  Future<void> setTheme(String key) async {
    if (!ThemeKeys.all.contains(key) || key == state) return;
    final family = _familyFromLegacy(key);
    if (family == null) return;
    final brightness = switch (key) {
      ThemeKeys.dark => ThemeBrightnessMode.dark,
      ThemeKeys.system => ThemeBrightnessMode.system,
      _ => ThemeBrightnessMode.light,
    };
    await ref.read(themeFamilyProvider.notifier).set(family);
    await ref.read(themeBrightnessProvider.notifier).set(brightness);
  }
}

/// 全局主题 Provider（legacy：state = ThemeKeys 之一）
final themeProvider =
    NotifierProvider<ThemeLegacyNotifier, String>(ThemeLegacyNotifier.new);

/// 字体风格档（标题衬线开关；persist app.font.style）。
class FontModeNotifier extends Notifier<FontMode> {
  @override
  FontMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString('app.font.style');
    return saved == 'modern' ? FontMode.modern : FontMode.serif;
  }

  Future<void> set(FontMode m) async {
    state = m;
    await ref.read(sharedPreferencesProvider).setString('app.font.style', m.name);
  }
}

final fontStyleProvider =
    NotifierProvider<FontModeNotifier, FontMode>(FontModeNotifier.new);

/// 圆角密度档（persist app.radius.density；缺省 standard）。
class RadiusDensityNotifier extends Notifier<RadiusDensity> {
  @override
  RadiusDensity build() {
    final saved =
        ref.watch(sharedPreferencesProvider).getString('app.radius.density');
    return switch (saved) {
      'soft' => RadiusDensity.soft,
      'clean' => RadiusDensity.clean,
      _ => RadiusDensity.standard,
    };
  }

  Future<void> set(RadiusDensity d) async {
    state = d;
    await ref.read(sharedPreferencesProvider).setString('app.radius.density', d.name);
  }
}

final radiusDensityProvider =
    NotifierProvider<RadiusDensityNotifier, RadiusDensity>(RadiusDensityNotifier.new);
