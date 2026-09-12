/// App 内 AI 生成攻略的「草稿」存储（§AI 攻略导入）。
///
/// 一次生成分多轮工具调用（受模型单次输出上限约束，不可能一次吐出 6000 字），
/// 所以草稿要跨工具调用、跨轮次保存：先 [GuideAiDraft.start]，逐栏
/// [GuideAiDraft.putSection]，最后 [GuideAiDraft.load] 出完整城市对象给确认卡。
///
/// 存放位置：`SharedPreferences`（key `guide_ai_draft_<cityKey>`）。
/// 攻略内容本身仍然本地、不上云（与 §7.1「纯本地不云端」一致）。
library;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'guide_content_filter.dart';
import 'guide_models.dart';

/// 六栏 -> 每栏必须的字段与最少条数（导入前的品控线）。
const Map<String, ({List<String> fields, int minItems})> kGuideSectionSpec = {
  'prep': (fields: ['title', 'detail'], minItems: 3),
  'spots': (fields: ['name', 'addr', 'tag', 'timeText', 'note'], minItems: 5),
  'food': (fields: ['name', 'area', 'note'], minItems: 4),
  'transport': (fields: ['mode', 'line', 'note'], minItems: 3),
  'tips': (fields: ['title', 'detail'], minItems: 3),
  'budget': (fields: ['item', 'rangeText'], minItems: 3),
};

/// 正文汉字数下限（低于此值判定「还不足以成为攻略」）。
const int kGuideMinChars = 3000;

class GuideAiDraft {
  GuideAiDraft({
    required this.cityKey,
    required this.cityName,
    this.area = '',
    Map<String, List<Map<String, dynamic>>>? sections,
  }) : sections = sections ?? {
          for (final k in GuideCity.sectionKeys) k: <Map<String, dynamic>>[],
        };

  final String cityKey;
  final String cityName;
  final String area;
  final Map<String, List<Map<String, dynamic>>> sections;

  static String _prefsKey(String cityKey) => 'guide_ai_draft_$cityKey';

  static Map<String, dynamic> _sanitize(Map<String, dynamic> item) {
    // 只保留契约字段，且值一律转字符串（模型偶尔给数字/布尔）
    final out = <String, dynamic>{};
    for (final e in item.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) out[e.key] = t;
      } else if (v is num || v is bool) {
        out[e.key] = v.toString();
      }
    }
    return out;
  }

  /// 新建/覆盖草稿（AI 每次开始一城生成时调用）。
  static Future<GuideAiDraft> start({
    required String cityKey,
    required String cityName,
    String area = '',
  }) async {
    final draft = GuideAiDraft(
        cityKey: cityKey, cityName: cityName, area: area);
    await draft.save();
    return draft;
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _prefsKey(cityKey),
      jsonEncode({
        'key': cityKey,
        'name': cityName,
        'area': area,
        'sections': sections,
      }),
    );
  }

  /// 读草稿；不存在返回 null。
  static Future<GuideAiDraft?> load(String cityKey) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_prefsKey(cityKey));
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final secs = <String, List<Map<String, dynamic>>>{};
      final rawSecs = (m['sections'] as Map?) ?? {};
      for (final k in GuideCity.sectionKeys) {
        secs[k] = [
          for (final it in (rawSecs[k] as List?) ?? const [])
            if (it is Map) _sanitize(it.cast<String, dynamic>()),
        ];
      }
      return GuideAiDraft(
        cityKey: m['key'] as String? ?? cityKey,
        cityName: m['name'] as String? ?? cityKey,
        area: m['area'] as String? ?? '',
        sections: secs,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String cityKey) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_prefsKey(cityKey));
  }

  /// 写入/追加一栏的条目，返回该栏现有条数。
  ///
  /// 追加而不是覆盖：模型分多次补齐同一栏时不会互相吃掉内容。
  int putSection(String sectionKey, List<dynamic> items) {
    if (!GuideCity.sectionKeys.contains(sectionKey)) return -1;
    final list = sections[sectionKey]!;
    for (final it in items) {
      if (it is! Map) continue;
      final clean = _sanitize(it.cast<String, dynamic>());
      if (clean.isEmpty) continue;
      // 同栏同名条目去重（模型常常重复输出）
      final name = (clean['name'] ?? clean['title'] ?? clean['item'] ?? '')
          .toString();
      final idx = list.indexWhere((e) =>
          (e['name'] ?? e['title'] ?? e['item'] ?? '').toString() == name);
      if (idx >= 0) {
        list[idx] = clean;
      } else {
        list.add(clean);
      }
    }
    return list.length;
  }

  int get textChars => GuideCity.textCharCount(null, sections);

  int get itemCount =>
      sections.values.fold<int>(0, (n, l) => n + l.length);

  /// 距离「可导入」还差什么；全通过返回空列表。
  ///
  /// 只做**下限**校验（不强制达到 5500 字——AI 生成场景下，用户看到提示后
  /// 可以选择继续补写或直接导入，不该被硬门槛卡死）。
  List<String> gaps() {
    final out = <String>[];
    for (final k in GuideCity.sectionKeys) {
      final spec = kGuideSectionSpec[k]!;
      final list = (sections[k] ?? const []).cast<Map<String, dynamic>>();
      if (list.length < spec.minItems) {
        out.add('${GuideCity.sectionLabels[k]}还缺 ${spec.minItems - list.length} 条');
        continue;
      }
      // 字段完整性：只抽查「名称类字段是否有中文」——说明字段允许留空
      //（预算栏的区间文本、交通栏的说明都可能较短），不当硬门槛。
      final nameField = switch (k) {
        'spots' || 'food' => 'name',
        'transport' => 'mode',
        'budget' => 'item',
        _ => 'title',
      };
      final named = list
          .where((e) => hasCjk(e[nameField]?.toString(), min: 1))
          .length;
      if (named == 0) out.add('${GuideCity.sectionLabels[k]}缺少条目名');
    }
    if (textChars < kGuideMinChars) {
      out.add('正文仅 $textChars 字（建议 5500 字以上，约 15 分钟阅读）');
    }
    return out;
  }

  /// 转成种子契约的城对象（供 `GuideCity.validate` 与落盘）。
  Map<String, dynamic> toCityJson() => {
        'key': cityKey,
        'name': cityName,
        if (area.isNotEmpty) 'area': area,
        'sections': sections,
      };

  /// 确认卡展示用的摘要行（栏名 / 条数 / 汉字数）。
  List<List<String>> summaryRows() => [
        for (final k in GuideCity.sectionKeys)
          [
            GuideCity.sectionLabels[k]!,
            '${(sections[k] ?? const []).length} 条 · '
                '${GuideCity.textCharCount(null, {k: sections[k]})} 字',
          ],
        ['正文合计', '$textChars 字 · 约 ${GuideCity.readingMinutes(textChars)} 分钟'],
      ];
}
