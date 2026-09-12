/// 在线层内容过滤（用户需求 2026-09：「获取的只是地点，不是攻略，而且全是外国的」）。
///
/// 在线层唯一的准入标准：**中文正文**。任何条目在并入 seeds 之前都要过一遍
/// [hasCjk]；不通过即丢弃，绝不让外文地名/POI 混进攻略的六栏。
library;

/// 正文里至少要有这么多个汉字才算「中文内容」。
const int kMinCjkChars = 6;

/// 是否含足量汉字（≥[min] 个 `[\u4e00-\u9fff]`）。
///
/// 用「数量」而不是「出现过汉字」作为判据：外文条目里偶尔混一个汉字
/// （如 `Tokyo 东京塔`）不该被当成中文内容。
bool hasCjk(String? s, {int min = kMinCjkChars}) {
  if (s == null || s.isEmpty) return false;
  var n = 0;
  for (final unit in s.codeUnits) {
    if (unit >= 0x4e00 && unit <= 0x9fff) {
      n++;
      if (n >= min) return true;
    }
  }
  return false;
}

/// 汉字数量（用于种子/导入内容的阅读时长估算与校验）。
int cjkCount(String? s) {
  if (s == null || s.isEmpty) return 0;
  var n = 0;
  for (final unit in s.codeUnits) {
    if (unit >= 0x4e00 && unit <= 0x9fff) n++;
  }
  return n;
}

/// 单条在线条目是否有中文可供展示：标题/名称 + 说明里任意一处达标即通过。
///
/// [fields] 按优先级给（如 `['name', 'title', 'note', 'detail', 'addr']`）。
bool entryLooksChinese(Map<String, dynamic> item, List<String> fields) {
  for (final f in fields) {
    if (hasCjk(item[f]?.toString())) return true;
  }
  return false;
}

/// 公告/导航类噪音行（去哪儿城市页里夹带的站点导航、备案信息等）。
///
/// 命中即整行丢弃，避免「登录/注册/我的空间」这类导航被当成攻略内容。
///
/// ⚠️ 这份清单**只放不会出现在正文里的整词**：早前把「一日游」「旅游包车」
/// 等短词也列进来，结果「西湖游船」这种正常景点名被误杀。宁可漏掉个别导航行，
/// 也不能吃掉真实内容。
const List<String> kGuideNoiseMarks = [
  // 页面顶部/底部的功能导航
  '登录', '注册', '我的空间', '我的行程', '我的游记', '我的收藏', '查看订单',
  '联系客服', '攻略首页', '攻略库', '创建行程', '发表游记', '创作者平台',
  '境内门票', '品质一日游', '地图找景点', '度假团购', '周边休闲', '长线游',
  '当地人首页', '出境WiFi', '旅游包车',
  '国内租车', '境外租车', '国际接送机', '热门搜索', '历史记录',
  // 页面内区块标题（分区导航，不是正文）
  '热门城市', '热门景点', '目的地分类导航', '周边推荐',
  // 合规/版权声明
  '京ICP', '京公网安备', '营业执照', '互联网药品信息服务资格证',
  '合作机构', '友情链接', '关于我们', '联系我们', '用户协议', '常见问题',
  '意见反馈', '加入我们', '业务合作', '安全中心', 'Copyright', 'All Rights',
  '版权所有', '违法和不良信息', '旅游投诉', '举报电话', '举报邮箱',
  // 其他站点级字样
  '下载APP', '扫码下载', '返回顶部', '上一页', '下一页', '清除', '当前城市',
];

/// 该行是否站点导航/合规声明类噪音（长度守卫：长句默认视为正文）。
bool isGuideNoise(String line) {
  final s = line.trim();
  if (s.isEmpty) return true;
  if (s.length > 60) return false; // 长句不像导航
  for (final m in kGuideNoiseMarks) {
    if (s.contains(m)) return true;
  }
  return false;
}
