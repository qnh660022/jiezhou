// V2.7.2 S9：matchCityKey 单测（规格 §12.4 ≥8 例）+ 锦囊 prep 转清单仓储用例。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/db/database.dart';
import 'package:travel_assistant/data/repo/checklist_repo.dart';
import 'package:travel_assistant/domain/guide_match.dart';

const Map<String, String> _names = {
  '杭州': 'hangzhou',
  '苏州': 'suzhou',
  '漳州': 'zhangzhou',
  '东京': 'tokyo',
};

void main() {
  group('matchCityKey', () {
    test('1. 单城命中', () {
      expect(matchCityKey('杭州', _names), 'hangzhou');
    });

    test('2. 带市后缀命中', () {
      expect(matchCityKey('杭州市', _names), 'hangzhou');
      expect(matchCityKey('漳州市', _names), 'zhangzhou');
    });

    test('3. 多段分隔：首个命中段', () {
      expect(matchCityKey('嘉兴-杭州-苏州', _names), 'hangzhou',
          reason: '嘉兴未收录 → 跳过');
      expect(matchCityKey('杭州-苏州', _names), 'hangzhou');
      expect(matchCityKey('苏州/杭州', _names), 'suzhou');
      expect(matchCityKey('杭州、苏州', _names), 'hangzhou');
      expect(matchCityKey('杭州·苏州', _names), 'hangzhou');
      expect(matchCityKey('杭州 苏州', _names), 'hangzhou');
    });

    test('4. 无命中 → null', () {
      expect(matchCityKey('南京', _names), isNull);
      expect(matchCityKey('月球', _names), isNull);
    });

    test('5. 空串/纯空格 → null', () {
      expect(matchCityKey('', _names), isNull);
      expect(matchCityKey('   ', _names), isNull);
    });

    test('6. 全段未命中多城串 → null', () {
      expect(matchCityKey('南京-扬州', _names), isNull);
    });

    test('7. 分隔符全支持（-/／/、/·/空格）', () {
      expect(matchCityKey('东京／苏州', _names), 'tokyo');
      expect(matchCityKey('苏州／东京', _names), 'suzhou');
    });

    test('8. 空段容忍（连续分隔符）', () {
      expect(matchCityKey('-杭州-苏州', _names), 'hangzhou');
    });

    test('9. 多城带市后缀', () {
      expect(matchCityKey('杭州市-苏州市', _names), 'hangzhou');
    });
  });

  group('锦囊 prep 转清单（addKitPrepItem）', () {
    late AppDatabase db;
    late ChecklistRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase();
      repo = ChecklistRepository(db);
    });
    tearDown(() async => db.close());

    test('成功 → 去重跳过 → label 与 title 全等且 category=other', () async {
      expect(await repo.addKitPrepItem(tripId: 't1', label: '预约与门票'),
          isTrue);
      expect(await repo.addKitPrepItem(tripId: 't1', label: '预约与门票'),
          isFalse,
          reason: '同 trip 同 label 全等去重');
      expect(await repo.addKitPrepItem(tripId: 't1', label: ' 预约与门票 '),
          isFalse,
          reason: 'trim 后全等也视为重复');
      final rows = await repo.getAllByScope('trip', tripId: 't1');
      expect(rows, hasLength(1));
      expect(rows.first.label, '预约与门票');
      expect(rows.first.category, 'other', reason: '不新增清单分类');
    });

    test('空 label 拒绝', () async {
      expect(await repo.addKitPrepItem(tripId: 't1', label: '   '), isFalse);
      expect(await repo.getAllByScope('trip', tripId: 't1'), isEmpty);
    });

    test('不同 trip 不互相去重', () async {
      expect(await repo.addKitPrepItem(tripId: 't1', label: '买票'), isTrue);
      expect(await repo.addKitPrepItem(tripId: 't2', label: '买票'), isTrue);
    });
  });
}
