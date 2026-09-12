// 攻略层新契约用例（2026-09：精品 50 城 / 换源 / UI 重设计 / AI 导入）。
//
// 与 guide_test.dart 的分工：那边保留 §7.13 的既有行为断言（不改语义），
// 这边覆盖本轮新增的契约——种子体量与 area、去哪儿 ID 表、中文过滤、
// 爬取层城市页解析、AI 导入优先级。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:travel_assistant/data/guide/guide_ai_draft.dart';
import 'package:travel_assistant/data/guide/guide_cache.dart';
import 'package:travel_assistant/data/guide/guide_city_sources.dart';
import 'package:travel_assistant/data/guide/guide_content_filter.dart';
import 'package:travel_assistant/data/guide/guide_crawler.dart';
import 'package:travel_assistant/data/guide/guide_crawler_rules.dart';
import 'package:travel_assistant/data/guide/guide_http.dart'
    show GuideFetchClass, GuideFetchResult;
import 'package:travel_assistant/data/guide/guide_models.dart';
import 'package:travel_assistant/data/guide/guide_paste_import.dart';
import 'package:travel_assistant/data/guide/guide_raw_html.dart';
import 'package:travel_assistant/data/guide/guide_service.dart';

/// 精品 50 城（与 docs/攻略生成提示词模板.md、check_guide_seed.py 保持一致）。
const kPremium50 = [
  'beijing', 'shanghai',
  'hangzhou', 'suzhou', 'nanjing', 'xiamen', 'huangshan', 'wuxi', 'yangzhou',
  'shaoxing', 'ningbo', 'quanzhou', 'wuyuan', 'jinan', 'jingdezhen',
  'guangzhou', 'shenzhen', 'guilin', 'sanya', 'shantou', 'foshan', 'chaozhou',
  'haikou', 'beihai',
  'chengdu', 'chongqing', 'kunming', 'dali', 'lijiang', 'zhangjiajie',
  'guiyang', 'luoyang', 'xishuangbanna', 'shangrila', 'leshan',
  'xian', 'dunhuang', 'zhangye', 'xining',
  'harbin', 'dalian', 'qingdao', 'tianjin', 'shenyang', 'changchun',
  'hongkong', 'macau', 'taibei',
  'weihai', 'yanji',
];

/// 去哪儿城市页截取片段（结构取自真实抓取结果，2026-09）。
///
/// 关键：**简介文字在链接之后**（`<a>景点名</a>` 紧接一段说明，然后是下一个 `<a>`），
/// `extractLinkPairs` 依赖这个形态。写假数据时必须保持这个顺序，否则测试通过而
/// 真机抓不到内容。
const _qunarSample = '''
<html><head><title>杭州旅游攻略-2026杭州自助游</title></head><body>
<h1>杭州旅游攻略</h1>
<div>江南忆，最忆是杭州，一半山水一半城，人间天堂悠然生。</div>
<div>建议游玩：3天。</div>
<div>杭州的最佳出游时间是3-4月、9-10月，春秋较短，冬夏较长。</div>
<h2>推荐线路</h2>
<div>杭州经典4日线路</div>
<div>西湖往西面轻幽的群山走走，深度体验杭州的山水与人文</div>
<div>杭州人气3日线路</div>
<div>西湖美景三月天，三日带你在市区玩出经典</div>
<h2>不可错过</h2>
<a href="https://travel.qunar.com/p-ts14666">东坡肉</a>
<div>肥而不腻，配米饭最下饭，老字号楼外楼做得地道</div>
<a href="https://travel.qunar.com/p-ts14667">西湖醋鱼</a>
<div>酸甜适口，草鱼现杀现做，建议现点现吃不要打包</div>
<a href="https://travel.qunar.com/p-ts14668">龙井虾仁</a>
<div>虾仁清甜配新茶，春季最当时令，人均八十上下</div>
<h2>热门攻略</h2>
<h3><a href="https://travel.qunar.com/youji/6936441">杭州初游地盘点，附三天行程安排</a></h3>
<h3><a href="https://travel.qunar.com/youji/7076650">杭州美食地图，本地人常去的馆子清单</a></h3>
<table><tr><td><a href="https://piao.qunar.com/ticket/detail.htm?id=1">西湖游船</a></td><td>¥ 55起</td></tr></table>
<div>还没去过杭州</div>
<h2>目的地分类导航</h2>
<h3>杭州热门景点</h3>
<a href="https://travel.qunar.com/p-oi708952-xihu">西湖风景名胜区</a>
<div>断桥到苏堤的经典环湖线，骑行四小时能把精华看全</div>
<a href="https://travel.qunar.com/p-oi710142-lingyinsi">灵隐寺</a>
<div>飞来峰五代造像值得慢慢看，清晨人少光线也好</div>
<a href="https://travel.qunar.com/p-oi714820-qinghefangjie">清河坊街</a>
<div>老字号与小吃集中，晚市热闹，适合安排晚饭</div>
<div>热门城市</div>
<h2>合作机构</h2>
<div>Copyright©2021 Qunar.com 京ICP备05021087号</div>
</body></html>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('种子体量与 area（精品 50 城契约）', () {
    late Map<String, dynamic> seed;
    setUpAll(() async {
      final raw =
          await rootBundle.loadString('assets/data/guide_seed_v1.json');
      seed = (jsonDecode(raw) as Map).cast<String, dynamic>();
    });

    test('L1-P0 城市 ≥86、key 唯一、结构合法、area 合法', () {
      const areas = {
        '直辖市', '华东', '华南', '华中', '西南', '西北', '华北', '东北', '港澳台',
      };
      final cities = (seed['cities'] as List).cast<Map>();
      expect(cities.length, greaterThanOrEqualTo(86));
      final keys = <String>{};
      for (final c in cities) {
        final m = c.cast<String, dynamic>();
        expect(GuideCity.validate(m), isNull, reason: '${m['key']} 结构非法');
        expect(keys.add(m['key'] as String), isTrue, reason: '${m['key']} key 重复');
        final area = (m['area'] as String?) ?? '';
        expect(area.isNotEmpty, isTrue, reason: '${m['key']} 缺 area');
        expect(areas.contains(area), isTrue, reason: '${m['key']} area 非法：$area');
      }
    });

    test('L1-P0 精品 50 城全部在册', () {
      final keys = {
        for (final c in (seed['cities'] as List).cast<Map>()) c['key'] as String,
      };
      final missing = kPremium50.where((k) => !keys.contains(k)).toList();
      expect(missing, isEmpty, reason: '缺精品城市：$missing');
    });

    test('L1-P1 阅读时长换算：350 汉字/分钟、向上取整', () {
      // 用真实正文样本，按 cjkCount 就地算期望值（避免手工数字数出错）
      const body = '西湖环湖骑行经典线路，断桥到苏堤约四小时，沿路可看平湖秋月。';
      final perRun = cjkCount(body);
      expect(perRun, greaterThan(20));
      final chars = GuideCity.textCharCount(null, {
        'prep': [
          {'title': '定位', 'detail': body}
        ]
      });
      // title 也算正文（六栏所有字符串都计入阅读量）
      expect(chars, perRun + cjkCount('定位'));
      expect(GuideCity.readingMinutes(0), 0);
      expect(GuideCity.readingMinutes(100), 1);
      expect(GuideCity.readingMinutes(350), 1);
      expect(GuideCity.readingMinutes(351), 2);
      expect(GuideCity.readingMinutes(5500), 16);
    });

    test('L1-P1 旧数据缺 area 不影响校验（向后兼容）', () {
      expect(
          GuideCity.validate({
            'key': 'hangzhou',
            'name': '杭州',
            'sections': {for (final k in GuideCity.sectionKeys) k: <dynamic>[]},
          }),
          isNull);
    });
  });

  group('内容过滤（去掉外文/地点）', () {
    test('L1-P0 hasCjk 按数量判定，外文条目一律不通过', () {
      expect(hasCjk('西湖风景名胜区'), isTrue);
      expect(hasCjk('Tokyo Tower'), isFalse);
      expect(hasCjk('东京塔', min: 6), isFalse); // 只有 3 个汉字
      expect(hasCjk(''), isFalse);
      expect(hasCjk(null), isFalse);
      expect(cjkCount('杭州西湖 123 ABC'), 4);
    });

    test('L1-P0 entryLooksChinese 任一字段达标即通过', () {
      expect(
          entryLooksChinese({'name': 'Tokyo', 'note': '西湖风景很好'}, ['name', 'note']),
          isTrue);
      expect(
          entryLooksChinese({'name': 'Tokyo', 'note': 'nice'}, ['name', 'note']),
          isFalse);
    });

    test('L1-P1 站点导航行被识别为噪音，正文行不被误杀', () {
      expect(isGuideNoise('登录'), isTrue);
      expect(isGuideNoise('京ICP备05021087号'), isTrue);
      expect(isGuideNoise('热门城市'), isTrue);
      expect(isGuideNoise('品质一日游 小团'), isTrue);
      // 含「游」但属正常景点/正文：不能误杀（早前版本踩过这个坑）
      expect(isGuideNoise('西湖游船 55 元，建议傍晚去，人少且光线好'), isFalse);
      expect(isGuideNoise('苏州园林游'), isFalse);
    });
  });

  group('去哪儿城市页解析', () {
    test('L1-P0 结构化抽取：按标题分块、块内取要点', () {
      final sections = extractSections(_qunarSample);
      final titles = sections.map((s) => s.title).toList();
      expect(titles, contains('推荐线路'));
      expect(titles, contains('不可错过'));
      expect(titles, contains('杭州旅游攻略'));
    });

    test('L1-P0 页面城市名识别（抓取后复核用）', () {
      expect(pageCityName(_qunarSample), '杭州');
      expect(pageCityName('<html><title>长沙旅游攻略-2026</title></html>'), '长沙');
      expect(pageCityName('<html><body>nothing</body></html>'), isNull);
    });

    test('L1-P0 链接配对（图墙卡片：链接文字 + 尾随简介）', () {
      const html =
          '<a href="/x">西湖风景名胜区</a><div>半日游经典线路推荐</div>'
          '<a href="/y">灵隐寺</a><div>飞来峰造像值得慢慢看</div>';
      final pairs = extractLinkPairs(html);
      expect(pairs.length, 2);
      expect(pairs.first.text, '西湖风景名胜区');
      expect(pairs.first.tail.contains('半日游'), isTrue);
    });

    test('L1-P1 城市页抓取：返回六栏条目与中文游记，且经城市名复核', () async {
      final layer = GuideCrawlLayer(
        null as dynamic, // 走 fetchOverride，不触碰真实网络
        fetchOverride: (url) =>
            const GuideFetchResult(GuideFetchClass.ok, _qunarSample),
      );
      final res = await layer.crawlCity('hangzhou');
      expect(res, isNotNull);
      final r = res!;
      expect(r.sections['spots'], isNotEmpty);
      expect(r.sections['spots']!.first['name'], '西湖风景名胜区');
      expect(r.sections['food'], isNotEmpty);
      expect(r.articles, isNotEmpty);
      expect(r.articles.first['sourceUrl'], contains('/youji/'));
      expect(r.articles.every((a) => hasCjk(a['title'] as String, min: 4)), isTrue);
      expect(r.layers, contains('crawl'));
    });

    test('L1-P1 页面城市名与期望不符 → 整层丢弃（防错城正文）', () async {
      final layer = GuideCrawlLayer(
        null as dynamic,
        fetchOverride: (_) => const GuideFetchResult(
            GuideFetchClass.ok,
            '<html><title>长沙旅游攻略</title><body><h1>长沙旅游攻略</h1>'
            '<h2>热门攻略</h2></body></html>'),
      );
      // 请求 hangzhou，页面却是长沙 → 必须丢弃
      expect(await layer.crawlCity('hangzhou'), isNull);
    });

    test('L1-P1 无 ID 映射的城市直接跳过在线层（不猜 URL）', () async {
      final layer = GuideCrawlLayer(
        null as dynamic,
        fetchOverride: (_) => const GuideFetchResult(GuideFetchClass.ok, ''),
      );
      // wuzhen 不在 kQunarCityIds 里
      expect(kQunarCityIds.containsKey('wuzhen'), isFalse);
      expect(await layer.crawlCity('wuzhen'), isNull);
    });
  });

  group('白名单与去哪儿的 ID 表', () {
    test('L1-P0 已知禁抓站点被拦、去哪儿城市页放行', () {
      expect(isKnownBlockedHost('www.mafengwo.cn'), isTrue);
      expect(isKnownBlockedHost('bbs.qyer.com'), isTrue);
      expect(isKnownBlockedHost('travel.qunar.com'), isFalse);
      expect(matchGuideRule('https://travel.qunar.com/p-cs300195-hangzhou'),
          isNotNull);
      expect(matchGuideRule('https://travel.qunar.com/plan/first'), isNull);
      expect(matchGuideRule('https://travel.qunar.com/p-cs300195-hangzhou-xianlu'),
          isNull); // 子页 404，不进白名单
    });

    test('L1-P0 已停用规则不参与匹配（但仍留档）', () {
      final mafengwo = kGuideCrawlerRules.firstWhere((r) => r.host == 'www.mafengwo.cn');
      expect(mafengwo.enabled, isFalse);
      expect(matchGuideRule('https://www.mafengwo.cn/yj/12345'), isNull);
    });

    test('L1-P1 ID 表与名称表一一对应', () {
      expect(kQunarCityIds.length, kQunarCityNames.length);
      expect(kQunarCityIds.length, qunarCityCount);
      expect(kQunarCityIds.keys.toSet(), kQunarCityNames.keys.toSet());
      // 精品 50 城至少覆盖一半（无映射城市走内置种子，不算错）
      final covered =
          kPremium50.where((k) => kQunarCityIds.containsKey(k)).length;
      expect(covered, greaterThanOrEqualTo(25),
          reason: '在线源覆盖过少：$covered/50');
    });
  });

  group('AI 生成草稿与导入', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('L1-P0 草稿分栏累积、同栏同名覆盖、字数统计', () async {
      final d = await GuideAiDraft.start(
          cityKey: 'hangzhou', cityName: '杭州', area: '华东');
      d.putSection('spots', [
        {'name': '西湖', 'note': '环湖骑行经典线路，断桥到苏堤'},
      ]);
      d.putSection('spots', [
        {'name': '西湖', 'note': '改写后的说明文字'},
        {'name': '灵隐寺', 'note': '飞来峰造像值得慢慢看'},
      ]);
      d.putSection('prep', [
        {'title': '预约', 'detail': '灵隐寺香花券另购，旺季提前一天买'},
      ]);
      await d.save();

      final loaded = await GuideAiDraft.load('hangzhou');
      expect(loaded, isNotNull);
      expect(loaded!.sections['spots']!.length, 2); // 同名覆盖，不重复
      expect(loaded.sections['spots']!.first['note'], '改写后的说明文字');
      expect(loaded.sections['prep']!.length, 1);
      expect(loaded.textChars, greaterThan(20));
    });

    test('L1-P1 gaps 报出缺栏与字数不足', () async {
      final d = await GuideAiDraft.start(cityKey: 'suzhou', cityName: '苏州');
      d.putSection('prep', [
        {'title': '预约', 'detail': '拙政园旺季需提前预约，现场无票'},
      ]);
      final gaps = d.gaps();
      expect(gaps.any((g) => g.contains('景点推荐')), isTrue);
      expect(gaps.any((g) => g.contains('字')), isTrue);
    });

    test('L1-P1 toCityJson 通过种子契约校验', () async {
      final d = await GuideAiDraft.start(cityKey: 'xiamen', cityName: '厦门');
      for (final k in GuideCity.sectionKeys) {
        d.putSection(k, [
          {'title': '条目', 'name': '条目', 'item': '条目', 'detail': '内容内容内容'}
        ]);
      }
      expect(GuideCity.validate(d.toCityJson()), isNull);
      expect(d.summaryRows().last[0], '正文合计');
    });

    test('L1-P0 清洗：模型给的数字/布尔被转成字符串，空值丢弃', () async {
      final d = await GuideAiDraft.start(cityKey: 'changsha', cityName: '长沙');
      d.putSection('budget', [
        {'item': '住宿', 'rangeText': '200-400/晚（参考）', 'extra': 12},
        {'item': '', 'rangeText': ''},
      ]);
      expect(d.sections['budget']!.length, 1);
      expect(d.sections['budget']!.first['extra'], '12');
    });

    test('L1-P1 非法栏目名返回 -1 且不写入', () async {
      final d = await GuideAiDraft.start(cityKey: 'chengdu', cityName: '成都');
      expect(d.putSection('shopping', const []), -1);
      expect(d.itemCount, 0);
    });
  });

  group('粘贴导入解析（宽容 JSON）', () {
    const good = '{"key":"hangzhou","name":"杭州","sections":{'
        '"prep":[],"spots":[],"food":[],"transport":[],"tips":[],"budget":[]}}';

    test('L1-P0 裸 JSON 直接解析', () {
      final r = parseGuideJson(good);
      expect(r.error, isNull);
      expect(r.city!['key'], 'hangzhou');
    });

    test('L1-P0 包在代码块/前言里的 JSON 也能抽出', () {
      final r = parseGuideJson('好的，这是攻略：\n```json\n$good\n```\n希望有用');
      expect(r.error, isNull);
      expect(r.city!['name'], '杭州');
    });

    test('L1-P0 字符串里的花括号不干扰配对', () {
      final r = parseGuideJson(
          '{"key":"hangzhou","name":"杭州{西湖}","sections":{'
          '"prep":[],"spots":[],"food":[],"transport":[],"tips":[],"budget":[]}}');
      expect(r.error, isNull);
    });

    test('L1-P1 缺 sections / 缺 key / key 不在库 / key 不符 都给出可读错误', () {
      expect(parseGuideJson('{"key":"hangzhou"}').error, contains('sections'));
      expect(parseGuideJson('{"name":"杭州","sections":{}}').error, contains('key'));
      expect(
          parseGuideJson(good, seedNames: {'beijing': '北京'}).error,
          contains('攻略库里没有'));
      expect(
          parseGuideJson(good, expectKey: 'beijing').error,
          contains('不是当前城市'));
      expect(parseGuideJson('完全不是 JSON').error, isNotNull);
      expect(parseGuideJson('').error, isNotNull);
    });

    test('L1-P1 摘要含六栏与合计', () {
      final r = parseGuideJson(good);
      final rows = guideJsonSummary(r.city!);
      expect(rows.length, 7);
      expect(rows.last[0], '正文合计');
    });
  });

  group('AI 导入优先级（覆盖内置种子）', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('L1-P1 importCityGuide 拒绝结构不完整/过短内容', () async {
      final svc = GuideService(enableOnline: false);
      expect(await svc.importCityGuide({'key': 'hangzhou'}), isNotNull);
      final short = {
        'key': 'hangzhou',
        'name': '杭州',
        'sections': {
          for (final k in GuideCity.sectionKeys)
            k: [{'title': '标题', 'detail': '短'}],
        },
      };
      final err = await svc.importCityGuide(short);
      expect(err, isNotNull);
      expect(err, contains('太短'));
    });

    test('L1-P1 合法内容导入成功、可查询、可删除', () async {
      final tmp = await Directory.systemTemp.createTemp('guide_import_test');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final svc = GuideService(
        enableOnline: false,
        cache: GuideCache(baseDirOverride: tmp.path),
      );
      final long = '这是一段足够长的攻略正文，用来验证导入的字数下限判断逻辑是否生效。' * 30;
      final city = {
        'key': 'hangzhou',
        'name': '杭州',
        'sections': {
          for (final k in GuideCity.sectionKeys)
            k: [
              {'title': '标题', 'name': '名称', 'item': '项目', 'detail': long}
            ],
        },
      };
      expect(await svc.importCityGuide(city), isNull);
      expect(await svc.hasCityOverride('hangzhou'), isTrue);
      // 导入后 getGuide 立即返回 AI 内容（layersUsed 记 ai）
      final r = await svc.getGuide('杭州');
      expect(r.isAiImported, isTrue);
      expect(r.layersUsed, contains('ai'));
      await svc.clearCityOverride('hangzhou');
      expect(await svc.hasCityOverride('hangzhou'), isFalse);
      final back = await svc.getGuide('杭州');
      expect(back.isAiImported, isFalse);
      expect(back.layersUsed, contains('seed'));
    });
  });

  group('按城市 key 取攻略（城市切换入口）', () {
    test('L1-P1 getGuideMultiOfflineByKeys 逐城返回、去重、未知 key 也返回', () async {
      final svc = GuideService(enableOnline: false);
      final res = await svc.getGuideMultiOfflineByKeys(
          ['hangzhou', 'hangzhou', 'chengdu']);
      expect(res.length, 2);
      expect(res.map((r) => r.location!.key).toList(), ['hangzhou', 'chengdu']);
      expect(res.every((r) => r.layersUsed.contains('seed')), isTrue);
    });

    test('L1-P1 allCities 返回带 area 的城市清单', () async {
      final svc = GuideService(enableOnline: false);
      final cities = await svc.allCities();
      expect(cities.length, greaterThanOrEqualTo(86));
      expect(cities.where((c) => c.key == 'hangzhou').first.area, '华东');
    });
  });
}
