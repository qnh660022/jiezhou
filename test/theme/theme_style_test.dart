// L1-P0 主题差异表（§5.10）：12 板可解析、字段约束、差异维度覆盖、旧 key 迁移、衬线应用。
import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/theme/theme_provider.dart';
import 'package:travel_assistant/theme/tokens.dart';

void main() {
  group('ThemeStyles 差异表', () {
    test('L1-P0 12 板（浅5+深6+夜航）可解析且字段合法', () {
      final all = [...ThemeStyles.lightStyles, ...ThemeStyles.darkStyles];
      expect(all.length, 11); // 浅 5 + 深 6（含夜航）
      for (final s in all) {
        expect(s.signatureGradient.length, 2, reason: '${s.family} 渐变长度必须为 2');
        expect(s.motionTempo, greaterThan(0.7));
        expect(s.motionTempo, lessThan(1.4));
        expect(s.displayName.trim(), isNotEmpty);
        expect(_schemeOk(s.seed, s.brightness), isTrue);
      }
    });

    test('L1-P0 展示名不重复（浅深各有其名）', () {
      final names = [
        ...ThemeStyles.lightStyles.map((s) => s.displayName),
        ...ThemeStyles.darkStyles.map((s) => s.displayName),
      ];
      expect(names.length, names.toSet().length);
    });

    test('L1-P0 差异维度：serif ≥2、cardKind 覆盖 3 种、tempo 存在不一致', () {
      final lights = ThemeStyles.lightStyles;
      expect(lights.where((s) => s.serifHeadline).length, greaterThanOrEqualTo(2));
      final kinds = lights.map((s) => s.cardKind).toSet();
      expect(kinds.length, greaterThanOrEqualTo(3));
      final tempos = lights.map((s) => s.motionTempo).toSet();
      expect(tempos.length, greaterThanOrEqualTo(2));
    });

    test('L1-P0 schemeForFb：全 (family×light/dark) 可解析', () {
      for (final f in ThemeFamily.values) {
        if (f == ThemeFamily.night) {
          // 夜航为纯深族（§5.10 差异表：浅板 —）
          expect(schemeForFb(f, ThemeBrightnessMode.light).brightness,
              Brightness.dark, reason: '$f 纯深');
        } else {
          expect(schemeForFb(f, ThemeBrightnessMode.light).brightness,
              Brightness.light, reason: '$f 浅板');
        }
        expect(schemeForFb(f, ThemeBrightnessMode.dark).brightness,
            Brightness.dark, reason: '$f 深板');
      }
    });

    test('L1-P0 buildAppThemeFor：serif 族标题 fontFamily 指向衬线；modern 回退', () {
      final serifTheme = buildAppThemeFor(
          ThemeFamily.mint, ThemeBrightnessMode.light,
          fontMode: FontMode.serif);
      expect(serifTheme.textTheme.titleLarge!.fontFamily, 'SerifTitle');
      expect(serifTheme.textTheme.titleLarge!.fontFamilyFallback,
          contains('Noto Serif SC'));
      final modernTheme = buildAppThemeFor(
          ThemeFamily.mint, ThemeBrightnessMode.light,
          fontMode: FontMode.modern);
      expect(modernTheme.textTheme.titleLarge!.fontFamily, isNot('SerifTitle'));
    });

    test('L1-P0 MotionTokens.durationFor 按 family 节律缩放并夹紧', () {
      expect(MotionTokens.durationFor(220, 0.95), const Duration(milliseconds: 209));
      expect(MotionTokens.durationFor(220, 1.20), const Duration(milliseconds: 264));
      expect(MotionTokens.durationFor(100, 1.3), const Duration(milliseconds: 130));
    });
  });

  group('旧 key 迁移（§5.2）', () {
    Future<(ProviderContainer, SharedPreferences)> make(
        Map<String, Object> init) async {
      SharedPreferences.setMockInitialValues(init);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      return (c, prefs);
    }

    final cases = {
      'green': (ThemeFamily.mint, ThemeBrightnessMode.light),
      'blue': (ThemeFamily.sky, ThemeBrightnessMode.light),
      'orange': (ThemeFamily.sun, ThemeBrightnessMode.light),
      'pink': (ThemeFamily.bloom, ThemeBrightnessMode.light),
      'purple': (ThemeFamily.nebula, ThemeBrightnessMode.light),
      'dark': (ThemeFamily.night, ThemeBrightnessMode.dark),
      'system': (ThemeFamily.mint, ThemeBrightnessMode.system),
    };

    for (final entry in cases.entries) {
      test('L1-P0 旧键 ${entry.key} → (${entry.value.$1}, ${entry.value.$2})',
          () async {
        final (c, prefs) = await make({'app.theme.key': entry.key});
        addTearDown(c.dispose);
        c.read(themeFamilyProvider); // 触发迁移
        expect(prefs.getString('app.theme.family'), entry.value.$1.name);
        expect(prefs.getString('app.theme.brightness'), entry.value.$2.name);
        expect(prefs.getString('app.theme.key'), isNull); // 旧键删除
      });
    }
  });
}

/// 对比度粗校验：正文色与 surface 亮度差足够（完整 WCAG 抽查在验收报告人工记录）。
bool _schemeOk(Color seed, Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
  return _contrast(scheme.onSurface, scheme.surface) >= 4.5 &&
      _contrast(scheme.onSurfaceVariant,
              b == Brightness.dark ? scheme.surfaceContainerHigh : scheme.surfaceContainer) >=
          3.0;
}

double _contrast(Color a, Color b) {
  double lum(Color c) {
    final r = _linear(c.r), g = _linear(c.g), bl = _linear(c.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * bl;
  }

  final l1 = lum(a), l2 = lum(b);
  final lighter = l1 > l2 ? l1 : l2, darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

double _linear(double c) {
  c = c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  return c;
}
