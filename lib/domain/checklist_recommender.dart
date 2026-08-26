/// 清单智能模板库推荐引擎（纯函数）。
///
/// 打分规则：
/// * 目的地/行程名命中场景 tags：基础 +3，每额外命中一个关键词再 +1；
/// * 出行月份落在场景 months 内：+1；
/// * 行程天数 >= 场景 minDays（>0 时）：+1；
/// * 总分为 0 的场景不进推荐榜（UI 另列「全部模板」）。
/// 本文件纯 Dart 无 IO；日期换算复用 core/date_utils.dart。
library;

import '../core/date_utils.dart';
import '../data/seed/checklist_scenarios.dart';

/// 一条推荐结果
class TemplateMatch {
  const TemplateMatch({required this.template, required this.score, required this.reasons});

  final ScenarioTemplate template;
  final int score;

  /// 中文匹配理由（UI 直接展示，如「命中关键词：海、岛」）
  final List<String> reasons;
}

/// 为一次出行推荐场景模板，得分降序；同分按 key 字典序稳定排序。
List<TemplateMatch> recommendTemplates({
  required String destination,
  required String tripName,
  required int startEpochDay,
  required int endEpochDay,
  List<ScenarioTemplate> library = kScenarioTemplates,
}) {
  final month = epochDayToDate(startEpochDay).month;
  final days = tripDays(startEpochDay, endEpochDay);
  final hay = '$destination $tripName'.toLowerCase();
  final out = <TemplateMatch>[];
  for (final t in library) {
    var score = 0;
    final reasons = <String>[];
    if (t.tags.isNotEmpty) {
      final hits = [for (final tag in t.tags) if (hay.contains(tag.toLowerCase())) tag];
      if (hits.isNotEmpty) {
        score += 2 + hits.length; // 首个命中即 3 分起
        reasons.add('命中关键词：${hits.take(3).join('、')}${hits.length > 3 ? ' 等' : ''}');
      }
    }
    if (t.months.isNotEmpty && t.months.contains(month)) {
      score += 1;
      reasons.add('$month 月适玩');
    }
    if (t.minDays > 0 && days >= t.minDays) {
      score += 1;
      reasons.add('行程 $days 天适用');
    }
    if (score > 0) out.add(TemplateMatch(template: t, score: score, reasons: reasons));
  }
  out.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.template.key.compareTo(b.template.key);
  });
  return out;
}

/// 导入去重：跳过已存在（去首尾空白后精确相等）的条目文案。
List<String> filterExistingLabels(Iterable<String> existing, Iterable<String> labels) {
  final set = {for (final e in existing) e.trim()};
  return [for (final l in labels) if (!set.contains(l.trim())) l];
}
