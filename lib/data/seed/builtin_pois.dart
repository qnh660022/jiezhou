// 数据来源: D:\AI\money\utils\poi.js · 条数 94
// 由 travel-assistant-v2/integrator 从旧版小程序数据层迁移生成；纯常量，无任何第三方/flutter 依赖。
// 内置热门地点库（HOT_POIS 全量搬运）：名称/城市/地址/坐标/图标/维基词条。

/// 内置热门地点（离线推荐库，覆盖国内外热门城市）。
class BuiltinPoi {
  final String name;

  /// 所属城市
  final String city;

  /// 详细地址
  final String address;

  /// 展示图标（emoji）
  final String icon;

  /// 中文维基百科词条标题（用于拉取配图）
  final String wikiTitle;

  /// 纬度
  final double lat;

  /// 经度
  final double lng;

  const BuiltinPoi({
    required this.name,
    required this.city,
    required this.address,
    required this.icon,
    required this.wikiTitle,
    required this.lat,
    required this.lng,
  });
}

/// 内置热门地点全集（与旧版 utils/poi.js 的 HOT_POIS 一一对应）。
const List<BuiltinPoi> kBuiltinPois = [
  BuiltinPoi(name: '故宫博物院', city: '北京', address: '北京市东城区景山前街4号', icon: '🏯', wikiTitle: '故宫', lat: 39.9163, lng: 116.3972),
  BuiltinPoi(name: '天安门广场', city: '北京', address: '北京市东城区长安街', icon: '🏛️', wikiTitle: '天安门广场', lat: 39.9055, lng: 116.3976),
  BuiltinPoi(name: '颐和园', city: '北京', address: '北京市海淀区新建宫门路19号', icon: '🏞️', wikiTitle: '颐和园', lat: 39.9999, lng: 116.2755),
  BuiltinPoi(name: '八达岭长城', city: '北京', address: '北京市延庆区G6京藏高速58号出口', icon: '🧱', wikiTitle: '八达岭长城', lat: 40.3594, lng: 116.0181),
  BuiltinPoi(name: '天坛公园', city: '北京', address: '北京市东城区天坛东里甲1号', icon: '⛩️', wikiTitle: '天坛', lat: 39.8822, lng: 116.4066),
  BuiltinPoi(name: '外滩', city: '上海', address: '上海市黄浦区中山东一路', icon: '🌃', wikiTitle: '外滩', lat: 31.2397, lng: 121.4903),
  BuiltinPoi(name: '东方明珠广播电视塔', city: '上海', address: '上海市浦东新区世纪大道1号', icon: '🗼', wikiTitle: '东方明珠广播电视塔', lat: 31.2397, lng: 121.4998),
  BuiltinPoi(name: '豫园', city: '上海', address: '上海市黄浦区福佑路168号', icon: '🏯', wikiTitle: '豫园', lat: 31.2273, lng: 121.4930),
  BuiltinPoi(name: '上海迪士尼度假区', city: '上海', address: '上海市浦东新区川沙新镇黄赵路310号', icon: '🎢', wikiTitle: '上海迪士尼度假区', lat: 31.1434, lng: 121.6573),
  BuiltinPoi(name: '武康路历史文化名街', city: '上海', address: '上海市徐汇区武康路', icon: '🏘️', wikiTitle: '武康路', lat: 31.2056, lng: 121.4389),
  BuiltinPoi(name: '广州塔', city: '广州', address: '广州市海珠区阅江西路222号', icon: '🗼', wikiTitle: '广州塔', lat: 23.1066, lng: 113.3245),
  BuiltinPoi(name: '沙面岛', city: '广州', address: '广州市荔湾区沙面大街', icon: '🏛️', wikiTitle: '沙面', lat: 23.1096, lng: 113.2394),
  BuiltinPoi(name: '陈家祠', city: '广州', address: '广州市荔湾区中山七路恩龙里34号', icon: '🏯', wikiTitle: '陈家祠', lat: 23.1291, lng: 113.2447),
  BuiltinPoi(name: '白云山风景名胜区', city: '广州', address: '广州市白云区广园中路801号', icon: '⛰️', wikiTitle: '白云山', lat: 23.1854, lng: 113.2918),
  BuiltinPoi(name: '世界之窗', city: '深圳', address: '深圳市南山区深南大道9037号', icon: '🌍', wikiTitle: '世界之窗', lat: 22.5364, lng: 113.9707),
  BuiltinPoi(name: '深圳湾公园', city: '深圳', address: '深圳市南山区滨海大道', icon: '🌊', wikiTitle: '深圳湾公园', lat: 22.5246, lng: 113.9529),
  BuiltinPoi(name: '大梅沙海滨公园', city: '深圳', address: '深圳市盐田区盐梅路', icon: '🏖️', wikiTitle: '大梅沙', lat: 22.5936, lng: 114.3034),
  BuiltinPoi(name: '华侨城创意文化园', city: '深圳', address: '深圳市南山区锦绣北街2号', icon: '🎨', wikiTitle: '华侨城创意文化园', lat: 22.5390, lng: 113.9950),
  BuiltinPoi(name: '宽窄巷子', city: '成都', address: '成都市青羊区金河路口', icon: '🏘️', wikiTitle: '宽窄巷子', lat: 30.6691, lng: 104.0605),
  BuiltinPoi(name: '锦里古街', city: '成都', address: '成都市武侯区武侯祠大街231号', icon: '🏮', wikiTitle: '锦里', lat: 30.6465, lng: 104.0488),
  BuiltinPoi(name: '成都大熊猫繁育研究基地', city: '成都', address: '成都市成华区熊猫大道1375号', icon: '🐼', wikiTitle: '成都大熊猫繁育研究基地', lat: 30.7355, lng: 104.1484),
  BuiltinPoi(name: '都江堰景区', city: '成都', address: '成都市都江堰市公园路', icon: '🌊', wikiTitle: '都江堰', lat: 31.0045, lng: 103.6195),
  BuiltinPoi(name: '西湖风景名胜区', city: '杭州', address: '杭州市西湖区龙井路1号', icon: '🏞️', wikiTitle: '西湖', lat: 30.2458, lng: 120.1527),
  BuiltinPoi(name: '灵隐寺', city: '杭州', address: '杭州市西湖区法云弄1号', icon: '⛩️', wikiTitle: '灵隐寺', lat: 30.2403, lng: 120.1018),
  BuiltinPoi(name: '西溪国家湿地公园', city: '杭州', address: '杭州市西湖区天目山路518号', icon: '🌿', wikiTitle: '西溪湿地', lat: 30.2688, lng: 120.0623),
  BuiltinPoi(name: '河坊街', city: '杭州', address: '杭州市上城区河坊街', icon: '🏘️', wikiTitle: '河坊街', lat: 30.2400, lng: 120.1710),
  BuiltinPoi(name: '秦始皇兵马俑博物馆', city: '西安', address: '西安市临潼区秦陵北路', icon: '🏺', wikiTitle: '秦始皇兵马俑', lat: 34.3841, lng: 109.2785),
  BuiltinPoi(name: '西安城墙', city: '西安', address: '西安市碑林区南大街2号', icon: '🧱', wikiTitle: '西安城墙', lat: 34.2545, lng: 108.9420),
  BuiltinPoi(name: '大雁塔', city: '西安', address: '西安市雁塔区雁塔南路', icon: '🗼', wikiTitle: '大雁塔', lat: 34.2184, lng: 108.9642),
  BuiltinPoi(name: '回民街', city: '西安', address: '西安市莲湖区北院门', icon: '🍜', wikiTitle: '回民街', lat: 34.2637, lng: 108.9378),
  BuiltinPoi(name: '洪崖洞民俗风貌区', city: '重庆', address: '重庆市渝中区嘉陵江滨江路88号', icon: '🏮', wikiTitle: '洪崖洞', lat: 29.5628, lng: 106.5781),
  BuiltinPoi(name: '磁器口古镇', city: '重庆', address: '重庆市沙坪坝区磁南街1号', icon: '🏘️', wikiTitle: '磁器口', lat: 29.5820, lng: 106.4505),
  BuiltinPoi(name: '长江索道', city: '重庆', address: '重庆市渝中区新华路151号', icon: '🚡', wikiTitle: '长江索道', lat: 29.5602, lng: 106.5887),
  BuiltinPoi(name: '武隆天生三桥', city: '重庆', address: '重庆市武隆区仙女山镇', icon: '⛰️', wikiTitle: '天生三桥', lat: 29.3946, lng: 107.8544),
  BuiltinPoi(name: '鼓浪屿', city: '厦门', address: '厦门市思明区鼓浪屿', icon: '🏖️', wikiTitle: '鼓浪屿', lat: 24.4471, lng: 118.0667),
  BuiltinPoi(name: '厦门大学', city: '厦门', address: '厦门市思明区思明南路422号', icon: '🏫', wikiTitle: '厦门大学', lat: 24.4364, lng: 118.1000),
  BuiltinPoi(name: '环岛路', city: '厦门', address: '厦门市思明区环岛南路', icon: '🛣️', wikiTitle: '环岛路', lat: 24.4451, lng: 118.1567),
  BuiltinPoi(name: '曾厝垵', city: '厦门', address: '厦门市思明区环岛南路', icon: '🏘️', wikiTitle: '曾厝垵', lat: 24.4272, lng: 118.1114),
  BuiltinPoi(name: '中山陵', city: '南京', address: '南京市玄武区石象路7号', icon: '⛩️', wikiTitle: '中山陵', lat: 32.0639, lng: 118.8520),
  BuiltinPoi(name: '夫子庙秦淮风光带', city: '南京', address: '南京市秦淮区贡院街', icon: '🏮', wikiTitle: '夫子庙', lat: 32.0230, lng: 118.7880),
  BuiltinPoi(name: '南京博物院', city: '南京', address: '南京市玄武区中山东路321号', icon: '🏛️', wikiTitle: '南京博物院', lat: 32.0409, lng: 118.8245),
  BuiltinPoi(name: '明孝陵', city: '南京', address: '南京市玄武区紫金山南麓', icon: '🪦', wikiTitle: '明孝陵', lat: 32.0639, lng: 118.8440),
  BuiltinPoi(name: '黄鹤楼', city: '武汉', address: '武汉市武昌区蛇山西山坡特1号', icon: '🗼', wikiTitle: '黄鹤楼', lat: 30.5475, lng: 114.3008),
  BuiltinPoi(name: '武汉大学', city: '武汉', address: '武汉市武昌区珞珈山', icon: '🏫', wikiTitle: '武汉大学', lat: 30.5380, lng: 114.3610),
  BuiltinPoi(name: '东湖生态旅游风景区', city: '武汉', address: '武汉市武昌区沿湖大道16号', icon: '🌊', wikiTitle: '东湖', lat: 30.5525, lng: 114.4167),
  BuiltinPoi(name: '户部巷', city: '武汉', address: '武汉市武昌区自由路', icon: '🍜', wikiTitle: '户部巷', lat: 30.5528, lng: 114.3073),
  BuiltinPoi(name: '橘子洲', city: '长沙', address: '长沙市岳麓区橘子洲头', icon: '🏝️', wikiTitle: '橘子洲', lat: 28.1957, lng: 112.9584),
  BuiltinPoi(name: '岳麓山', city: '长沙', address: '长沙市岳麓区登高路58号', icon: '⛰️', wikiTitle: '岳麓山', lat: 28.1827, lng: 112.9320),
  BuiltinPoi(name: '湖南博物院', city: '长沙', address: '长沙市开福区东风路50号', icon: '🏛️', wikiTitle: '湖南博物院', lat: 28.2100, lng: 112.9870),
  BuiltinPoi(name: '太平老街', city: '长沙', address: '长沙市天心区太平街', icon: '🏘️', wikiTitle: '太平街', lat: 28.1950, lng: 112.9700),
  BuiltinPoi(name: '拙政园', city: '苏州', address: '苏州市姑苏区东北街178号', icon: '🌿', wikiTitle: '拙政园', lat: 31.3245, lng: 120.6254),
  BuiltinPoi(name: '平江路历史街区', city: '苏州', address: '苏州市姑苏区平江路', icon: '🏘️', wikiTitle: '平江路', lat: 31.3170, lng: 120.6310),
  BuiltinPoi(name: '苏州博物馆', city: '苏州', address: '苏州市姑苏区东北街204号', icon: '🏛️', wikiTitle: '苏州博物馆', lat: 31.3253, lng: 120.6254),
  BuiltinPoi(name: '虎丘山风景名胜区', city: '苏州', address: '苏州市姑苏区虎丘山门内8号', icon: '⛰️', wikiTitle: '虎丘', lat: 31.3360, lng: 120.5830),
  BuiltinPoi(name: '栈桥', city: '青岛', address: '青岛市市南区太平路12号', icon: '🌉', wikiTitle: '栈桥', lat: 36.0635, lng: 120.3165),
  BuiltinPoi(name: '八大关', city: '青岛', address: '青岛市市南区武胜关支路10号', icon: '🏘️', wikiTitle: '八大关', lat: 36.0550, lng: 120.3480),
  BuiltinPoi(name: '崂山风景区', city: '青岛', address: '青岛市崂山区崂山路', icon: '⛰️', wikiTitle: '崂山', lat: 36.1645, lng: 120.6390),
  BuiltinPoi(name: '青岛啤酒博物馆', city: '青岛', address: '青岛市市北区登州路56号', icon: '🍺', wikiTitle: '青岛啤酒博物馆', lat: 36.0850, lng: 120.3560),
  BuiltinPoi(name: '洱海', city: '大理', address: '大理白族自治州大理市', icon: '🌊', wikiTitle: '洱海', lat: 25.7380, lng: 100.1880),
  BuiltinPoi(name: '大理古城', city: '大理', address: '大理白族自治州大理市复兴路', icon: '🏯', wikiTitle: '大理古城', lat: 25.6910, lng: 100.1620),
  BuiltinPoi(name: '苍山', city: '大理', address: '大理白族自治州大理市', icon: '⛰️', wikiTitle: '苍山', lat: 25.6530, lng: 100.1060),
  BuiltinPoi(name: '崇圣寺三塔', city: '大理', address: '大理白族自治州大理市三塔路', icon: '🗼', wikiTitle: '崇圣寺三塔', lat: 25.7040, lng: 100.1480),
  BuiltinPoi(name: '丽江古城', city: '丽江', address: '丽江市古城区大研镇', icon: '🏘️', wikiTitle: '丽江古城', lat: 26.8721, lng: 100.2340),
  BuiltinPoi(name: '玉龙雪山', city: '丽江', address: '丽江市玉龙纳西族自治县', icon: '🏔️', wikiTitle: '玉龙雪山', lat: 27.0975, lng: 100.1750),
  BuiltinPoi(name: '蓝月谷', city: '丽江', address: '丽江市玉龙纳西族自治县', icon: '💙', wikiTitle: '蓝月谷', lat: 27.0230, lng: 100.2110),
  BuiltinPoi(name: '束河古镇', city: '丽江', address: '丽江市古城区束河路', icon: '🏯', wikiTitle: '束河古镇', lat: 26.9160, lng: 100.2020),
  BuiltinPoi(name: '亚龙湾', city: '三亚', address: '三亚市吉阳区亚龙湾路', icon: '🏖️', wikiTitle: '亚龙湾', lat: 18.2100, lng: 109.6540),
  BuiltinPoi(name: '蜈支洲岛', city: '三亚', address: '三亚市海棠区', icon: '🏝️', wikiTitle: '蜈支洲岛', lat: 18.3120, lng: 109.7700),
  BuiltinPoi(name: '天涯海角游览区', city: '三亚', address: '三亚市天涯区天涯镇', icon: '🌴', wikiTitle: '天涯海角', lat: 18.2910, lng: 109.3500),
  BuiltinPoi(name: '南山文化旅游区', city: '三亚', address: '三亚市崖州区南山文化旅游区', icon: '🙏', wikiTitle: '南山文化旅游区', lat: 18.2980, lng: 109.1750),
  BuiltinPoi(name: '香港迪士尼乐园', city: '香港', address: '香港大屿山竹篙湾', icon: '🎢', wikiTitle: '香港迪士尼乐园', lat: 22.3135, lng: 114.0415),
  BuiltinPoi(name: '维多利亚港', city: '香港', address: '香港九龙半岛与香港岛之间', icon: '🌃', wikiTitle: '维多利亚港', lat: 22.2930, lng: 114.1710),
  BuiltinPoi(name: '太平山顶', city: '香港', address: '香港山顶道', icon: '⛰️', wikiTitle: '太平山', lat: 22.2765, lng: 114.1480),
  BuiltinPoi(name: '大三巴牌坊', city: '澳门', address: '澳门半岛大三巴街', icon: '⛪', wikiTitle: '大三巴牌坊', lat: 22.1974, lng: 113.5410),
  BuiltinPoi(name: '澳门威尼斯人度假村', city: '澳门', address: '澳门路氹金光大道', icon: '🎰', wikiTitle: '威尼斯人(澳门)', lat: 22.1478, lng: 113.5600),
  BuiltinPoi(name: '台北101', city: '台北', address: '台北市信义区信义路五段7号', icon: '🗼', wikiTitle: '台北101', lat: 25.0330, lng: 121.5645),
  BuiltinPoi(name: '西门町', city: '台北', address: '台北市万华区', icon: '🏮', wikiTitle: '西门町', lat: 25.0458, lng: 121.5070),
  BuiltinPoi(name: '九份老街', city: '台北', address: '新北市瑞芳区基山街', icon: '🏘️', wikiTitle: '九份', lat: 25.1090, lng: 121.8430),
  BuiltinPoi(name: '日月潭', city: '台北', address: '南投县鱼池乡', icon: '🏞️', wikiTitle: '日月潭', lat: 23.8660, lng: 120.9200),
  BuiltinPoi(name: '东京塔', city: '东京', address: '东京都港区芝公园4-2-8', icon: '🗼', wikiTitle: '东京铁塔', lat: 35.6586, lng: 139.7454),
  BuiltinPoi(name: '浅草寺', city: '东京', address: '东京都台东区浅草2-3-1', icon: '⛩️', wikiTitle: '浅草寺', lat: 35.7148, lng: 139.7967),
  BuiltinPoi(name: '富士山', city: '东京', address: '静冈县与山梨县交界', icon: '🏔️', wikiTitle: '富士山', lat: 35.3606, lng: 138.7274),
  BuiltinPoi(name: '埃菲尔铁塔', city: '巴黎', address: 'Champ de Mars, 5 Av. Anatole France, 75007 Paris', icon: '🗼', wikiTitle: '埃菲尔铁塔', lat: 48.8584, lng: 2.2945),
  BuiltinPoi(name: '卢浮宫', city: '巴黎', address: 'Rue de Rivoli, 75001 Paris', icon: '🏛️', wikiTitle: '卢浮宫', lat: 48.8606, lng: 2.3376),
  BuiltinPoi(name: '凯旋门', city: '巴黎', address: 'Place Charles de Gaulle, 75008 Paris', icon: '⛩️', wikiTitle: '凯旋门', lat: 48.8738, lng: 2.2950),
  BuiltinPoi(name: '大英博物馆', city: '伦敦', address: 'Great Russell St, London WC1B 3DG', icon: '🏛️', wikiTitle: '大英博物馆', lat: 51.5194, lng: -0.1270),
  BuiltinPoi(name: '伦敦眼', city: '伦敦', address: 'Lambeth, London SE1 7PB', icon: '🎡', wikiTitle: '伦敦眼', lat: 51.5033, lng: -0.1196),
  BuiltinPoi(name: '时代广场', city: '纽约', address: 'Manhattan, NY 10036', icon: '🌃', wikiTitle: '时代广场', lat: 40.7580, lng: -73.9855),
  BuiltinPoi(name: '自由女神像', city: '纽约', address: 'Liberty Island, New York, NY', icon: '🗽', wikiTitle: '自由女神像', lat: 40.6892, lng: -74.0445),
  BuiltinPoi(name: '大皇宫', city: '曼谷', address: 'Na Phra Lan Rd, Phra Nakhon, Bangkok', icon: '🏯', wikiTitle: '曼谷大皇宫', lat: 13.7500, lng: 100.4910),
  BuiltinPoi(name: '鱼尾狮公园', city: '新加坡', address: '1 Fullerton Rd, Singapore', icon: '🦁', wikiTitle: '鱼尾狮', lat: 1.2868, lng: 103.8545),
  BuiltinPoi(name: '圣淘沙岛', city: '新加坡', address: 'Sentosa Island, Singapore', icon: '🏖️', wikiTitle: '圣淘沙', lat: 1.2494, lng: 103.8302),
  BuiltinPoi(name: '悉尼歌剧院', city: '悉尼', address: 'Bennelong Point, Sydney NSW 2000', icon: '🎭', wikiTitle: '悉尼歌剧院', lat: -33.8568, lng: 151.2153),
  BuiltinPoi(name: '邦迪海滩', city: '悉尼', address: 'Bondi Beach, NSW 2026', icon: '🏖️', wikiTitle: '邦迪海滩', lat: -33.8908, lng: 151.2743),
];
