// V2.7.2 S5：guideRef 契约单测（规格 §8.1 / §8.5）。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/guide_ref.dart';

void main() {
  group('GuideRef.tryParse', () {
    test('1. 合法 spots/food ref 解析', () {
      final a = GuideRef.tryParse('hangzhou#spots#3');
      expect(a, isNotNull);
      expect(a!.cityKey, 'hangzhou');
      expect(a.section, 'spots');
      expect(a.index, 3);

      final b = GuideRef.tryParse('hangzhou#food#0');
      expect(b, isNotNull);
      expect(b!.section, 'food');
      expect(b.index, 0);
    });

    test('2. format() round-trip（规范化输出）', () {
      const raw = 'zhangzhou#food#12';
      final parsed = GuideRef.tryParse(raw)!;
      expect(parsed.format(), raw);
      // 再解析再格式化幂等
      expect(GuideRef.tryParse(parsed.format())!.format(), raw);
    });

    test('3. 非法：空串 / 段数不对', () {
      expect(GuideRef.tryParse(''), isNull);
      expect(GuideRef.tryParse('   '), isNull);
      expect(GuideRef.tryParse('hangzhou#spots'), isNull);
      expect(GuideRef.tryParse('hangzhou#spots#1#x'), isNull);
      expect(GuideRef.tryParse('hangzhou'), isNull);
    });

    test('4. 非法：栏不合法（仅 spots|food）', () {
      expect(GuideRef.tryParse('hangzhou#prep#1'), isNull);
      expect(GuideRef.tryParse('hangzhou#calendar#0'), isNull);
      expect(GuideRef.tryParse('hangzhou##1'), isNull);
      expect(GuideRef.tryParse('hangzhou#SPOTS#1'), isNull);
    });

    test('5. 非法：序号负数/非数字/空城 key', () {
      expect(GuideRef.tryParse('hangzhou#spots#-1'), isNull);
      expect(GuideRef.tryParse('hangzhou#spots#x'), isNull);
      expect(GuideRef.tryParse('hangzhou#spots#1.5'), isNull);
      expect(GuideRef.tryParse('#spots#1'), isNull);
    });

    test('6. 首尾空白容忍并 trim', () {
      final a = GuideRef.tryParse('  hangzhou#spots#7  ');
      expect(a, isNotNull);
      expect(a!.format(), 'hangzhou#spots#7');
    });

    test('7. prefix() 前缀反查口径', () {
      final r = GuideRef(cityKey: 'hz', section: 'food', index: 9);
      expect(r.prefix(), 'hz#food#');
      expect('hz#food#12'.startsWith(r.prefix()), isTrue);
      expect('hz#spot#12'.startsWith(r.prefix()), isFalse);
    });
  });

  group('T1 映射（timeText → durationMin）', () {
    test('8. 四枚举固定映射（附录 T1）', () {
      expect(guideDurationFromTimeText('1-2小时'), 90);
      expect(guideDurationFromTimeText('2-3小时'), 150);
      expect(guideDurationFromTimeText('半天'), 240);
      expect(guideDurationFromTimeText('一天'), 480);
    });

    test('9. 未登记/空/null → null（未估时）', () {
      expect(guideDurationFromTimeText('3小时'), isNull);
      expect(guideDurationFromTimeText(''), isNull);
      expect(guideDurationFromTimeText('  '), isNull);
      expect(guideDurationFromTimeText(null), isNull);
    });
  });
}
