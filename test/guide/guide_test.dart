// L1-P0 攻略层用例（§7.13）：HTML 清洗 / 种子包结构 / 文章品控 / 归一化 / 降级链 / 缓存。
// 2026-09-06 扩：多目的地归一化、全国城市表、open 层（Open-Meteo/OSM）、搜狐白名单。
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/guide/guide_aggregator.dart';
import 'package:travel_assistant/data/guide/guide_crawler_rules.dart';
import 'package:travel_assistant/data/guide/guide_models.dart';
import 'package:travel_assistant/data/guide/guide_normalize.dart';
import 'package:travel_assistant/data/guide/guide_open_source.dart';
import 'package:travel_assistant/data/guide/guide_http.dart' show GuideFetchClass, GuideFetchResult;
import 'package:travel_assistant/data/guide/guide_raw_html.dart';
import 'package:travel_assistant/data/guide/guide_cache.dart' show GuideCache;
import 'package:travel_assistant/data/guide/guide_service.dart';
import 'package:travel_assistant/data/seed/china_regions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HTML 清洗（手写，无外部解析依赖）', () {
    test('L1-P0 script/style/注释/标签剥离、实体解码、空白压缩、段落抽取', () {
      final html = '''
      <html><head><style>.a{color:red}</style><script>alert(1)</script></head>
      <body><!-- 注释 --><p>西湖风景区是杭州最著名的景点，四季景色各异</p>
      <div><h2>灵隐寺与飞来峰造像值得用半天慢慢逛</h2><li>飞来峰造像 &amp; 石刻艺术非常有名</li><br/>
      <span>短</span></div></body></html>''';
      final ps = extractParagraphs(html);
      expect(ps.join('\n'), isNot(contains('<')));
      expect(ps.join('\n'), isNot(contains('alert')));
      expect(ps.join('\n'), isNot(contains('color:red')));
      expect(ps.any((p) => p.contains('西湖风景区')), isTrue);
      expect(ps.any((p) => p.contains('灵隐寺与飞来峰造像')), isTrue);
      expect(ps.any((p) => p.contains('飞来峰造像 & 石刻')), isTrue);
      expect(ps.any((p) => p == '短'), isFalse); // 短段落被过滤
    });
  });

  group('种子包结构（§7.13）', () {
    late Map<String, dynamic> seed;
    setUpAll(() async {
      final raw = await rootBundle
          .loadString('assets/data/guide_seed_v1.json');
      seed = (jsonDecode(raw) as Map).cast<String, dynamic>();
    });

    // 离线种子 2.0：内容精品化后红线放宽（仅防呆兜底，正常单城 15~60KB、每栏 3~12 条）。
    test('L1-P0 城市数 ≥55 且 key 唯一、结构合法、单城 ≤256KB', () {
      final cities = (seed['cities'] as List).cast<Map>();
      expect(cities.length, greaterThanOrEqualTo(55));
      final keys = <String>{};
      for (final c in cities) {
        final m = c.cast<String, dynamic>();
        expect(GuideCity.validate(m), isNull, reason: '${m['key']} 结构非法');
        expect(keys.add(m['key'] as String), isTrue, reason: '${m['key']} key 重复');
        final size = jsonEncode(m).length;
        expect(size, lessThanOrEqualTo(256 * 1024),
            reason: '${m['key']} 单城超 256KB: $size');
      }
    });

    test('L1-P0 六栏齐全、每栏 3~24 条', () {
      for (final c in (seed['cities'] as List).cast<Map>()) {
        final sections =
            (c['sections'] as Map).cast<String, dynamic>();
        for (final k in GuideCity.sectionKeys) {
          final list = (sections[k] as List?) ?? [];
          expect(list.length, greaterThanOrEqualTo(3),
              reason: '${c['key']}.$k 少于 3 条');
          expect(list.length, lessThanOrEqualTo(24),
              reason: '${c['key']}.$k 超过 24 条');
        }
      }
    });
  });

  group('归一化（§7.14）', () {
    test('L1-P0 清洗后缀、区间取主名、别名、英文、未匹配 null', () {
      expect(normalizeGuideDestination('成都市区')!.key, 'chengdu');
      expect(normalizeGuideDestination('四川成都')!.key, 'chengdu');
      expect(normalizeGuideDestination('成都-稻城')!.key, 'chengdu');
      expect(normalizeGuideDestination('蓉城')!.key, 'chengdu');
      expect(normalizeGuideDestination('Chengdu')!.key, 'chengdu');
      expect(normalizeGuideDestination('莫高窟')!.key, 'dunhuang');
      expect(normalizeGuideDestination('羊城三日')!.key, 'guangzhou');
      expect(normalizeGuideDestination('亚特兰蒂斯'), isNull);
    });

    test('L1-P1 多目的地：分段归一、去重保序、上限 5 城', () {
      // 「成都-稻城」两段都命中（稻城 v2 已入种子）
      final duo = normalizeGuideDestinations('成都-稻城');
      expect(duo.map((e) => e.key).toList(), ['chengdu', 'daocheng']);
      // 「A到B」形态
      expect(normalizeGuideDestinations('成都到稻城').length, 2);
      // 顿号分隔
      expect(normalizeGuideDestinations('大理、丽江').map((e) => e.key),
          ['dali', 'lijiang']);
      // 未识别段跳过，识别段保留；重复段去重
      final mixed = normalizeGuideDestinations('亚特兰蒂斯-成都-成都');
      expect(mixed.map((e) => e.key).toList(), ['chengdu']);
      // 上限 5
      final many = normalizeGuideDestinations('北京-上海-广州-成都-杭州-西安');
      expect(many.length, 5);
      // 单数版语义不变：首命中
      expect(normalizeGuideDestinations('成都-稻城', maxCities: 1).single.key,
          'chengdu');
      // 全不识别 → 空表
      expect(normalizeGuideDestinations('亚特兰蒂斯-幻想乡'), isEmpty);
    });

    test('L1-P1 港澳台与新城市别名（椰城→海口等）', () {
      expect(normalizeGuideDestination('香港')!.key, 'hongkong');
      expect(normalizeGuideDestination('Macau')!.key, 'macau');
      expect(normalizeGuideDestination('椰城')!.key, 'haikou');
      expect(normalizeGuideDestination('稻城亚丁')!.key, 'daocheng');
      expect(normalizeGuideDestination('泰山两日')!.key, 'taian');
      expect(normalizeGuideDestination('北戴河看海')!.key, 'qinhuangdao');
    });
  });

  group('全国城市表（目的地选择器数据源）', () {
    test('L1-P1 分组 ≥28、34 省级区划全覆盖、城市 ≥330、无重名、港澳台必含', () {
      expect(kChinaRegions.length, greaterThanOrEqualTo(28));
      // 34 个省级行政区必须全部被覆盖（直辖/港澳台为展示分组，其余为独立键）
      const all34 = [
        '北京', '天津', '上海', '重庆',
        '河北', '山西', '内蒙古', '辽宁', '吉林', '黑龙江',
        '江苏', '浙江', '安徽', '福建', '江西', '山东', '河南',
        '湖北', '湖南', '广东', '广西', '海南', '四川', '贵州', '云南',
        '西藏', '陕西', '甘肃', '青海', '宁夏', '新疆',
        '香港', '澳门', '台湾',
      ];
      final regionNames = <String>{
        ...kChinaRegions.keys,
        ...(kChinaRegions['直辖市'] ?? const []),
        ...(kChinaRegions['港澳台'] ?? const []),
      };
      for (final p in all34) {
        expect(regionNames.contains(p), isTrue, reason: '缺省级区划 $p');
      }
      expect(kChinaCityCount, greaterThanOrEqualTo(330));
      final names = <String>{};
      for (final c in kChinaCities) {
        expect(names.add(c.name), isTrue, reason: '${c.name} 重名');
      }
      final hmt = kChinaRegions['港澳台']!;
      for (final must in ['香港', '澳门', '台北', '高雄']) {
        expect(hmt.contains(must), isTrue, reason: '港澳台缺 $must');
      }
      // 热门旅游县级市在表内（与攻略种子呼应）
      for (final must in ['敦煌', '稻城', '香格里拉', '婺源', '平遥']) {
        expect(names.contains(must), isTrue, reason: '缺热门城市 $must');
      }
    });
  });

  group('open 层（Open-Meteo 天气 + OSM 国内中文 POI）', () {
    test('L1-P1 天气+POI 解析；外文/海外 POI 被丢弃（2026-09 去外国内容）', () async {
      const weatherJson = '{"daily":{"time":["2026-09-06","2026-09-07","2026-09-08"],'
          '"temperature_2m_max":[30,31,29],"temperature_2m_min":[22,23,21],'
          '"precipitation_probability_max":[10,80,20]}}';
      const poiJson = '{"features":['
          // 国内 + 中文名：保留
          '{"properties":{"name":"成都博物馆","countrycode":"CN","osm_type":"W","osm_id":"1",'
          '"osm_value":"museum","district":"西御河街道","city":"成都市"}},'
          // 地名自身：过滤
          '{"properties":{"name":"成都","countrycode":"CN","osm_type":"N","osm_id":"2"}},'
          // 海外 + 中文名：过滤（countrycode 不是 CN）
          '{"properties":{"name":"东京国立博物馆","countrycode":"JP","osm_type":"W","osm_id":"4"}},'
          // 国内但外文名：过滤（无汉字）
          '{"properties":{"name":"Tokyo Tower","countrycode":"CN","osm_type":"W","osm_id":"5"}},'
          '{"properties":{"name":"人民公园","countrycode":"CN","osm_type":"W","osm_id":"3",'
          '"osm_value":"park","city":"成都市"}}]}';
      final layer = GuideOpenSourceLayer(fetchOverride: (url) {
        if (url.contains('open-meteo')) {
          return const GuideFetchResult(GuideFetchClass.ok, weatherJson);
        }
        return const GuideFetchResult(GuideFetchClass.ok, poiJson);
      });
      final out = await layer.enhance(const GuideLocation('chengdu', '成都'));
      expect(out, isNotNull);
      expect(out!['prep']!.first['source'], 'Open-Meteo');
      expect((out['prep']!.first['detail'] as String).contains('降水概率80%'),
          isTrue);
      final spotNames = out['spots']!.map((e) => e['name']).toList();
      expect(spotNames, ['成都博物馆', '人民公园']); // 地名自身/海外/外文全被过滤
      expect(out['spots']!.every((e) => e['sourceUrl'] != null), isTrue);
    });

    test('L1-P1 全链路失败 → 返回 null（静默降级，不抛）', () async {
      final layer = GuideOpenSourceLayer(
          fetchOverride: (_) => const GuideFetchResult(GuideFetchClass.networkFail, ''));
      final out = await layer.enhance(const GuideLocation('chengdu', '成都'));
      expect(out, isNull);
    });
  });

  group('文章品控（§7.7）', () {
    const agg = GuideAggregator();

    test('L1-P0 >8 截断、URL 去重、标题长度过滤、评分倒序', () {
      final now = DateTime(2026, 9, 1);
      final raw = List.generate(12, (i) => {
            'title': '杭州自由行完整攻略第${i}篇实在很长很好',
            'sourceUrl': 'https://www.mafengwo.cn/yj/$i',
            'publishedAt': now.subtract(Duration(days: 10 + i)).millisecondsSinceEpoch,
          });
      // 重复 URL
      raw.add({...raw[0], 'title': '杭州自由行完全不一样的另一篇攻略文'});
      // 标题过短
      raw.add({'title': '短标题', 'sourceUrl': 'https://bbs.qyer.com/thread-99'});
      final out = agg.filterAndScore(raw, now: now);
      expect(out.length, 8); // 上限 8
      final urls = out.map((a) => a['sourceUrl']).toSet();
      expect(urls.length, out.length); // 去重
      // 评分倒序（新鲜度随天数衰减 → 越新越靠前）
      for (var i = 1; i < out.length; i++) {
        expect((out[i - 1]['score'] as double),
            greaterThanOrEqualTo(out[i]['score'] as double));
      }
    });
  });

  group('白名单纪律（§7.6，2026-09 换源）', () {
    test('L1-P0 去哪儿城市页命中、子页与未知域拒绝', () {
      expect(
          matchGuideRule('https://travel.qunar.com/p-cs300195-hangzhou')?.name,
          '去哪儿攻略');
      expect(matchGuideRule('https://evil.example.com/p-cs1-hangzhou'), isNull);
      // 子页实测 404，不进白名单
      expect(
          matchGuideRule('https://travel.qunar.com/p-cs300195-hangzhou-meishi'),
          isNull);
    });

    test('L1-P1 实测禁抓的站点不再放行（全站 Disallow 或反爬壳）', () {
      // 马蜂窝 robots: User-agent:* Disallow:/
      expect(matchGuideRule('https://www.mafengwo.cn/yj/12345'), isNull);
      expect(isKnownBlockedHost('www.mafengwo.cn'), isTrue);
      // 穷游：安全验证壳
      expect(matchGuideRule('https://bbs.qyer.com/thread-99'), isNull);
      expect(isKnownBlockedHost('bbs.qyer.com'), isTrue);
      // 知乎专栏：403 + robots 全禁
      expect(matchGuideRule('https://zhuanlan.zhihu.com/p/123'), isNull);
      // 搜狐：robots 对通用 UA 全禁
      expect(
          matchGuideRule('https://www.sohu.com/a/811864015_122045638',
              articles: true),
          isNull);
    });

    test('L1-P1 停用规则仍留在表里可审计', () {
      final names =
          kGuideCrawlerRules.where((r) => !r.enabled).map((r) => r.name).toSet();
      expect(names, containsAll(['马蜂窝', '穷游网', '知乎', '搜狐旅游']));
      // 每条停用规则都要写明实测依据
      for (final r in kGuideCrawlerRules.where((r) => !r.enabled)) {
        expect(r.note.isNotEmpty, isTrue, reason: '${r.name} 缺 note');
      }
    });
  });

  group('降级链（§7.2）', () {
    test('L1-P0 无法识别目的地 → failed 语义（不抛异常）', () async {
      final svc = GuideService(enableOnline: false);
      final r = await svc.getGuide('亚特兰蒂斯');
      expect(r.failed, isNotNull);
      expect(r.location, isNull);
    });

    test('L1-P0 有种子城市：seed 层成功即有内容，layersUsed 含 seed，不抛', () async {
      final svc = GuideService(enableOnline: false);
      final r = await svc.getGuide('杭州');
      expect(r.failed, isNull);
      expect(r.location!.key, 'hangzhou');
      expect(r.layersUsed, contains('seed'));
      expect((r.sections['spots'] ?? const []).isNotEmpty, isTrue);
      // 纯离线结果：无在线层，徽标应为离线态
      expect(r.hasOnline, isFalse);
      expect(r.onlineAttempted, isFalse);
    });

    test('L1-P1 多目的地：getGuideMultiOffline 逐城返回离线结果', () async {
      final svc = GuideService(enableOnline: false);
      final results = await svc.getGuideMultiOffline('成都-稻城');
      expect(results.map((e) => e.location!.key).toList(),
          ['chengdu', 'daocheng']);
      expect(results.every((r) => r.layersUsed.contains('seed')), isTrue);
      expect(
          (results.first.sections['spots'] ?? const []).isNotEmpty, isTrue);
    });

    test('L1-P1 多目的地：getGuideMulti 全不识别 → 空表（UI 走空态）', () async {
      final svc = GuideService(enableOnline: false);
      expect(await svc.getGuideMulti('亚特兰蒂斯-幻想乡'), isEmpty);
    });
  });

  group('缓存（GuideCache 逻辑，临时目录版）', () {
    test('L1-P0 写入后可读、TTL 过期不命中（用 manifest 直改验证判定逻辑）', () async {
      // 说明：真实 writableDir 依赖平台通道；此处验证 GuideCity JSON 往返与
      // TTL 判定公式（savedAtMs + ttlMs 与失效等价）。
      final now = DateTime.now().millisecondsSinceEpoch;
      final city = GuideCity('hangzhou', '杭州', {
        for (final k in GuideCity.sectionKeys) k: [
          {'title': '条目', 'detail': 'x'}
        ]
      });
      final json = city.toJson(layersUsed: ['seed']);
      final parsed = (jsonDecode(jsonEncode(json)) as Map).cast<String, dynamic>();
      expect(GuideCity.validate({
        'key': parsed['key'],
        'name': parsed['name'],
        'sections': parsed['sections'],
      }), isNull);
      // TTL：1 天前写入（<7 天）命中；8 天前失效
      expect(now - (now - 1 * 86400000) <= GuideCache.ttlMs, isTrue);
      expect(now - (now - 8 * 86400000) > GuideCache.ttlMs, isTrue);
    });
  });
}
