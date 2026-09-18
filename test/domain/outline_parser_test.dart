// V2.7.2 S3：大纲解析器单测（规格 §六 S3.6 ≥16 例）。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/outline_parser.dart';

void main() {
  group('文法解析', () {
    test('1. 三种天头写法 D3 / D3： / D3:', () {
      for (final head in ['D3', 'D3：', 'D3:']) {
        final r = parseOutline('$head\n西湖');
        expect(r.days.single.dayIndex, 3, reason: head);
        expect(r.days.single.items.single.name, '西湖');
      }
    });

    test('1b. 带冒号天头的其余文本忽略；非冒号天头形同普通行', () {
      final r = parseOutline('D1: 今天出发\n断桥');
      expect(r.days.single.items.single.name, '断桥');
      // "D1 西湖"（空格非冒号）不是天头 → 名字原样
      final r2 = parseOutline('D1 西湖');
      expect(r2.days, isEmpty);
      expect(r2.poolItems.single.name, 'D1 西湖');
    });

    test('2. 时间解析与越界：09:30 合法；24:00 行按无效处理；越界带名字不误吞', () {
      final r = parseOutline('D1\n09:30 看日出');
      expect(r.days.single.items.single.startTimeMin, 9 * 60 + 30);
      expect(r.days.single.items.single.name, '看日出');
      final r2 = parseOutline('24:00');
      expect(r2.days, isEmpty);
      expect(r2.invalidLines, ['24:00']);
      final r3 = parseOutline('D1\n24:00 夜航');
      expect(r3.days.single.items.single.name, '24:00 夜航',
          reason: '越界时刻不作时间前缀，整行归名（确定性）');
      expect(r3.days.single.items.single.startTimeMin, isNull);
    });

    test('3. 五种时长 2h / 90m / 1.5h / 半天 / 一天', () {
      final r = parseOutline('D1\n甲 2h\n乙 90m\n丙 1.5h\n丁 半天\n戊 一天');
      final items = r.days.single.items;
      expect(items.map((e) => e.durationMin).toList(),
          [120, 90, 90, 240, 480]);
    });

    test('4. 尾缀取最后一个匹配 token（西湖 2h 半天 → 240）', () {
      final r = parseOutline('D1\n西湖 2h 半天');
      expect(r.days.single.items.single.name, '西湖');
      expect(r.days.single.items.single.durationMin, 240);
    });

    test('5. 无天头行进池（携带 time/duration）', () {
      final r = parseOutline('灵隐寺 09:00 2h');
      // 行首非时间前缀；末 token 2h 被认作尾缀 → 名字='灵隐寺 09:00'
      expect(r.poolItems, hasLength(1));
      expect(r.poolItems.single.name, '灵隐寺 09:00');
      expect(r.poolItems.single.durationMin, 120);
      final r2 = parseOutline('09:00 灵隐寺 2h\nD1\n西湖');
      expect(r2.poolItems.single.name, '灵隐寺');
      expect(r2.poolItems.single.startTimeMin, 9 * 60);
      expect(r2.poolItems.single.durationMin, 120);
    });

    test('6. 同名同天跳过（planOutlineImport：库存 + 批次内）', () {
      final parsed = parseOutline('D1\n西湖\n西湖\n灵隐寺');
      final plan = planOutlineImport(parsed, existingNamesByDay: const {
        1: {'灵隐寺'},
      });
      expect(plan.cardCount, 1, reason: '库存已含灵隐寺 → 批内只剩西湖');
      expect(plan.cards.single.items.single.name, '西湖');
      expect(plan.skippedDuplicates, ['西湖', '灵隐寺']);
    });

    test('7. 9:30 无效行（防误吞名字）', () {
      final r = parseOutline('9:30');
      expect(r.days, isEmpty);
      expect(r.poolItems, isEmpty);
      expect(r.invalidLines, ['9:30']);
    });

    test('8. 空文档 / 纯空白', () {
      for (final raw in ['', '   \n\t\n']) {
        final r = parseOutline(raw);
        expect(r.days, isEmpty);
        expect(r.poolItems, isEmpty);
        expect(r.invalidLines, isEmpty);
      }
    });

    test('9. 仅天头（无内容行）', () {
      final r = parseOutline('D1\nD2\n');
      expect(r.days.map((d) => d.dayIndex), [1, 2]);
      expect(r.days.every((d) => d.items.isEmpty), isTrue);
    });

    test('10. 多天混排乱序（同天头重复出现 → 归并同天，天内按文档顺序）', () {
      final r = parseOutline('D2\n第二天甲\nD1\n第一天甲\nD2\n第二天乙');
      expect(r.days.map((d) => d.dayIndex).toList(), [1, 2],
          reason: '天按序号归位（确定性）');
      expect(r.days[0].items.map((e) => e.name), ['第一天甲']);
      expect(r.days[1].items.map((e) => e.name), ['第二天甲', '第二天乙']);
    });

    test('13. 中文名含空格 / emoji', () {
      final r = parseOutline('D1\n西湖 边漫步 1h\n沉船湾 🌊 2h');
      final items = r.days.single.items;
      expect(items[0].name, '西湖 边漫步');
      expect(items[1].name, '沉船湾 🌊');
      expect(items[1].durationMin, 120);
    });

    test('14. 半角全角冒号天头（含行内其他文本）', () {
      final r = parseOutline('D2：返程日\n收拾行李');
      expect(r.days.single.dayIndex, 2);
      expect(r.days.single.items.single.name, '收拾行李');
    });

    test('15. 超长行（1000 字符）不崩且完整成卡', () {
      final long = '景' * 1000;
      final r = parseOutline('D1\n$long');
      expect(r.days.single.items.single.name, long);
      expect(r.days.single.items.single.name.length, 1000);
    });

    test('16. CRLF 与 Tab 输入', () {
      final r = parseOutline('D1\r\n09:00\t西湖\t2h\r\n\r\nD2\r\n灵隐寺');
      expect(r.days[0].items.single.name, '西湖');
      expect(r.days[0].items.single.startTimeMin, 9 * 60);
      expect(r.days[0].items.single.durationMin, 120);
      expect(r.days[1].items.single.name, '灵隐寺');
    });
  });

  group('导出与往返', () {
    test('导出格式：天头 + HH:mm 名称 时长；90→1.5h；240→半天；480→一天', () {
      final text = exportOutline(
        startEpochDay: 100,
        endEpochDay: 101,
        cardsByDay: {
          1: [
            const OutlineExportCard(startTimeMin: 9 * 60, durationMin: 90, name: '西湖'),
            const OutlineExportCard(durationMin: 240, name: '灵隐寺'),
          ],
          2: [
            const OutlineExportCard(startTimeMin: 13 * 60 + 5, durationMin: 480, name: '返程'),
            const OutlineExportCard(durationMin: 45, name: '休整'),
          ],
        },
      );
      final lines = text.split('\n')..removeLast();
      expect(lines, [
        'D1',
        '09:00 西湖 1.5h',
        '灵隐寺 半天',
        'D2',
        '13:05 返程 一天',
        '休整 45m',
      ]);
    });

    test('11. round-trip：导出 → 导入逐卡一致（含无时间/无时长卡）', () {
      final cards = {
        1: [
          const OutlineExportCard(startTimeMin: 8 * 60 + 30, durationMin: 150, name: '甲'),
          const OutlineExportCard(name: '乙'),
        ],
        2: [
          const OutlineExportCard(startTimeMin: 14 * 60, name: '丙'),
          const OutlineExportCard(durationMin: 60, name: '丁'),
        ],
      };
      final text = exportOutline(startEpochDay: 100, endEpochDay: 101, cardsByDay: cards);
      final parsed = parseOutline(text);
      expect(parsed.days, hasLength(2));
      for (var d = 0; d < 2; d++) {
        final src = cards[d + 1]!;
        final back = parsed.days[d].items;
        expect(back, hasLength(src.length));
        for (var i = 0; i < src.length; i++) {
          expect(back[i].name, src[i].name);
          expect(back[i].startTimeMin, src[i].startTimeMin);
          expect(back[i].durationMin, src[i].durationMin);
        }
      }
    });

    test('12. 覆盖模式字段重建一致（计划层：新卡集 = 大纲全集）', () {
      final parsed = parseOutline('D1\n新甲 2h\n新乙');
      final plan = planOutlineImport(parsed, existingNamesByDay: const {
        1: {'旧卡A', '旧卡B'},
      }, skipDuplicates: false);
      expect(plan.cardCount, 2);
      expect(plan.skippedDuplicates, isEmpty);
      expect(plan.cards.single.items.map((e) => e.name).toList(), ['新甲', '新乙']);
      expect(plan.cards.single.items.first.durationMin, 120);
    });

    test('导入报告四元组（新增/跳过/无效/入池）齐备', () {
      final parsed = parseOutline('没天头的行 2h\nD1\n西湖\n9:99\n');
      final plan = planOutlineImport(parsed, existingNamesByDay: const {
        1: {'西湖'},
      });
      expect(plan.cardCount, 0);
      expect(plan.skippedDuplicates, ['西湖']);
      expect(plan.invalidLines, ['9:99']);
      expect(plan.toPool.single.name, '没天头的行',
          reason: '无天头行同样按文法解析（末 token 2h 为尾缀时长）');
      expect(plan.toPool.single.durationMin, 120);
    });
  });
}
