// 数据来源: D:\AI\money\utils\flight.js · 条数 62
// 由 travel-assistant-v2/integrator 从旧版小程序数据层迁移生成；纯常量，无任何第三方/flutter 依赖。
// 常用航空公司库（IATA 两字码 / ICAO 三字码 / 中文名）。

/// 航空公司。
class Airline {
  /// IATA 两字码（如 CA）
  final String iata;

  /// ICAO 三字码（如 CCA）
  final String icao;

  /// 中文名称
  final String name;

  const Airline(this.iata, this.icao, this.name);
}

/// 内置航司全集。
const List<Airline> kAirlines = [
  Airline('CA', 'CCA', '中国国际航空'),
  Airline('MU', 'CES', '中国东方航空'),
  Airline('CZ', 'CSN', '中国南方航空'),
  Airline('HU', 'CHH', '海南航空'),
  Airline('MF', 'CXA', '厦门航空'),
  Airline('3U', 'CSC', '四川航空'),
  Airline('ZH', 'CSZ', '深圳航空'),
  Airline('SC', 'CDG', '山东航空'),
  Airline('HO', 'DKH', '吉祥航空'),
  Airline('GS', 'GCR', '天津航空'),
  Airline('8L', 'LKE', '祥鹏航空'),
  Airline('KY', 'KNA', '昆明航空'),
  Airline('GJ', 'CDC', '长龙航空'),
  Airline('EU', 'UEA', '成都航空'),
  Airline('KN', 'CUH', '中国联合航空'),
  Airline('9C', 'CQH', '春秋航空'),
  Airline('BK', 'OKA', '奥凯航空'),
  Airline('G5', 'HXA', '华夏航空'),
  Airline('PN', 'CHB', '西部航空'),
  Airline('DZ', 'EPA', '东海航空'),
  Airline('JD', 'CBJ', '首都航空'),
  Airline('QW', 'QDA', '青岛航空'),
  Airline('9H', 'CGN', '长安航空'),
  Airline('FU', 'FUA', '福州航空'),
  Airline('NS', 'HBH', '河北航空'),
  Airline('TV', 'TBA', '西藏航空'),
  Airline('NH', 'ANA', '全日空'),
  Airline('JL', 'JAL', '日本航空'),
  Airline('KE', 'KAL', '大韩航空'),
  Airline('OZ', 'AAR', '韩亚航空'),
  Airline('CX', 'CPA', '国泰航空'),
  Airline('KA', 'HDA', '国泰港龙'),
  Airline('SQ', 'SIA', '新加坡航空'),
  Airline('TG', 'THA', '泰国国际航空'),
  Airline('MH', 'MAS', '马来西亚航空'),
  Airline('QF', 'QFA', '澳洲航空'),
  Airline('UA', 'UAL', '美国联合航空'),
  Airline('AA', 'AAL', '美国航空'),
  Airline('DL', 'DAL', '达美航空'),
  Airline('BA', 'BAW', '英国航空'),
  Airline('AF', 'AFR', '法国航空'),
  Airline('LH', 'DLH', '汉莎航空'),
  Airline('EK', 'UAE', '阿联酋航空'),
  Airline('QR', 'QTR', '卡塔尔航空'),
  Airline('SU', 'AFL', '俄罗斯航空'),
  Airline('TK', 'THY', '土耳其航空'),
  Airline('CI', 'CAL', '中华航空'),
  Airline('BR', 'EVA', '长荣航空'),
  Airline('AC', 'ACA', '加拿大航空'),
  Airline('NZ', 'ANZ', '新西兰航空'),
  Airline('KL', 'KLM', '荷兰皇家航空'),
  Airline('LX', 'SWR', '瑞士航空'),
  Airline('AY', 'FIN', '芬兰航空'),
  Airline('VS', 'VIR', '维珍大西洋航空'),
  Airline('ET', 'ETH', '埃塞俄比亚航空'),
  Airline('EY', 'ETD', '阿提哈德航空'),
  Airline('GA', 'GIA', '印尼鹰航'),
  Airline('PR', 'PAL', '菲律宾航空'),
  Airline('VN', 'HVN', '越南航空'),
  Airline('AK', 'AXM', '亚洲航空'),
  Airline('FD', 'AIQ', '泰国亚航'),
  Airline('TR', 'TGW', '酷航'),
];

/// 按 IATA 两字码查找航司；未命中返回 null。
Airline? findAirlineByIata(String iata) {
  final code = iata.trim().toUpperCase();
  for (final a in kAirlines) {
    if (a.iata == code) return a;
  }
  return null;
}

/// 按 ICAO 三字码查找航司；未命中返回 null。
Airline? findAirlineByIcao(String icao) {
  final code = icao.trim().toUpperCase();
  for (final a in kAirlines) {
    if (a.icao == code) return a;
  }
  return null;
}
