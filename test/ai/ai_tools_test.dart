/// AI 工具纯函数回归测试：JSON 截断修复、legacy 工具调用解析、参数校验。
///
/// 背景：create_travel_pack / create_trip_plan 的 days 嵌套参数很长，
/// 曾因 maxTokens 截断导致「参数不是合法 JSON」高频报错。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_assistant/features/ai/ai_tools.dart';

void main() {
  group('jsonDecodeLoose：正常解析', () {
    test('标准 JSON', () {
      final r = jsonDecodeLoose('{"name":"成都","days":3}');
      expect(r, isNotNull);
      expect(r!['name'], '成都');
      expect(r['days'], 3);
    });

    test('前后杂质的截取', () {
      final r = jsonDecodeLoose('废话 {"a":1} 尾巴');
      expect(r!['a'], 1);
    });

    test('嵌套数组对象', () {
      final r = jsonDecodeLoose(
          '{"name":"x","days":[{"day":1,"items":[{"name":"宽窄巷子","type":"attraction"}]}]}');
      expect(r!['days'], isA<List>());
      expect((r['days'] as List).first['items'].first['name'], '宽窄巷子');
    });
  });

  group('jsonDecodeLoose：截断修复（旅游包/行程创建高频报错场景）', () {
    test('days 数组中途被截断', () {
      const truncated =
          '{"name":"成都5日游","destination":"成都","days":[{"day":1,"items":[{"name":"宽窄巷子"},{"name":"锦里"}'
          ;
      final r = jsonDecodeLoose(truncated);
      expect(r, isNotNull);
      expect(r!['name'], '成都5日游');
      final days = r['days'] as List;
      expect(days, isNotEmpty);
      expect((days.first['items'] as List).length, 2);
    });

    test('字符串值中途截断', () {
      final r = jsonDecodeLoose('{"title":"午餐","note":"大家吃得');
      expect(r!['title'], '午餐');
      expect(r['note'], '大家吃得');
    });

    test('悬空键名截断', () {
      final r = jsonDecodeLoose('{"a":1,"b');
      expect(r!['a'], 1);
      expect(r.containsKey('b'), isFalse);
    });

    test('悬空冒号截断', () {
      final r = jsonDecodeLoose('{"a":1,"b":');
      expect(r!['a'], 1);
      expect(r.containsKey('b'), isFalse);
    });

    test('数组尾逗号截断', () {
      final r = jsonDecodeLoose('{"memberNames":["你","小明",');
      expect(r!['memberNames'], ['你', '小明']);
    });

    test('嵌套对象截断（travel pack 完整场景）', () {
      const t = '{"tripName":"大理4日","destination":"大理","startDate":"2026-10-01",'
          '"endDate":"2026-10-04","memberNames":["你","小明"],"budgetYuan":5000,'
          '"days":[{"day":1,"items":[{"name":"古城","type":"attraction","costYuan":80},'
          '{"name":"洱海","type":"attraction"}]},{"day":2,"items":[{"name":"苍山"}]';
      final r = jsonDecodeLoose(t);
      expect(r!['tripName'], '大理4日');
      final days = r['days'] as List;
      expect(days.length, 2);
      expect((days[0]['items'] as List).length, 2);
      expect((days[1]['items'] as List).first['name'], '苍山');
      expect(r['budgetYuan'], 5000);
    });

    test('无法修复时抛 FormatException', () {
      expect(() => jsonDecodeLoose('完全不是 JSON'), throwsFormatException);
    });
  });

  group('parseLegacyToolCalls：<tool_call> 文本兜底解析', () {
    test('标准 legacy 格式', () {
      final calls = parseLegacyToolCalls(
          '<tool_call><function=add_expense><parameter=title>午餐</parameter>'
          '<parameter=amountYuan>45</parameter></tool_call>');
      expect(calls.length, 1);
      expect(calls.first.name, 'add_expense');
      final args = jsonDecodeLoose(calls.first.argumentsJson);
      expect(args!['title'], '午餐');
      expect(args['amountYuan'], 45);
    });

    test('对象参数（days 嵌套）', () {
      final calls = parseLegacyToolCalls(
          '<tool_call><function=create_trip_plan><parameter=name>test</parameter>'
          '<parameter=days>{"day":1,"items":[{"name":"a"}]}</parameter></tool_call>');
      expect(calls.length, 1);
      final args = jsonDecodeLoose(calls.first.argumentsJson);
      expect((args!['days'] as Map)['day'], 1);
    });

    test('缺闭合标签的截断兜底', () {
      final calls = parseLegacyToolCalls(
          '<tool_call><function=query_expenses><parameter=detail>true</parameter>');
      expect(calls.length, 1);
      expect(calls.first.name, 'query_expenses');
    });

    test('非工具文本返回空', () {
      expect(parseLegacyToolCalls('普通回答文本'), isEmpty);
    });
  });
}
