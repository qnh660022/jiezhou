/// CSV 解析器（RFC4180 子集）：兼容 UTF-8 BOM、CRLF/LF、双引号转义。
///
/// 纯 Dart 无 IO，可在单测覆盖。解析结果 = 行 × 单元格 的二维列表。
library;

/// 解析 CSV 文本为二维列表。
///
/// 规则：
/// * 首行 UTF-8 BOM（\uFEFF）自动剥离；
/// * 单元格可用双引号包裹，内部双引号以 `""` 转义；
/// * 引号内允许逗号与换行（含 \r\n / \n / \r）；
/// * 未闭合引号抛 [FormatException]。
List<List<String>> parseCsv(String text) {
  var s = text;
  if (s.startsWith('\uFEFF')) s = s.substring(1);
  final rows = <List<String>>[];
  final row = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          buf.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      buf.write(c);
      i++;
      continue;
    }
    if (c == '"') {
      inQuotes = true;
      i++;
    } else if (c == ',') {
      row.add(buf.toString());
      buf.clear();
      i++;
    } else if (c == '\r') {
      if (i + 1 < s.length && s[i + 1] == '\n') i += 2;
      else i++;
      row.add(buf.toString());
      buf.clear();
      rows.add(List.of(row));
      row.clear();
    } else if (c == '\n') {
      i++;
      row.add(buf.toString());
      buf.clear();
      rows.add(List.of(row));
      row.clear();
    } else {
      buf.write(c);
      i++;
    }
  }
  if (inQuotes) throw const FormatException('CSV 引号未闭合');
  if (buf.isNotEmpty || row.isNotEmpty) {
    row.add(buf.toString());
    rows.add(row);
  }
  return rows;
}
