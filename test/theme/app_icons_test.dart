// V2.8.1 S4 · 图标体系基建（规格 §7.5，≥6 例）：
// 码点一致性 / 字体资产 / 内置分类映射完备性 / 自定义兜底 / CategoryIconBox 渲染 / pubspec 声明。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/features/ledger/widgets/category_icon_box.dart';
import 'package:travel_assistant/theme/app_icons.dart';

void main() {
  test('1. codepoints.json 与 AppIcons 逐枚一致', () {
    final json = jsonDecode(
            File('design/icons/codepoints.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(json.length, 36, reason: '规格：36 枚（底栏5+分类8+功能15+品牌1+预留7）');
    final iconMap = <String, IconData>{
      'boat': AppIcons.boat,
      'spark': AppIcons.spark, 'clip': AppIcons.clip,
      'compass': AppIcons.compass, 'wallet': AppIcons.wallet,
      'user': AppIcons.user,
      'food': AppIcons.food, 'car': AppIcons.car, 'bed': AppIcons.bed,
      'ticket': AppIcons.ticket, 'bag': AppIcons.bag, 'fun': AppIcons.fun,
      'med': AppIcons.med, 'tag': AppIcons.tag,
      'trash': AppIcons.trash, 'check': AppIcons.check,
      'calendar': AppIcons.calendar, 'bookmark': AppIcons.bookmark,
      'clock': AppIcons.clock, 'bolt': AppIcons.bolt, 'sun': AppIcons.sun,
      'chart': AppIcons.chart, 'coins': AppIcons.coins,
      'members': AppIcons.members, 'toolbox': AppIcons.toolbox,
      'qr': AppIcons.qr, 'search': AppIcons.search, 'tune': AppIcons.tune,
      'camera': AppIcons.camera,
      'reserve1': AppIcons.reserve1, 'reserve2': AppIcons.reserve2,
      'reserve3': AppIcons.reserve3, 'reserve4': AppIcons.reserve4,
      'reserve5': AppIcons.reserve5, 'reserve6': AppIcons.reserve6,
      'reserve7': AppIcons.reserve7,
    };
    for (final entry in json.entries) {
      final icon = iconMap[entry.key];
      expect(icon, isNotNull, reason: 'AppIcons 缺少 ${entry.key}');
      expect(icon!.codePoint, int.parse(entry.value as String, radix: 16),
          reason: '${entry.key} 码点漂移');
      expect(icon.fontFamily, 'JieZhouIcons');
    }
  });

  test('2. TTF 字体资产存在且字形数正确', () {
    final ttf = File('assets/fonts/JieZhouIcons.ttf');
    expect(ttf.existsSync(), isTrue);
    expect(ttf.lengthSync(), greaterThan(4000), reason: '36 字形 TTF 不应过小');
    // TTF magic: 0x00010000
    final bytes = ttf.readAsBytesSync();
    expect(bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3], 0x10000);
  });

  test('3. 内置分类映射完备性（7/7 真实 key）', () {
    const builtinKeys = [
      'food', 'transport', 'stay', 'ticket', 'shopping', 'fun', 'other'
    ];
    for (final key in builtinKeys) {
      expect(AppIcons.categoryIcons.containsKey(key), isTrue,
          reason: '内置分类 $key 未映射图标');
      expect(AppIcons.categoryIcons[key], isNotNull);
    }
    expect(AppIcons.categoryIcons.length, 7);
  });

  test('4. 自定义分类统一 tag 兜底', () {
    expect(AppIcons.forCategory('c_custom_1'), AppIcons.tag);
    expect(AppIcons.forCategory(''), AppIcons.tag);
    expect(AppIcons.forCategory('food'), AppIcons.food);
  });

  testWidgets('5. CategoryIconBox：内置 key 渲染图标 / 自定义渲染 emoji 兼容',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: const [
          CategoryIconBox(categoryKey: 'food', icon: '🍜'),
          CategoryIconBox(categoryKey: 'c_my', icon: '🎯'),
        ],
      ),
    ));
    await tester.pump();
    // 内置分类：渲染 Icon（AppIcons.food），emoji 不再显示
    final icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.icon, AppIcons.food);
    expect(find.text('🍜'), findsNothing,
        reason: '内置分类岗位 emoji 已被矢量图标替换');
    // 自定义分类：保留 emoji（内容岗位白名单）
    expect(find.text('🎯'), findsOneWidget);
  });

  test('6. pubspec 已声明 JieZhouIcons 字体且零新增依赖', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('family: JieZhouIcons'), isTrue);
    expect(pubspec.contains('assets/fonts/JieZhouIcons.ttf'), isTrue);
    // 依赖白名单机制：本版零新增第三方依赖
    final deps = pubspec.indexOf('dependencies:');
    final devDeps = pubspec.indexOf('dev_dependencies:');
    final depBlock = pubspec.substring(deps, devDeps);
    expect(depBlock.contains('# V2.8'), isFalse, reason: 'V2.8 不得新增依赖');
  });
}
