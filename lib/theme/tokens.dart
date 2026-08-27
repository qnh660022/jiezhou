import 'package:flutter/material.dart';

/// 「旅途助手」设计令牌：唯一颜色/圆角/间距/字体来源，禁止业务代码硬编码色值。

/// 圆角令牌：卡片 24 / 输入框 16 / 按钮 14
abstract final class AppRadius {
  static const double cardValue = 24;
  static const double inputValue = 16;
  static const double buttonValue = 14;

  static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));
  static const BorderRadius input = BorderRadius.all(Radius.circular(inputValue));
  static const BorderRadius button = BorderRadius.all(Radius.circular(buttonValue));

  /// 胶囊（底栏 / Chip）全圆角
  static const BorderRadius capsule = BorderRadius.all(Radius.circular(999));
}

/// 间距令牌：严格 4px 网格
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// 悬浮胶囊底栏上的操作控件统一避让值。
/// HomeShell 使用 extendBody，页面内容会延伸到导航栏后方，所有浮动按钮
/// 必须使用同一套 inset，避免在不同页面出现上下跳动或被底栏遮挡。
abstract final class AppBottomLayout {
  // 统一 FAB 底部：整体下移贴近底部，跨页面使用同一套 inset。
  // 仍略高于底部悬浮胶囊栏（约 74 + safe），避免被其遮挡。
  static const double actionButtonOffset = 80;

  /// 消费页底部合计栏的估算高度，用于让浮于其上的 FAB 不与之重叠。
  static const double totalBarHeight = 58;

  /// 有底部合计栏的页面（消费页）：FAB 上移到合计栏正上方所需底部偏移。
  static const double totalBarOffset =
      actionButtonOffset + totalBarHeight + Spacing.sm;

  /// 内容底部预留：清掉下方悬浮控件（合计栏 + FAB）的总占用，结算后词典项不被遮挡。
  static const double contentTail = totalBarOffset + actionButtonOffset;

  static double withSafeArea(BuildContext context, double value) =>
      value + MediaQuery.paddingOf(context).bottom;
}

/// 字体层级：34 / 28 / 22 / 17 / 15 / 13，大标题一律粗体
abstract final class AppFontSizes {
  static const double display = 34; // 页面大标题
  static const double headline = 28; // 区块大标题
  static const double title = 22; // 卡片标题
  static const double bodyLarge = 17; // 正文强调
  static const double body = 15; // 正文
  static const double caption = 13; // 辅助说明
}

/// 主题 Key 与中文名（持久化到 SharedPreferences 的值）
abstract final class ThemeKeys {
  static const String green = 'green'; // 薄荷绿（默认）
  static const String blue = 'blue'; // 天空蓝
  static const String orange = 'orange'; // 活力橙
  static const String pink = 'pink'; // 樱花粉
  static const String purple = 'purple'; // 星空紫
  static const String dark = 'dark'; // 石墨夜（暗色）
  static const String system = 'system'; // 跟随系统亮暗

  static const List<String> all = [
    green,
    blue,
    orange,
    pink,
    purple,
    dark,
    system,
  ];

  static const Map<String, String> labels = {
    green: '薄荷绿',
    blue: '天空蓝',
    orange: '活力橙',
    pink: '樱花粉',
    purple: '星空紫',
    dark: '石墨夜',
    system: '跟随系统',
  };

  /// 各主题种子色（全部配色的唯一源头）
  static const Map<String, Color> previewSeeds = {
    green: Color(0xFF00A878),
    blue: Color(0xFF2F80ED),
    orange: Color(0xFFF2994A),
    pink: Color(0xFFF06B9C),
    purple: Color(0xFF7B61FF),
    dark: Color(0xFF3A3F4B),
  };
}

/// 六套完整 Material3 配色方案
abstract final class AppSchemes {
  /// 薄荷绿（默认）
  static final ColorScheme mintGreen = ColorScheme.fromSeed(
    seedColor: ThemeKeys.previewSeeds[ThemeKeys.green]!,
  ).copyWith(
    primary: const Color(0xFF00A878),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFB8F2DF),
    onPrimaryContainer: const Color(0xFF00291D),
    secondary: const Color(0xFF3BA776),
    surface: const Color(0xFFF7FBF8),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF1F7F3),
    surfaceContainer: const Color(0xFFEAF2ED),
    surfaceContainerHigh: const Color(0xFFE2EBE5),
    surfaceContainerHighest: const Color(0xFFD9E4DD),
    onSurface: const Color(0xFF17211B),
    onSurfaceVariant: const Color(0xFF5A6B61),
    outlineVariant: const Color(0xFFDCE5DE),
  );

  /// 天空蓝
  static final ColorScheme skyBlue = ColorScheme.fromSeed(
    seedColor: ThemeKeys.previewSeeds[ThemeKeys.blue]!,
  ).copyWith(
    primary: const Color(0xFF2F80ED),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFCDE1FD),
    onPrimaryContainer: const Color(0xFF0B2A55),
    secondary: const Color(0xFF4E9BD4),
    surface: const Color(0xFFF6FAFE),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFEFF6FC),
    surfaceContainer: const Color(0xFFE8F0F8),
    surfaceContainerHigh: const Color(0xFFDFE9F3),
    surfaceContainerHighest: const Color(0xFFD5E1EE),
    onSurface: const Color(0xFF151C24),
    onSurfaceVariant: const Color(0xFF59636E),
    outlineVariant: const Color(0xFFDBE4EE),
  );

  /// 活力橙
  static final ColorScheme vibrantOrange = ColorScheme.fromSeed(
    seedColor: ThemeKeys.previewSeeds[ThemeKeys.orange]!,
  ).copyWith(
    primary: const Color(0xFFF2994A),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFFE3C7),
    onPrimaryContainer: const Color(0xFF4A2800),
    secondary: const Color(0xFFE08E3C),
    surface: const Color(0xFFFFFBF6),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFFCF4EA),
    surfaceContainer: const Color(0xFFF7EEE1),
    surfaceContainerHigh: const Color(0xFFF1E6D6),
    surfaceContainerHighest: const Color(0xFFEADFCB),
    onSurface: const Color(0xFF231A10),
    onSurfaceVariant: const Color(0xFF6E6053),
    outlineVariant: const Color(0xFFEFE3D2),
  );

  /// 樱花粉
  static final ColorScheme sakuraPink = ColorScheme.fromSeed(
    seedColor: ThemeKeys.previewSeeds[ThemeKeys.pink]!,
  ).copyWith(
    primary: const Color(0xFFF06B9C),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFFDCE8),
    onPrimaryContainer: const Color(0xFF47102A),
    secondary: const Color(0xFFE3779E),
    surface: const Color(0xFFFEF7F9),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFFCF0F4),
    surfaceContainer: const Color(0xFFF7E9EF),
    surfaceContainerHigh: const Color(0xFFF1E1E8),
    surfaceContainerHighest: const Color(0xFFEAD8E1),
    onSurface: const Color(0xFF23171C),
    onSurfaceVariant: const Color(0xFF6F5C64),
    outlineVariant: const Color(0xFFEFE0E7),
  );

  /// 星空紫
  static final ColorScheme starryPurple = ColorScheme.fromSeed(
    seedColor: ThemeKeys.previewSeeds[ThemeKeys.purple]!,
  ).copyWith(
    primary: const Color(0xFF7B61FF),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE3DCFF),
    onPrimaryContainer: const Color(0xFF230F69),
    secondary: const Color(0xFF8A76F2),
    surface: const Color(0xFFFAF8FF),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF3F1FB),
    surfaceContainer: const Color(0xFFECEAF7),
    surfaceContainerHigh: const Color(0xFFE4E1F3),
    surfaceContainerHighest: const Color(0xFFDDD8EF),
    onSurface: const Color(0xFF191627),
    onSurfaceVariant: const Color(0xFF625D72),
    outlineVariant: const Color(0xFFE5E1F0),
  );

  /// 石墨夜（暗色）
  static final ColorScheme graphiteDark = ColorScheme.fromSeed(
    seedColor: ThemeKeys.previewSeeds[ThemeKeys.purple]!,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF8FA6FF),
    onPrimary: const Color(0xFF0E1B4D),
    primaryContainer: const Color(0xFF33418F),
    onPrimaryContainer: const Color(0xFFDCE1FF),
    secondary: const Color(0xFF9AA6C7),
    surface: const Color(0xFF14161C),
    surfaceContainerLowest: const Color(0xFF0E1015),
    surfaceContainerLow: const Color(0xFF1A1D24),
    surfaceContainer: const Color(0xFF1E222B),
    surfaceContainerHigh: const Color(0xFF282C36),
    surfaceContainerHighest: const Color(0xFF333845),
    onSurface: const Color(0xFFE4E6EE),
    onSurfaceVariant: const Color(0xFFA8ADC0),
    outlineVariant: const Color(0xFF33384A),
  );

  static final Map<String, ColorScheme> byKey = {
    ThemeKeys.green: mintGreen,
    ThemeKeys.blue: skyBlue,
    ThemeKeys.orange: vibrantOrange,
    ThemeKeys.pink: sakuraPink,
    ThemeKeys.purple: starryPurple,
    ThemeKeys.dark: graphiteDark,
  };

  static ColorScheme schemeFor(String key) => byKey[key] ?? byKey[ThemeKeys.green]!;
}

/// 行程封面渐变（LinearGradient 常量；行程模型只存 key，渲染时查表）
abstract final class CoverGradients {
  static const ocean = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
  ); // 海屿蓝

  static const sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2994A), Color(0xFFF55E45)],
  ); // 落日橙

  static const forest = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  ); // 森野绿

  static const violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B61FF), Color(0xFFC58BF2)],
  ); // 星梦紫

  static const dusk = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF355C7D), Color(0xFF6C5B7B)],
  ); // 暮光蓝

  static const dawn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
  ); // 晨曦金

  static const List<String> keys = ['ocean', 'sunset', 'forest', 'violet', 'dusk', 'dawn'];

  static const Map<String, LinearGradient> byKey = {
    'ocean': ocean,
    'sunset': sunset,
    'forest': forest,
    'violet': violet,
    'dusk': dusk,
    'dawn': dawn,
  };

  static LinearGradient gradientFor(String key) => byKey[key] ?? ocean;

  /// 封面上的前景文字统一白色系
  static const Color onCover = Colors.white;
}

/// 头像徽章 8 色盘（avatar_badge 使用）
abstract final class AvatarPalette {
  static const List<Color> colors = [
    Color(0xFF00A878), // 薄荷
    Color(0xFF2F80ED), // 天蓝
    Color(0xFFF2994A), // 活力橙
    Color(0xFFF06B9C), // 樱粉
    Color(0xFF7B61FF), // 星紫
    Color(0xFFEB5757), // 珊瑚红
    Color(0xFF219653), // 森绿
    Color(0xFF9B51E0), // 青莲
  ];

  static const Color onColor = Colors.white;

  /// 按姓名稳定取色（逐码元求和取模，保证跨进程一致）
  static Color colorForName(String name) {
    var sum = 0;
    for (final unit in name.codeUnits) {
      sum += unit;
    }
    return colors[sum % colors.length];
  }
}

/// 文字样式助手（金额等宽数字必须走 tabularFigures）
abstract final class AppTextStyles {
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  /// 金额等宽数字样式
  static TextStyle money(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: fontSize ?? AppFontSizes.bodyLarge,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color ?? scheme.onSurface,
      fontFeatures: tabularFigures,
      letterSpacing: 0.1,
    );
  }

  /// 页面大标题 34 粗体
  static TextStyle display(ColorScheme scheme) => TextStyle(
        fontSize: AppFontSizes.display,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -0.5,
      );

  /// 区块标题 28 粗体
  static TextStyle headline(ColorScheme scheme) => TextStyle(
        fontSize: AppFontSizes.headline,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -0.4,
      );
}

/// 全局 ThemeData 构建入口（app.dart 共用；dark 主题也由此返回）
ThemeData buildAppTheme(String themeKey) {
  final scheme = AppSchemes.schemeFor(themeKey);
  final isDark = scheme.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    highlightColor: scheme.primary.withValues(alpha: 0.08),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: AppFontSizes.bodyLarge,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
    ),
    textTheme: TextTheme(
      displayLarge: AppTextStyles.display(scheme),
      displayMedium: AppTextStyles.display(scheme).copyWith(fontSize: 30),
      headlineMedium: AppTextStyles.headline(scheme),
      headlineSmall:
          AppTextStyles.headline(scheme).copyWith(fontSize: 24, letterSpacing: -0.3),
      titleLarge: TextStyle(
          fontSize: AppFontSizes.title,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.3),
      titleMedium: TextStyle(
          fontSize: AppFontSizes.bodyLarge,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface),
      titleSmall: TextStyle(
          fontSize: AppFontSizes.body,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface),
      bodyLarge: TextStyle(
          fontSize: AppFontSizes.bodyLarge,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
          height: 1.4),
      bodyMedium: TextStyle(
          fontSize: AppFontSizes.body,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
          height: 1.4),
      bodySmall: TextStyle(
          fontSize: AppFontSizes.caption,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
          height: 1.35),
      labelLarge: TextStyle(
          fontSize: AppFontSizes.body,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface),
      labelMedium: TextStyle(
          fontSize: AppFontSizes.caption,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
      hintStyle:
          TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      border: const OutlineInputBorder(
          borderRadius: AppRadius.input, borderSide: BorderSide.none),
      enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.input, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(64, 52),
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.xxl, vertical: Spacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: const TextStyle(
            fontSize: AppFontSizes.bodyLarge, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(64, 48),
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: const TextStyle(
            fontSize: AppFontSizes.body, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(
            fontSize: AppFontSizes.body, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor:
          isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.capsule),
      labelStyle:
          TextStyle(fontSize: AppFontSizes.caption, color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 6),
    ),
    dividerTheme:
        DividerThemeData(color: scheme.outlineVariant, thickness: 0.8, space: 0.8),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      showDragHandle: false,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isDark ? scheme.surfaceContainerHigh : scheme.inverseSurface,
      contentTextStyle: TextStyle(
          fontSize: AppFontSizes.caption,
          color: isDark ? scheme.onSurface : scheme.onInverseSurface),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) => states
              .contains(WidgetState.selected)
          ? scheme.onPrimary
          : scheme.outline),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary, linearTrackColor: scheme.surfaceContainerHigh),
  );
}

/// 语义色（收入/支出等业务含义，唯一出处）
abstract final class SemanticColors {
  static const Color income = Color(0xFF1E9E6A); // 收入绿
  static const Color expense = Color(0xFFD9553F); // 支出红
  static const Color warning = Color(0xFFE8A13C); // 预警橙
}
