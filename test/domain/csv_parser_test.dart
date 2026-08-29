import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/domain/csv_parser.dart';

void main() {
  test('BOM + CRLF 基础解析', () {
    final rows = parseCsv('\uFEFF日期,金额,备注\r\n2025-01-01,100,午餐\r\n');
    expect(rows, [
      ['日期', '金额', '备注'],
      ['2025-01-01', '100', '午餐'],
    ]);
  });

  test('引号内逗号/换行/转义引号', () {
    final rows = parseCsv('a,"b,c","d\n新行","说""你好"""\r\n');
    expect(rows, [
      ['a', 'b,c', 'd\n新行', '说"你好"'],
    ]);
  });

  test('LF 行尾与末尾无换行', () {
    final rows = parseCsv('x,y\n1,2');
    expect(rows, [
      ['x', 'y'],
      ['1', '2'],
    ]);
  });

  test('未闭合引号抛 FormatException', () {
    expect(() => parseCsv('a,"未闭合\nb'), throwsFormatException);
  });
}
