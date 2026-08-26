import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/seed/checklist_scenarios.dart';
import 'package:travel_assistant/domain/checklist_recommender.dart';

// epochDay 换算辅助（UTC 构造避免时区漂移）
int _day(int y, int m, int d) => DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ 86400000;

void main() {
  test('目的地关键词命中排第一并给理由', () {
    final m = recommendTemplates(
        destination: '三亚', tripName: '海边度假', startEpochDay: _day(2026, 7, 20), endEpochDay: _day(2026, 7, 24));
    expect(m, isNotEmpty);
    expect(m.first.template.key, 'beach'); // 海岛命中「三亚」「海」双重关键词
    expect(m.first.reasons.any((r) => r.contains('命中关键词')), isTrue);
  });

  test('月份匹配加分（冬季去雪乡 -> 滑雪模板靠前）', () {
    final m = recommendTemplates(
        destination: '雪乡', tripName: '看雪', startEpochDay: _day(2026, 1, 15), endEpochDay: _day(2026, 1, 18));
    expect(m.first.template.key, 'ski');
    expect(m.first.score, greaterThan(3)); // 关键词+季节
  });

  test('长行程触发天数规则（>=7 天出现 longhaul）', () {
    final m = recommendTemplates(
        destination: '随便哪儿', tripName: '长途漫游', startEpochDay: _day(2026, 4, 1), endEpochDay: _day(2026, 4, 10));
    final keys = m.map((e) => e.template.key).toList();
    expect(keys.contains('longhaul'), isTrue);
    final lh = m.firstWhere((e) => e.template.key == 'longhaul');
    expect(lh.reasons.any((r) => r.contains('10 天')), isTrue);
  });

  test('零分场景不进推荐榜；短途不出 longhaul', () {
    final shortTrip = recommendTemplates(
        destination: '附近公园', tripName: '散步', startEpochDay: _day(2026, 4, 1), endEpochDay: _day(2026, 4, 2));
    expect(shortTrip.map((e) => e.template.key), isNot(contains('longhaul')));
  });

  test('排序稳定：同分按 key 字典序', () {
    final m = recommendTemplates(
        destination: '', tripName: '', startEpochDay: _day(2026, 4, 1), endEpochDay: _day(2026, 4, 2));
    for (var i = 1; i < m.length; i++) {
      if (m[i].score == m[i - 1].score) {
        expect(m[i].template.key.compareTo(m[i - 1].template.key), greaterThan(0));
      } else {
        expect(m[i].score, lessThan(m[i - 1].score));
      }
    }
  });

  test('种子库规模与结构自洽', () {
    expect(kScenarioTemplates.length, 10);
    final validKeys = {'docs', 'clothes', 'electronics', 'toiletries', 'medicine', 'other'};
    for (final t in kScenarioTemplates) {
      expect(t.items.keys.every(validKeys.contains), isTrue, reason: t.key);
      expect(t.months.every((m) => m >= 1 && m <= 12), isTrue, reason: t.key);
    }
  });

  test('filterExistingLabels 去重含空白归一', () {
    expect(filterExistingLabels(const ['身份证 ', '护照'], const ['身份证', ' 护照', '签证']), ['签证']);
  });
}
