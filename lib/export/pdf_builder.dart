/// PDF 导出：内置 Roboto + Droid Sans Fallback 字体，西文/中文混排直接嵌入渲染。
library;

import "dart:typed_data";

import "package:flutter/services.dart" show rootBundle;
import "package:flutter/widgets.dart" show WidgetsFlutterBinding;
import "../core/date_utils.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

/// 打包进 assets 的 PDF 内置字体缓存（均为 Apache-2.0，可合法随应用分发）。
const String _kCjkFontAsset = "assets/fonts/CJKFont.ttf";
const String _kLatinRegularAsset = "assets/fonts/Roboto-Regular.ttf";
const String _kLatinBoldAsset = "assets/fonts/Roboto-Bold.ttf";

Future<pw.Font> _loadFont(String asset) async {
  WidgetsFlutterBinding.ensureInitialized();
  return pw.Font.ttf(await rootBundle.load(asset));
}

const _ink = PdfColor.fromInt(0xFF17211B);
const _muted = PdfColor.fromInt(0xFF5A6B61);
const _line = PdfColor.fromInt(0xFFDCE5DE);
const _surface = PdfColor.fromInt(0xFFF7FBF8);
const _surfaceLow = PdfColor.fromInt(0xFFF1F7F3);
const _white = PdfColor.fromInt(0xFFFFFFFF);
const _mint = PdfColor.fromInt(0xFF00A878);

const Map<String, List<PdfColor>> _coverGradients = {
  "ocean": [PdfColor.fromInt(0xFF2F80ED), PdfColor.fromInt(0xFF56CCF2)],
  "sunset": [PdfColor.fromInt(0xFFF2994A), PdfColor.fromInt(0xFFF55E45)],
  "forest": [PdfColor.fromInt(0xFF11998E), PdfColor.fromInt(0xFF38EF7D)],
  "violet": [PdfColor.fromInt(0xFF7B61FF), PdfColor.fromInt(0xFFC58BF2)],
  "dusk": [PdfColor.fromInt(0xFF355C7D), PdfColor.fromInt(0xFF6C5B7B)],
  "dawn": [PdfColor.fromInt(0xFFF7971E), PdfColor.fromInt(0xFFFFD200)],
};

const Map<String, PdfColor> _typeColors = {
  "attraction": PdfColor.fromInt(0xFF00A878),
  "food": PdfColor.fromInt(0xFFF2994A),
  "transport": PdfColor.fromInt(0xFF2F80ED),
  "stay": PdfColor.fromInt(0xFF7B61FF),
  "note": PdfColor.fromInt(0xFF9B51E0),
};

const Map<String, String> _typeLabels = {
  "attraction": "景点",
  "food": "餐饮",
  "transport": "交通",
  "stay": "住宿",
  "note": "备注",
};

PdfColor _typeColor(Object? type) =>
    _typeColors[type?.toString()] ?? _typeColors["note"]!;

String _typeLabel(Object? type) =>
    _typeLabels[type?.toString()] ?? _typeLabels["note"]!;

PdfColor _soften(PdfColor color, double amount) {
  return PdfColor(
    color.red + (1 - color.red) * amount,
    color.green + (1 - color.green) * amount,
    color.blue + (1 - color.blue) * amount,
  );
}

String _stringValue(Object? value) => value?.toString().trim() ?? "";

String _dayNumber(Map<String, dynamic> day, int fallback) {
  final value = day["dayIndex"];
  if (value is int && value > 0) return value.toString();
  return fallback.toString();
}

pw.TextStyle _textStyle({
  double? size,
  PdfColor color = _ink,
  pw.FontWeight weight = pw.FontWeight.normal,
  double? lineHeight,
}) {
  return pw.TextStyle(
    fontSize: size,
    color: color,
    fontWeight: weight,
    lineSpacing: lineHeight,
  );
}

pw.Widget _metric(String value, String label) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor(1, 1, 1, 0.16),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColor(1, 1, 1, 0.28), width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: _textStyle(
              size: 17,
              color: _white,
              weight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            label,
            style: _textStyle(size: 8.5, color: PdfColor(1, 1, 1, 0.82)),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _detailChip(String text, {PdfColor color = _muted}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: pw.BoxDecoration(
      color: _surfaceLow,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(text, style: _textStyle(size: 8.5, color: color)),
  );
}

pw.Widget _itemCard(Map<String, dynamic> item) {
  final type = item["type"];
  final accent = _typeColor(type);
  final icon = _stringValue(item["icon"]);
  final rawName = _stringValue(item["name"]);
  final name = rawName.isEmpty ? "未命名安排" : rawName;
  final address = _stringValue(item["address"]);
  final time = _stringValue(item["time"]);
  final duration = _stringValue(item["duration"]);
  final cost = _stringValue(item["cost"]);
  final note = _stringValue(item["note"]);
  final fromName = _stringValue(item["fromName"]);
  final toName = _stringValue(item["toName"]);
  final flightNo = _stringValue(item["flightNo"]);

  final chips = <pw.Widget>[];
  if (time.isNotEmpty) chips.add(_detailChip(time, color: accent));
  if (duration.isNotEmpty) chips.add(_detailChip(duration));
  if (cost.isNotEmpty) chips.add(_detailChip(cost, color: _ink));

  final transportLine = [
    if (fromName.isNotEmpty) fromName,
    if (toName.isNotEmpty) toName,
  ].join("  →  ");

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _white,
      borderRadius: pw.BorderRadius.circular(13),
      border: pw.Border.all(color: _line, width: 0.8),
      boxShadow: [
        pw.BoxShadow(
          color: PdfColor(0.08, 0.16, 0.11, 0.06),
          blurRadius: 4,
          offset: const PdfPoint(0, 2),
        ),
      ],
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 34,
          height: 34,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: _soften(accent, 0.84),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            icon.isNotEmpty ? icon : _typeLabel(type).substring(0, 1),
            textAlign: pw.TextAlign.center,
            style: _textStyle(
              size: 14,
              color: accent,
              weight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      name,
                      style: _textStyle(
                        size: 11.5,
                        weight: pw.FontWeight.bold,
                        lineHeight: 1.25,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    _typeLabel(type),
                    style: _textStyle(
                      size: 8.5,
                      color: accent,
                      weight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                pw.SizedBox(height: 7),
                pw.Wrap(spacing: 5, runSpacing: 4, children: chips),
              ],
              if (transportLine.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text(
                  transportLine,
                  style: _textStyle(
                    size: 9.5,
                    color: accent,
                    weight: pw.FontWeight.bold,
                  ),
                ),
              ],
              if (flightNo.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  "航班/班次  $flightNo",
                  style: _textStyle(size: 9, color: _muted),
                ),
              ],
              if (address.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  address,
                  style: _textStyle(size: 9.5, color: _muted, lineHeight: 1.2),
                ),
              ],
              if (note.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  note,
                  style: _textStyle(size: 9, color: _muted, lineHeight: 1.2),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// 行程总览行数据（V2.7.2 S12；纯数据便于单测）。
class OverviewRowData {
  const OverviewRowData({
    required this.dayIndex,
    required this.date,
    required this.weekday,
    required this.count,
    required this.summary,
  });

  final int dayIndex;

  /// 调用方传入的日期文案。
  final String date;
  final String weekday;

  /// 当天正式卡数（备胎已排除）。
  final int count;

  /// 摘要：前 3 条（有时间 → `HH:mm 名称`；无 → `名称`）；空天 → `——`。
  final List<String> summary;
}

/// 总览行构造：摘要取前 3（按传入顺序，调用方已按 sortOrder/时间排序），
/// 备胎（backupOf != null）防御性再过滤一次。
List<OverviewRowData> buildOverviewRows(List<Map<String, dynamic>> days) {
  final rows = <OverviewRowData>[];
  for (final day in days) {
    final items = (day["items"] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item["backupOf"] == null)
            .toList() ??
        <Map<String, dynamic>>[];
    final summary = <String>[
      for (final it in items.take(3))
        '${(it["time"] ?? "").toString().trim().isEmpty ? "" : "${it["time"]} "}${it["name"] ?? ""}',
    ];
    if (items.length > 3) summary.add("…等 ${items.length - 3} 项");
    if (summary.isEmpty) summary.add("——");
    final epoch = day["epochDay"];
    rows.add(OverviewRowData(
      dayIndex: (day["dayIndex"] as int?) ?? (rows.length + 1),
      date: (day["date"] ?? "").toString(),
      weekday: epoch is int ? weekdayCnOf(epoch) : "",
      count: items.length,
      summary: summary,
    ));
  }
  return rows;
}

/// 手动分块：22 行/块（每块自带表头，块间 pw.NewPage 由渲染层处理）。
List<List<OverviewRowData>> splitOverviewBlocks(
  List<OverviewRowData> rows, {
  int perBlock = 22,
}) {
  final blocks = <List<OverviewRowData>>[];
  for (var i = 0; i < rows.length; i += perBlock) {
    blocks.add(rows.sublist(i, (i + perBlock).clamp(0, rows.length)));
  }
  return blocks;
}

/// 生成精美版行程 PDF。
///
/// [days] 每项至少包含 date/items；可选字段包括 dayIndex、type、time、duration、cost、note、交通信息。
/// 旧调用只传前三个参数仍然兼容，新增参数用于复用 App 的封面视觉和完整行程数据。
Future<Uint8List> buildTripPdf(
  String name,
  String dest,
  List<Map<String, dynamic>> days, {
  String emoji = "",
  String coverKey = "ocean",
  int? totalDays,
  String? dateRange,
  int? totalItems,
}) async {
  final latinRegular = await _loadFont(_kLatinRegularAsset);
  final latinBold = await _loadFont(_kLatinBoldAsset);
  final cjk = await _loadFont(_kCjkFontAsset);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: latinRegular,
      bold: latinBold,
      italic: latinRegular,
      boldItalic: latinBold,
      fontFallback: [cjk],
    ),
  );

  final gradientColors = _coverGradients[coverKey] ?? _coverGradients["ocean"]!;
  final safeName = name.trim().isEmpty ? "未命名行程" : name.trim();
  final safeDest = dest.trim().isEmpty ? "旅行计划" : dest.trim();
  final dayCount = totalDays ?? days.length;
  final itemCount =
      totalItems ??
      days.fold<int>(
        0,
        (sum, day) => sum + ((day["items"] as List?)?.length ?? 0),
      );

  // 视觉封面：整页渐变 + 行程摘要 + 三项关键统计。
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                ),
              ),
            ),
            pw.Positioned(
              right: -55,
              top: -35,
              child: pw.Container(
                width: 230,
                height: 230,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor(1, 1, 1, 0.10),
                ),
              ),
            ),
            pw.Positioned(
              left: -70,
              bottom: 110,
              child: pw.Container(
                width: 185,
                height: 185,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: PdfColor(1, 1, 1, 0.08),
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(42, 54, 42, 46),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          "TRAVEL PLAN",
                          style: _textStyle(
                            size: 10,
                            color: PdfColor(1, 1, 1, 0.82),
                            weight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Text(
                        "芥舟",
                        style: _textStyle(
                          size: 10,
                          color: PdfColor(1, 1, 1, 0.82),
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  if (emoji.trim().isNotEmpty)
                    pw.Text(
                      emoji.trim(),
                      style: _textStyle(size: 36, color: _white),
                    ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    safeName,
                    style: _textStyle(
                      size: 29,
                      color: _white,
                      weight: pw.FontWeight.bold,
                      lineHeight: 1.15,
                    ),
                  ),
                  pw.SizedBox(height: 9),
                  pw.Text(
                    safeDest,
                    style: _textStyle(size: 14, color: PdfColor(1, 1, 1, 0.90)),
                  ),
                  if (dateRange != null && dateRange.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      dateRange.trim(),
                      style: _textStyle(
                        size: 10.5,
                        color: PdfColor(1, 1, 1, 0.78),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 26),
                  pw.Row(
                    children: [
                      _metric("$dayCount", "旅行天数"),
                      pw.SizedBox(width: 8),
                      _metric("$itemCount", "安排事项"),
                      pw.SizedBox(width: 8),
                      _metric("${days.length}", "有安排日"),
                    ],
                  ),
                  pw.SizedBox(height: 22),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor(0, 0, 0, 0.14),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      "把每一天，走成值得收藏的故事。",
                      style: _textStyle(
                        size: 10,
                        color: PdfColor(1, 1, 1, 0.88),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // 行程总览页（V2.7.2 S12）：封面之后、每日详情之前；手动分块 22 行/块，
  // 每块自带表头；备胎已在数据构造中防御性排除。
  final overviewRows = buildOverviewRows(days);
  if (overviewRows.isNotEmpty) {
    doc.addPage(
      _buildOverviewPage(
        safeName,
        dateRange,
        splitOverviewBlocks(overviewRows),
      ),
    );
  }

  // 内容页使用 MultiPage：长地址、大量安排会自动分页；每个日期仍从新页开始。
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(38, 42, 38, 40),
      header: (ctx) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              safeName,
              style: _textStyle(
                size: 9,
                color: _muted,
                weight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text("行程安排", style: _textStyle(size: 9, color: _muted)),
        ],
      ),
      footer: (ctx) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              "芥舟 · 旅行计划",
              style: _textStyle(size: 8, color: _muted),
            ),
          ),
          pw.Text(
            "第 ${ctx.pageNumber} 页",
            style: _textStyle(size: 8, color: _muted),
          ),
        ],
      ),
      build: (ctx) {
        final widgets = <pw.Widget>[];
        if (days.isEmpty) {
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: _surface,
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: _line),
              ),
              child: pw.Text(
                "这趟旅程还没有安排事项。",
                style: _textStyle(size: 12, color: _muted),
              ),
            ),
          );
        }
        for (var i = 0; i < days.length; i++) {
          final day = days[i];
          final items =
              (day["items"] as List?)
                  ?.whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList() ??
              <Map<String, dynamic>>[];
          if (i > 0) widgets.add(pw.NewPage());
          widgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _line, width: 0.8),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _mint,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      "DAY ${_dayNumber(day, i + 1)}",
                      style: _textStyle(
                        size: 10,
                        color: _white,
                        weight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _stringValue(day["date"]).isEmpty
                              ? "日期待定"
                              : _stringValue(day["date"]),
                          style: _textStyle(
                            size: 17,
                            weight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          "${items.length} 个安排",
                          style: _textStyle(size: 9.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          if (items.isEmpty) {
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(13),
                decoration: pw.BoxDecoration(
                  color: _surface,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  "当天暂无安排",
                  style: _textStyle(size: 10, color: _muted),
                ),
              ),
            );
          } else {
            widgets.addAll(items.map(_itemCard));
          }
        }
        return widgets;
      },
    ),
  );

  return doc.save();
}

/// 总览页（S12）：标题块 + 分块表格；页脚与内容页同风格。
pw.MultiPage _buildOverviewPage(
  String tripName,
  String? dateRange,
  List<List<OverviewRowData>> blocks,
) {
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(38, 42, 38, 40),
    footer: (ctx) => pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            "芥舟 · 旅行计划",
            style: _textStyle(size: 8, color: _muted),
          ),
        ),
        pw.Text(
          "第 ${ctx.pageNumber} 页",
          style: _textStyle(size: 8, color: _muted),
        ),
      ],
    ),
    build: (ctx) {
      final widgets = <pw.Widget>[];
      for (var b = 0; b < blocks.length; b++) {
        if (b > 0) widgets.add(pw.NewPage());
        widgets.add(_overviewBlock(
          tripName,
          dateRange,
          blocks[b],
          isFirst: b == 0,
        ));
      }
      return widgets;
    },
  );
}

/// 单个总览分块：首块带页首标题，其余直接表头起（每块自带表头行）。
pw.Widget _overviewBlock(
  String tripName,
  String? dateRange,
  List<OverviewRowData> rows, {
  required bool isFirst,
}) {
  final header = <pw.Widget>[];
  if (isFirst) {
    header.add(pw.Text(
      "行程总览",
      style: _textStyle(size: 21, weight: pw.FontWeight.bold),
    ));
    header.add(pw.SizedBox(height: 6));
    header.add(pw.Text(
      dateRange == null || dateRange.isEmpty
          ? tripName
          : "$tripName · $dateRange",
      style: _textStyle(size: 10, color: _muted),
    ));
    header.add(pw.SizedBox(height: 12));
  }
  // 表头行
  header.add(pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.8)),
    ),
    child: pw.Row(children: [
      _ovCell("DAY", 40, bold: true, muted: true),
      _ovCell("日期", 90, bold: true, muted: true),
      _ovCell("星期", 40, bold: true, muted: true),
      _ovCell("安排", 40, bold: true, muted: true),
      _ovCell("摘要", null, bold: true, muted: true),
    ]),
  ));
  // 数据行（行高约 18pt：垂直 padding 5 + 字号 10）
  for (final r in rows) {
    header.add(pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.3)),
      ),
      child: pw.Row(children: [
        _ovCell("D${r.dayIndex}", 40, mint: true),
        _ovCell(r.date, 90),
        _ovCell(r.weekday, 40, muted: true),
        _ovCell("${r.count}", 40, muted: true),
        _ovCell(r.summary.join("、"), null),
      ]),
    ));
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: header,
  );
}

/// 总览单元格：[width] 为 null 时横向展开（摘要列）。
/// pdf 包无 ellipsis 溢出模式——超长文本手动截断加「…」（规格 §15.2）。
pw.Widget _ovCell(
  String raw,
  double? width, {
  bool bold = false,
  bool muted = false,
  bool mint = false,
}) {
  final limit = width == null ? 28 : (width ~/ 9.5).clamp(2, 28).toInt();
  var text = raw;
  if (text.length > limit) {
    text = '${text.substring(0, (limit - 1).clamp(0, text.length))}…';
  }
  final style = _textStyle(
    size: 10,
    color: mint ? _mint : (muted ? _muted : _ink),
    weight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  final child = pw.Text(text, maxLines: 1, style: style);
  if (width == null) return pw.Expanded(child: child);
  return pw.SizedBox(width: width, child: child);
}
