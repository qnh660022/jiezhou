/// 目的地归一化（§7.14）：destination 字符串 → 城市 key。
/// 归一化链：清洗 → 区间取主名 → ①key 全等 → ②别名表 → ③前缀/包含 → ④city_coords.matchCity 兜底。
library;
import '../seed/city_coords.dart';

/// 内置别名表（≥20 条；§7.14）。
const Map<String, String> kGuideCityAliases = {
  '蓉城': 'chengdu',
  '锦官城': 'chengdu',
  'chengdu': 'chengdu',
  '春城': 'kunming',
  'kunming': 'kunming',
  '羊城': 'guangzhou',
  '花城': 'guangzhou',
  'guangzhou': 'guangzhou',
  '鹏城': 'shenzhen',
  'shenzhen': 'shenzhen',
  '申城': 'shanghai',
  'shanghai': 'shanghai',
  '山城': 'chongqing',
  '雾都': 'chongqing',
  'chongqing': 'chongqing',
  '江城': 'wuhan',
  'wuhan': 'wuhan',
  '鹭岛': 'xiamen',
  '鹭城': 'xiamen',
  'xiamen': 'xiamen',
  '冰城': 'harbin',
  'harbin': 'harbin',
  '椰城': 'haikou',
  '泉城': 'jinan',
  '瓷都': 'jingdezhen',
  '莫高窟': 'dunhuang',
  'dunhuang': 'dunhuang',
  'hangzhou': 'hangzhou',
  'beijing': 'beijing',
  'xian': 'xian',
  'guilin': 'guilin',
  'sanya': 'sanya',
  'tsingtao': 'qingdao',
  'amoy': 'xiamen',
  // 港澳台与新城市别名
  'hongkong': 'hongkong',
  'hong kong': 'hongkong',
  'macau': 'macau',
  'macao': 'macau',
  'taipei': 'taibei',
  'taiwan': 'taibei',
  '稻城亚丁': 'daocheng',
  '亚丁': 'daocheng',
  '香格里拉': 'shangrila',
  '版纳': 'xishuangbanna',
  '潮汕': 'chaozhou',
  '九寨': 'jiuzhaigou',
  '峨嵋': 'emeishan',
  '泰山': 'taian',
  '麦积山': 'tianshui',
  '北戴河': 'qinhuangdao',
  '山海关': 'qinhuangdao',
  '草原天路': 'zhangye',
  // 离线种子 2.0 新增城市别名（泉城→jinan、瓷都→jingdezhen 原已存在，
  // 此前因种子缺城而失效，2.0 补齐内容后自然生效）
  '星城': 'changsha',
  '榕城': 'fuzhou',
  '百载商埠': 'shantou',
  '禅城': 'foshan',
  '北国春城': 'changchun',
  '佛国': 'wutaishan',
  '冷极': 'mohe',
  '圣城': 'lasa',
  '汴梁': 'kaifeng',
  '汴京': 'kaifeng',
  '极边第一城': 'tengchong',
  '长安': 'xian',
};

class GuideLocation {
  const GuideLocation(this.key, this.name);
  final String key;
  final String name;
}

/// 城市展示名（种子内的 name 反查；未收录城市经 matchCity 兜底时用原始串）。
GuideLocation? normalizeGuideDestination(String destination,
    {Map<String, String>? seedNames}) {
  return normalizeGuideDestinations(destination, seedNames: seedNames,
      maxCities: 1).firstOrNull;
}

/// 多目的地归一化：按常见分隔符分段后逐段走归一化链，去重保序。
/// 「成都-稻城」→ [chengdu, daocheng]；全不识别 → 空列表。
List<GuideLocation> normalizeGuideDestinations(String destination,
    {Map<String, String>? seedNames, int maxCities = 5}) {
  final out = <GuideLocation>[];
  final seen = <String>{};
  for (final seg in destination.split(RegExp(r'[-—→~、，,/]|到'))) {
    final cleaned = _clean(seg);
    if (cleaned.isEmpty) continue;
    final loc = _matchSingle(cleaned, seedNames);
    if (loc == null || !seen.add(loc.key)) continue;
    out.add(loc);
    if (out.length >= maxCities) break;
  }
  return out;
}

/// 单段归一化链：①key 全等 → ②别名表 → ③前缀/包含 → ④matchCity 兜底。
GuideLocation? _matchSingle(String cleaned, Map<String, String>? seedNames) {
  final candidates = <String>[cleaned];
  final main = _splitRange(cleaned);
  if (main != null && main != cleaned) candidates.add(main);

  for (final cand in candidates) {
    // ① key 全等
    final key1 = cand.toLowerCase();
    if (_knownKeys.contains(key1)) {
      return GuideLocation(key1, _nameOf(key1, cand, seedNames));
    }
    // ② 别名表
    final alias = kGuideCityAliases[cand] ?? kGuideCityAliases[cand.toLowerCase()];
    if (alias != null && _knownKeys.contains(alias)) {
      return GuideLocation(alias, _nameOf(alias, cand, seedNames));
    }
    // ③ 前缀/包含匹配（城市中文名或别名是 destination 的连续子串）
    for (final entry in _knownCnNames.entries) {
      if (cand.contains(entry.value)) {
        return GuideLocation(entry.key, entry.value);
      }
    }
    for (final entry in kGuideCityAliases.entries) {
      final aliasKey = entry.key.toLowerCase();
      // 英文别名与中文别名（≥2 字）做子串匹配；跳过纯拼音 key 的误命中
      if (entry.key.length >= 2 && cand.contains(entry.key) ||
          cand.toLowerCase().contains(aliasKey) && aliasKey.length >= 5) {
        if (_knownKeys.contains(entry.value)) {
          return GuideLocation(entry.value, _nameOf(entry.value, cand, seedNames));
        }
      }
    }
  }
  // ④ city_coords.matchCity 兜底（离线库坐标匹配口径）
  for (final cand in candidates) {
    if (matchCity(cand) != null) {
      final hit = _knownCnNames.entries
          .where((e) => cand.contains(e.value))
          .map((e) => GuideLocation(e.key, e.value))
          .firstOrNull;
      if (hit != null) return hit;
      return GuideLocation(cand, cand); // 坐标命中但无攻略种子 → 以原串为 key（无种子即空态）
    }
  }
  return null;
}

String _nameOf(String key, String fallback, Map<String, String>? seedNames) =>
    seedNames?[key] ?? _knownCnNames[key] ?? fallback;

/// 清洗：trim、去括号及内容、去后缀词。
String _clean(String input) {
  var s = input.trim();
  s = s.replaceAll(RegExp(r'[（(【].*?[）)】]'), '');
  s = s.replaceAll(RegExp(r'(市区|城区|地区|附近|周边|县|市)$'), '');
  return s.trim();
}

/// 区间取主名：「A-B」「A到B」「A→B」取左侧 A（匹配失败即整体未匹配，不猜测）。
String? _splitRange(String s) {
  final m = RegExp(r'^(.+?)[-→]|^(.+?)到').firstMatch(s);
  if (m == null) return null;
  final left = (m.group(1) ?? m.group(2))?.trim();
  return (left == null || left.isEmpty) ? null : left;
}

/// 种子收录的城市 key 集合（与 guide_seed_v1.json 对齐；由 seed source 注入亦可，
/// 这里静态列出避免加载资源文件依赖，测试用 ensureSeedKeys 同步校验）。
const Set<String> _knownKeys = {
  'beijing', 'shanghai', 'guangzhou', 'shenzhen', 'chengdu', 'chongqing',
  'hangzhou', 'xian', 'nanjing', 'suzhou', 'wuhan', 'changsha', 'xiamen',
  'qingdao', 'dalian', 'harbin', 'sanya', 'lijiang', 'dali', 'guilin',
  'kunming', 'guiyang', 'lanzhou', 'urumqi', 'lasa', 'xining', 'yinchuan',
  'huihe', 'taiyuan', 'zhengzhou', 'hefei', 'nanchang', 'fuzhou', 'nanning',
  'zhuhai', 'tianjin', 'zhangjiajie', 'wuzhen', 'huangshan', 'weihai',
  'beihai', 'pingyao', 'dunhuang', 'luoyang', 'zhangjiajie_fenghuang',
  // v2 扩充（71 城）
  'hongkong', 'macau', 'taibei', 'chengde', 'datong', 'qinhuangdao',
  'yanji', 'shenyang', 'daocheng', 'jiuzhaigou', 'leshan', 'emeishan',
  'zhangye', 'turpan', 'tianshui', 'taian', 'wuxi', 'yangzhou', 'shaoxing',
  'ningbo', 'quanzhou', 'wuyuan', 'yichang', 'enshi', 'chaozhou', 'haikou',
  'anshun', 'xishuangbanna', 'shangrila',
  // 离线种子 2.0 扩充（85 城）：xian/wuhan/changsha 已在首段列出，此处不重复
  'jinan', 'jingdezhen', 'shantou', 'foshan',
  'changchun', 'changbaishan', 'wutaishan', 'hulunbuir', 'mohe', 'yanan',
  'kaifeng', 'tengchong',
};

const Map<String, String> _knownCnNames = {
  'beijing': '北京', 'shanghai': '上海', 'guangzhou': '广州', 'shenzhen': '深圳',
  'chengdu': '成都', 'chongqing': '重庆', 'hangzhou': '杭州', 'xian': '西安',
  'nanjing': '南京', 'suzhou': '苏州', 'wuhan': '武汉', 'changsha': '长沙',
  'xiamen': '厦门', 'qingdao': '青岛', 'dalian': '大连', 'harbin': '哈尔滨',
  'sanya': '三亚', 'lijiang': '丽江', 'dali': '大理', 'guilin': '桂林',
  'kunming': '昆明', 'guiyang': '贵阳', 'lanzhou': '兰州', 'urumqi': '乌鲁木齐',
  'lasa': '拉萨', 'xining': '西宁', 'yinchuan': '银川', 'huihe': '呼和浩特',
  'taiyuan': '太原', 'zhengzhou': '郑州', 'hefei': '合肥', 'nanchang': '南昌',
  'fuzhou': '福州', 'nanning': '南宁', 'zhuhai': '珠海', 'tianjin': '天津',
  'zhangjiajie': '张家界', 'wuzhen': '乌镇', 'huangshan': '黄山',
  'weihai': '威海', 'beihai': '北海', 'pingyao': '平遥', 'dunhuang': '敦煌',
  'luoyang': '洛阳',
  'zhangjiajie_fenghuang': '凤凰',
  // v2 扩充（71 城）
  'hongkong': '香港', 'macau': '澳门', 'taibei': '台北', 'chengde': '承德',
  'datong': '大同', 'qinhuangdao': '秦皇岛', 'yanji': '延吉',
  'shenyang': '沈阳', 'daocheng': '稻城', 'jiuzhaigou': '九寨沟',
  'leshan': '乐山', 'emeishan': '峨眉山', 'zhangye': '张掖',
  'turpan': '吐鲁番', 'tianshui': '天水', 'taian': '泰安', 'wuxi': '无锡',
  'yangzhou': '扬州', 'shaoxing': '绍兴', 'ningbo': '宁波',
  'quanzhou': '泉州', 'wuyuan': '婺源', 'yichang': '宜昌', 'enshi': '恩施',
  'chaozhou': '潮州', 'haikou': '海口', 'anshun': '安顺',
  'xishuangbanna': '西双版纳', 'shangrila': '香格里拉',
  // 离线种子 2.0 扩充（85 城）：xian/wuhan/changsha 已在首段列出，此处不重复
  'jinan': '济南',
  'jingdezhen': '景德镇', 'shantou': '汕头', 'foshan': '佛山',
  'changchun': '长春', 'changbaishan': '长白山', 'wutaishan': '五台山',
  'hulunbuir': '呼伦贝尔', 'mohe': '漠河', 'yanan': '延安',
  'kaifeng': '开封', 'tengchong': '腾冲',
};
