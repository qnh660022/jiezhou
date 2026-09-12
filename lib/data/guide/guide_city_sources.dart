/// 去哪儿攻略「城市 key → 城市 ID」映射 + 城市名校验表（生成物，勿手改）。
///
/// 生成命令：`node scripts/gen_guide_city_sources.mjs`
///
/// 只收录**逐城抓页面用 <h1> 校验过**的城市：去哪儿 URL 里 ID 才是权威，ID 与 slug
/// 不匹配时会静默返回另一个城市的正文（HTTP 仍是 200）。所以抓取层拿到正文后必须
/// 再用 [kQunarCityNames] 复核一次，对不上就丢弃、只用内置种子。
///
/// 表内没有的城市 → 抓取层直接跳过在线层，**不猜 URL、不猜 ID**。
library;

/// cityKey(`assets/data/guide_seed_v1.json` 的 key) → 去哪儿城市 ID。
const Map<String, int> kQunarCityIds = {
  'anshun': 299852, // 安顺
  'beihai': 299789, // 北海
  'beijing': 299914, // 北京
  'changsha': 300022, // 长沙
  'chaozhou': 299787, // 潮州
  'chengde': 300082, // 承德
  'chengdu': 300085, // 成都
  'chongqing': 299979, // 重庆
  'dali': 300090, // 大理
  'dalian': 300134, // 大连
  'foshan': 300129, // 佛山
  'fuzhou': 299826, // 福州
  'guangzhou': 300132, // 广州
  'guilin': 299801, // 桂林
  'guiyang': 299856, // 贵阳
  'haikou': 300148, // 海口
  'hangzhou': 300195, // 杭州
  'hongkong': 300027, // 香港
  'jinan': 300150, // 济南
  'kunming': 300088, // 昆明
  'leshan': 299892, // 乐山
  'lijiang': 300079, // 丽江
  'macau': 300028, // 澳门
  'nanjing': 299861, // 南京
  'nanning': 299812, // 南宁
  'ningbo': 300194, // 宁波
  'qingdao': 299783, // 青岛
  'qinhuangdao': 300113, // 秦皇岛
  'quanzhou': 299779, // 泉州
  'sanya': 300188, // 三亚
  'shanghai': 299878, // 上海
  'shantou': 300096, // 汕头
  'shaoxing': 300181, // 绍兴
  'shenzhen': 300118, // 深圳
  'suzhou': 299937, // 苏州
  'taian': 300151, // 泰安
  'taibei': 300002, // 台北
  'tianjin': 299957, // 天津
  'weihai': 300115, // 威海
  'wuxi': 299940, // 无锡
  'xiamen': 299782, // 厦门
  'xian': 300100, // 西安
  'xishuangbanna': 299808, // 西双版纳
  'yanan': 300083, // 延安
  'yangzhou': 299941, // 扬州
  'zhangjiajie': 300064, // 张家界
  'zhuhai': 299799, // 珠海
};

/// cityKey → 期望的城市中文名（运行时复核抓回来的页面是不是这座城）。
const Map<String, String> kQunarCityNames = {
  'anshun': '安顺',
  'beihai': '北海',
  'beijing': '北京',
  'changsha': '长沙',
  'chaozhou': '潮州',
  'chengde': '承德',
  'chengdu': '成都',
  'chongqing': '重庆',
  'dali': '大理',
  'dalian': '大连',
  'foshan': '佛山',
  'fuzhou': '福州',
  'guangzhou': '广州',
  'guilin': '桂林',
  'guiyang': '贵阳',
  'haikou': '海口',
  'hangzhou': '杭州',
  'hongkong': '香港',
  'jinan': '济南',
  'kunming': '昆明',
  'leshan': '乐山',
  'lijiang': '丽江',
  'macau': '澳门',
  'nanjing': '南京',
  'nanning': '南宁',
  'ningbo': '宁波',
  'qingdao': '青岛',
  'qinhuangdao': '秦皇岛',
  'quanzhou': '泉州',
  'sanya': '三亚',
  'shanghai': '上海',
  'shantou': '汕头',
  'shaoxing': '绍兴',
  'shenzhen': '深圳',
  'suzhou': '苏州',
  'taian': '泰安',
  'taibei': '台北',
  'tianjin': '天津',
  'weihai': '威海',
  'wuxi': '无锡',
  'xiamen': '厦门',
  'xian': '西安',
  'xishuangbanna': '西双版纳',
  'yanan': '延安',
  'yangzhou': '扬州',
  'zhangjiajie': '张家界',
  'zhuhai': '珠海',
};

/// 已收录城市数（测试断言用）。
int get qunarCityCount => kQunarCityIds.length;
