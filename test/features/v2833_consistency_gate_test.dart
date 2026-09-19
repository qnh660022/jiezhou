// V2.8.3.3：四版统筹一致性门禁。
//
// 把「本轮修掉的不一致」固化为断言，防止后续版本无意回退。
// 扫描范围 = 手机端（`lib/features` + `lib/shared`），并按各版既有 OUT
// 条款排除三处无管辖区域：
//   * `desktop_*`  —— V2.8.1 O7「一切 Web/桌面端适配不做」
//   * `companions/` —— V2.8.1 O1 / V2.8.2 O1「旅伴空间一切改动排除」
//   * `features/ai/` —— V2.7.2 O11「一切 AI/大模型功能不做」（本就不该继续演进）
// 排除项已在《2.8.3.3 版本统筹裁定书》中逐条登记为余量，非遗忘。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 递归收集 dart 文件（跳过排除路径）。
List<File> scopedDartFiles() {
  final out = <File>[];
  for (final root in ['lib/features', 'lib/shared']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final p = e.path.replaceAll('\\', '/');
      if (p.contains('/desktop_')) continue;
      if (p.contains('/companions/')) continue;
      if (p.contains('/features/ai/')) continue;
      out.add(e);
    }
  }
  return out;
}

/// 取 `EmptyState(` 之后的一段窗口，判断其参数里是否用了 emoji。
/// 窗口取值 400 字符，足以覆盖多行调用，又不至于跨到下一个组件。
bool usesEmojiArg(String src, int start) {
  final end = (start + 400) < src.length ? start + 400 : src.length;
  return src.substring(start, end).contains('emoji:');
}

void main() {
  group('V2.8.3.3 门禁：空态图标岗位（手机端已全量换装）', () {
    test('1. 手机端不得再用 EmptyState(emoji:)', () {
      final offenders = <String>[];
      for (final f in scopedDartFiles()) {
        final src = f.readAsStringSync();
        var i = src.indexOf('EmptyState(');
        while (i != -1) {
          if (usesEmojiArg(src, i)) {
            final line = '\n'.allMatches(src.substring(0, i)).length + 1;
            offenders.add('${f.path}:$line');
          }
          i = src.indexOf('EmptyState(', i + 1);
        }
      }
      expect(offenders, isEmpty,
          reason: '功能岗位必须用 icon:（AppIcons.* / Icons.*_rounded），'
              'emoji 仅允许内容岗位。命中：${offenders.join('、')}');
    });

    test('2. 空态契约在组件头注中显式声明（防新代码再传 emoji）', () {
      final src =
          File('lib/shared/widgets/empty_state.dart').readAsStringSync();
      expect(src.contains('功能岗位一律用'), isTrue);
      expect(src.contains('新代码禁止再传'), isTrue);
    });
  });

  group('V2.8.3.3 门禁：提示条唯一形态（实现层）', () {
    test('3. 私有 _toast 助手一律委托 showAppSnackBar', () {
      final offenders = <String>[];
      for (final f in scopedDartFiles()) {
        final src = f.readAsStringSync();
        if (!RegExp(r'void _toast\w*\(').hasMatch(src)) continue;
        // 声明了 _toast 助手却不调用统一实现 → 仍是自建提示条
        if (!src.contains('showAppSnackBar')) offenders.add(f.path);
      }
      expect(offenders, isEmpty,
          reason: 'V2.8.1 S3：L1 轻提示唯一形态 = showAppSnackBar。'
              '命中：${offenders.join('、')}');
    });
  });

  group('V2.8.3.3 门禁：跨版标准项', () {
    test('4. 扫码入口在行程/账本域唯一实现（V2.8.1 S7 统一组件）', () {
      // 只扫「扫码入口是图标/整行 tile」的两个域；settings 域的
      // `_scanToJoin` 是「扫码并取回口令」的不同语义流程（需 await 结果），
      // 不属同组件范围，见《2.8.3.3 版本统筹裁定书》余量登记。
      final offenders = <String>[];
      for (final f in scopedDartFiles()) {
        final p = f.path.replaceAll('\\', '/');
        if (!p.contains('/features/trips/') && !p.contains('/features/ledger/')) {
          continue;
        }
        if (p.endsWith('join_by_qr_tile.dart')) continue;
        if (f.readAsStringSync().contains('const QrScanScreen()')) {
          offenders.add(p);
        }
      }
      expect(offenders, isEmpty,
          reason: '扫码入口必须走 JoinByQrTile（kIsWeb 降级内置于组件）。'
              '命中：${offenders.join('、')}');
    });

    test('5. 封面签条色值统一走 GlassTokens（不硬编码 alpha）', () {
      final src =
          File('lib/features/trips/screens/trips_home_screen.dart')
              .readAsStringSync();
      expect(src.contains('GlassTokens.coverPillFillAlpha'), isTrue,
          reason: '签条填充须走令牌（V2.8.3.1 统一）');
      expect(src.contains('GlassTokens.coverPillBorderAlpha'), isTrue,
          reason: '签条描边须走令牌');
      // 主页回退曾带回的硬编码值，不得回归
      expect(src.contains('Colors.white.withValues(alpha: 0.22)'), isFalse);
      expect(src.contains('Colors.white.withValues(alpha: 0.18)'), isFalse);
      expect(src.contains('Border.all(color: Colors.white.withValues(alpha: 0.35))'),
          isFalse);
    });
  });
}
