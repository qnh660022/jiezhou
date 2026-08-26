/// PDF 导出单元测试：魔数、封面参数、跨空白日期与长内容。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_assistant/export/pdf_builder.dart';

void main() {
  group('buildTripPdf', () {
    test('输出以 %PDF 魔数开头', () async {
      final bytes = await buildTripPdf(
        '东京五日游',
        '日本 · 东京',
        [
          {
            'dayIndex': 1,
            'date': '8月25日 周一',
            'items': [
              {
                'type': 'attraction',
                'icon': '🏛️',
                'name': '浅草寺',
                'address': '东京都台东区浅草2-3-1',
                'time': '09:30',
                'duration': '2小时',
                'cost': '¥ 35.00',
              },
            ],
          },
        ],
        emoji: '✈️',
        coverKey: 'ocean',
        totalDays: 5,
        dateRange: '8月25日-29日',
        totalItems: 1,
      );
      expect(bytes.length, greaterThan(4));
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });

    test('跨空白日期时仍可生成精美版 PDF', () async {
      final bytes = await buildTripPdf('京都游', '日本 · 京都', [
        {
          'dayIndex': 1,
          'date': '8月25日 周一',
          'items': [
            {'type': 'attraction', 'icon': '🏛️', 'name': '伏见稻荷大社'},
          ],
        },
        {
          'dayIndex': 3,
          'date': '8月27日 周三',
          'items': [
            {
              'type': 'food',
              'icon': '🍜',
              'name': '京都站附近餐厅',
              'address': '京都府京都市下京区东盐小路町901',
              'fromName': '京都站',
              'toName': '祇园',
            },
          ],
        },
      ], totalDays: 3);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });

    test('大量安排和长文本不应阻止生成', () async {
      final items = List<Map<String, dynamic>>.generate(
        40,
        (index) => {
          'type': index.isEven ? 'attraction' : 'note',
          'icon': index.isEven ? '🏛️' : '📝',
          'name': '第 ${index + 1} 个安排：这是用于验证自动分页的较长标题',
          'address':
              '这是一个较长的地址，用来验证 PDF 卡片中的中文换行与多页布局。京都府京都市某区某街道 ${index + 1} 号',
          'note': '提前确认开放时间，并预留步行和休息时间。',
        },
      );
      final bytes = await buildTripPdf(
        '长内容测试',
        '日本 · 京都',
        [
          {'dayIndex': 1, 'date': '8月25日 周一', 'items': items},
        ],
        totalDays: 1,
        totalItems: items.length,
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });

    test('空行程不崩溃', () async {
      final bytes = await buildTripPdf('空行程', '未知', [], totalDays: 0);
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });
  });
}
