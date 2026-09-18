/// 大纲双向编辑解析器（V2.7.2 S3，纯 Dart，零 AI / 零网络）。
///
/// 文法（规格 §六 S3.3，唯一权威定义；导出与导入同文法对称，T3）：
/// ```
/// document   := line*                      空行（仅空白字符）忽略
/// dayHeader  := ^\s*"D" digits \s* ["："|":"]? \s*$   设定当前天（半角/全角冒号均合法）
/// itemLine   := [time \s+] name [ \s+ duration]
/// time       := HH:mm（两位小时两位分钟，00:00–23:59）→ startTimeMin = h*60+m
/// duration   := digits["."digits]"h" | digits"m" | "半天" | "一天"
///               → 1.5h=90；m 为整分钟；"半天"=240；"一天"=480
/// name       := 去除已匹配前缀/尾缀后的非空剩余文本（trim）
/// 无效行     := 无法解析出非空 name 的行    → 原样进导入报告
/// ```
///
/// 解析细则（逐条验收）：
/// 1. `D3`、`D3：`、`D3:` 均合法；带冒号的天头其余文本忽略；
/// 2. 未出现任何天头前的 itemLine → 不建卡，进想去池（携带已解析 time/duration）；
/// 3. 尾缀时长取**最后一个**匹配 token（`西湖 2h 半天` → 240）；
/// 4. 同名同天去重在导入计划层处理（[planOutlineImport]）；
/// 5. `HH:mm` 必须两位小时两位分钟；`9:30` 属无效行（防误吞名字）；
/// 6. 单遍逐行、token 前缀匹配，无正则回溯风险。
library;

/// 大纲条目（解析产物最小单元）。
class OutlineItem {
  const OutlineItem({required this.name, this.startTimeMin, this.durationMin});

  final String name;

  /// 当日分钟数（0..1439）；null = 未写时间
  final int? startTimeMin;

  /// 分钟数；null = 未写时长
  final int? durationMin;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutlineItem &&
          other.name == name &&
          other.startTimeMin == startTimeMin &&
          other.durationMin == durationMin;

  @override
  int get hashCode => Object.hash(name, startTimeMin, durationMin);

  @override
  String toString() => 'OutlineItem($name, ${startTimeMin ?? '-'}, ${durationMin ?? '-'})';
}

/// 单天解析结果。
class OutlineDay {
  const OutlineDay({required this.dayIndex, required this.items});

  /// 天序号（1 起，来自 `D<n>`）
  final int dayIndex;
  final List<OutlineItem> items;
}

/// 解析结果：按文档顺序的天列表 + 无天头行（入池）+ 无效行。
class OutlineParseResult {
  const OutlineParseResult({
    required this.days,
    required this.poolItems,
    required this.invalidLines,
  });

  /// 仅含出现过的天（`D2` 与 `D5` 之间无内容时 `D3/D4` 不存在）
  final List<OutlineDay> days;

  /// 未出现任何天头前的 itemLine → 想去池
  final List<OutlineItem> poolItems;

  /// 无效行原文（trim 后非空才计入）
  final List<String> invalidLines;
}

/// 解析大纲文本（确定性规则解析；支持 \n / \r\n / \t 输入）。
OutlineParseResult parseOutline(String raw) {
  final days = <int, List<OutlineItem>>{};
  final poolItems = <OutlineItem>[];
  final invalidLines = <String>[];
  int? currentDay;

  for (var rawLine in raw.split('\n')) {
    if (rawLine.endsWith('\r')) {
      rawLine = rawLine.substring(0, rawLine.length - 1);
    }
    final line = rawLine.replaceAll('\t', ' ');
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue; // 空行忽略

    final day = _matchDayHeader(trimmed);
    if (day != null) {
      currentDay = day;
      days.putIfAbsent(day, () => []); // 仅天头（无内容）也记账
      continue;
    }

    final item = _matchItemLine(trimmed);
    if (item == null) {
      invalidLines.add(trimmed);
    } else if (currentDay == null) {
      poolItems.add(item); // 天头前的行 → 想去池
    } else {
      (days[currentDay] ??= []).add(item);
    }
  }
  final dayList = [
    for (final k in days.keys.toList()..sort()) OutlineDay(dayIndex: k, items: days[k]!),
  ];
  return OutlineParseResult(
      days: dayList, poolItems: poolItems, invalidLines: invalidLines);
}

/// `D3` / `D3：` / `D3:`（可带其余文本，忽略）；前缀匹配，digits ≥ 1 位。
int? _matchDayHeader(String line) {
  if (line.isEmpty) return null;
  final first = line.codeUnitAt(0);
  // 支持 D / d；后接 digits
  if (first != 0x44 && first != 0x64) return null; // 'D' / 'd'
  var i = 1;
  var digits = 0;
  var value = 0;
  while (i < line.length && _isDigit(line.codeUnitAt(i))) {
    value = value * 10 + (line.codeUnitAt(i) - 0x30);
    digits++;
    i++;
  }
  if (digits == 0) return null;
  // 天头余文：仅空白，或以冒号（半/全角）开头
  if (i >= line.length) return value;
  final rest = line.substring(i).trimLeft();
  if (rest.isEmpty) return value;
  final colon = rest.codeUnitAt(0);
  if (colon == 0x3A || colon == 0xFF1A) return value; // ':' / '：'
  return null;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// itemLine：`[HH:mm ]name[ 时长]`；时长尾缀取最后一个匹配 token。
OutlineItem? _matchItemLine(String line) {
  var rest = line;
  int? startTimeMin;

  // 前缀时间：HH:mm 两位小时两位分钟
  if (rest.length >= 6 && _isDigit(rest.codeUnitAt(0)) && _isDigit(rest.codeUnitAt(1)) && rest.codeUnitAt(2) == 0x3A && _isDigit(rest.codeUnitAt(3)) && _isDigit(rest.codeUnitAt(4))) {
    final sep = rest.codeUnitAt(5);
    if (sep == 0x20) {
      final h = (rest.codeUnitAt(0) - 0x30) * 10 + (rest.codeUnitAt(1) - 0x30);
      final m = (rest.codeUnitAt(3) - 0x30) * 10 + (rest.codeUnitAt(4) - 0x30);
      if (h <= 23 && m <= 59) {
        startTimeMin = h * 60 + m;
        rest = rest.substring(6).trimLeft();
      }
    }
  }

  if (rest.isEmpty) return null;

  // 尾缀时长：从末尾逐 token 剥离；时长取**文本最后一个**匹配 token
  // （`西湖 2h 半天` → 半天=240，更靠内的 2h 只从名字里剥掉、不覆盖取值）
  int? durationMin;
  var tail = rest;
  while (true) {
    final sp = tail.lastIndexOf(' ');
    if (sp < 0) break;
    final token = tail.substring(sp + 1);
    final parsed = _parseDuration(token);
    if (parsed == null) break;
    durationMin ??= parsed;
    tail = tail.substring(0, sp).trimRight();
  }

  final name = tail.trim();
  if (name.isEmpty) return null;
  // 「防误吞名字」：剥完前缀/尾缀后，剩余文本若是类时刻裸 token
  // （`9:30` / `24:00` 等 1-2 位数字 + 冒号 + 2 位数字），按无效行处理。
  if (_looksLikeBareTime(name)) return null;
  return OutlineItem(name: name, startTimeMin: startTimeMin, durationMin: durationMin);
}

/// `H:mm` / `HH:mm` 形态（不校验数值范围；仅识别形态）。
bool _looksLikeBareTime(String s) {
  final colon = s.indexOf(':');
  if (colon < 1 || colon > 2 || s.length != colon + 3) return false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (i == colon) continue;
    if (!_isDigit(c)) return false;
  }
  return true;
}

/// `2h` / `1.5h` / `90m` / `半天` / `一天`；非法返回 null。
int? _parseDuration(String token) {
  final t = token.trim();
  if (t.isEmpty) return null;
  if (t == '半天') return 240;
  if (t == '一天') return 480;
  final lower = t.toLowerCase();
  if (lower.endsWith('h')) {
    final numPart = lower.substring(0, lower.length - 1);
    final v = _parseNumber(numPart);
    if (v == null) return null;
    return (v * 60).round();
  }
  if (lower.endsWith('m')) {
    final numPart = lower.substring(0, lower.length - 1);
    final v = _parseNumber(numPart);
    if (v == null) return null;
    return v.round();
  }
  return null;
}

/// 整数或一位小数（`2` / `1.5`）；非法/超界返回 null。
double? _parseNumber(String s) {
  if (s.isEmpty) return null;
  var seenDot = false;
  var ok = true;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x2E) {
      if (seenDot) {
        ok = false;
        break;
      }
      seenDot = true;
    } else if (!_isDigit(c)) {
      ok = false;
      break;
    }
  }
  if (!ok) return null;
  final v = double.tryParse(s);
  return v;
}

// ===== 导入计划（去重 / 分流） =====

/// 导入计划：给 UI/仓库层的确定性行动清单。
class OutlineImportPlan {
  const OutlineImportPlan({
    required this.cards,
    required this.toPool,
    required this.skippedDuplicates,
    required this.invalidLines,
  });

  /// 待建卡（按天分组，天内保持文档顺序）
  final List<OutlineDay> cards;

  /// 入池条目（无天头行 + S6 前的「入池挂起」占位口径）
  final List<OutlineItem> toPool;
  final List<String> skippedDuplicates;
  final List<String> invalidLines;

  int get cardCount => cards.fold(0, (s, d) => s + d.items.length);
}

/// 由解析结果生成导入计划：
/// - [existingNamesByDay]：行程当前 各天已有的卡名（trim 后）；
/// - 同名同天（trim 后全等）→ 跳过并计数（含批次内去重）。
OutlineImportPlan planOutlineImport(
  OutlineParseResult parsed, {
  required Map<int, Set<String>> existingNamesByDay,
  bool skipDuplicates = true,
}) {
  final cards = <OutlineDay>[];
  final skipped = <String>[];
  final names = <int, Set<String>>{
    for (final e in existingNamesByDay.entries) e.key: {...e.value},
  };
  for (final day in parsed.days) {
    final items = <OutlineItem>[];
    final bucket = names.putIfAbsent(day.dayIndex, () => <String>{});
    for (final it in day.items) {
      final key = it.name.trim();
      if (skipDuplicates && bucket.contains(key)) {
        skipped.add(it.name);
        continue;
      }
      bucket.add(key);
      items.add(it);
    }
    if (items.isNotEmpty) cards.add(OutlineDay(dayIndex: day.dayIndex, items: items));
  }
  return OutlineImportPlan(
    cards: cards,
    toPool: parsed.poolItems,
    skippedDuplicates: skipped,
    invalidLines: parsed.invalidLines,
  );
}

// ===== 导出（对称文法） =====

/// 导出行数据源（天 + 卡最小视图；调用方从 drift 行/领域记录构造）。
class OutlineExportCard {
  const OutlineExportCard({this.startTimeMin, this.durationMin, required this.name});

  final int? startTimeMin;
  final int? durationMin;
  final String name;
}

/// 时长输出：240/480 特判 半天/一天；≥60 → `Xh`（90 → `1.5h`）；<60 → `Xm`；无则 ''。
String formatOutlineDuration(int? durationMin) {
  final d = durationMin;
  if (d == null) return '';
  if (d == 240) return '半天';
  if (d == 480) return '一天';
  if (d >= 60) {
    if (d % 60 == 0) return '${d ~/ 60}h';
    final h = d / 60;
    var text = h.toStringAsFixed(1);
    if (text.endsWith('0')) text = text.substring(0, text.length - 2);
    return '${text}h';
  }
  return '${d}m';
}

/// 导出大纲文本：按天（天头 `D1`…）、天内按传入顺序（调用方保证按 sortOrder）。
/// 想去池、备胎卡不进导出（调用方过滤）。
String exportOutline({
  required int startEpochDay,
  required int endEpochDay,
  required Map<int, List<OutlineExportCard>> cardsByDay,
}) {
  final buf = StringBuffer();
  final n = endEpochDay < startEpochDay ? 0 : endEpochDay - startEpochDay + 1;
  for (var i = 1; i <= n; i++) {
    buf.write('D$i');
    final cards = cardsByDay[i] ?? const <OutlineExportCard>[];
    if (cards.isEmpty) {
      buf.writeln();
      continue;
    }
    buf.writeln();
    for (final c in cards) {
      final time = c.startTimeMin == null
          ? ''
          : '${(c.startTimeMin! ~/ 60).toString().padLeft(2, '0')}:${(c.startTimeMin! % 60).toString().padLeft(2, '0')} ';
      final dur = formatOutlineDuration(c.durationMin);
      buf.writeln('$time${c.name}${dur.isEmpty ? '' : ' $dur'}');
    }
  }
  return buf.toString();
}
