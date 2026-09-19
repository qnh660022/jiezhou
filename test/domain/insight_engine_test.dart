// V2.8.1 S8 · 洞察语引擎（规格 §11.4，引擎 6 例）：
// 阈值边界 / 空数据 / 上升下降 / 多条排序上限 2。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/insight_engine.dart';

void main() {
  String name(String key) => switch (key) {
        'food' => '餐饮',
        'shopping' => '购物',
        'fun' => '娱乐',
        _ => key,
      };

  test('1. 数据不足：当月 <10 笔 → 空列表', () {
    final out = monthlyInsights(
      curMonth: {'food': 20000},
      prevMonth: {'food': 10000},
      categoryName: name,
      curCount: 9,
    );
    expect(out, isEmpty);
  });

  test('2. 数据不足：上月全空（<2 月数据）→ 空列表', () {
    final out = monthlyInsights(
      curMonth: {'food': 20000},
      prevMonth: {},
      categoryName: name,
      curCount: 30,
    );
    expect(out, isEmpty);
  });

  test('3. 触发下限边界：prev=5000 分且涨幅 15% → 多花 15%', () {
    final out = monthlyInsights(
      curMonth: {'food': 5750},
      prevMonth: {'food': 5000},
      categoryName: name,
      curCount: 10,
    );
    expect(out.length, 1);
    expect(out.first.text, '餐饮比上月多花 15%');
  });

  test('4. prev < 5000 分不触发（即使涨幅大）', () {
    final out = monthlyInsights(
      curMonth: {'food': 4000},
      prevMonth: {'food': 1000},
      categoryName: name,
      curCount: 10,
    );
    expect(out, isEmpty, reason: '阈值边界：prev ≥ 5000 分才触发');
  });

  test('5. 下降文案：省了 21%', () {
    final out = monthlyInsights(
      curMonth: {'food': 7900},
      prevMonth: {'food': 10000},
      categoryName: name,
      curCount: 10,
    );
    expect(out.length, 1);
    expect(out.first.text, '餐饮比上月省了 21%');
    expect(out.first.changeRatio, lessThan(0));
  });

  test('6. 多条按 |涨幅| 降序且上限 2 条', () {
    final out = monthlyInsights(
      curMonth: {
        'food': 10000, // +100%
        'shopping': 11500, // +15%（刚好触发线）
        'fun': 100, // -99%
      },
      prevMonth: {'food': 5000, 'shopping': 10000, 'fun': 10000},
      categoryName: name,
      curCount: 40,
    );
    expect(out.length, 2, reason: '至多 2 条');
    expect(out.first.categoryKey, 'food', reason: '|+100%| 最大排第一');
    expect(out.first.text, '餐饮比上月多花 100%');
    expect(out.last.categoryKey, 'fun', reason: '|-99%| 次之');
  });
}
