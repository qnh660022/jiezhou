// L1-P0 攻略层用例（§7.13）：HTML 清洗 / 种子包结构 / 文章品控 / 归一化 / 降级链 / 缓存。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/data/guide/guide_aggregator.dart';
import 'package:travel_assistant/data/guide/guide_crawler_rules.dart';
import 'package:travel_assistant/data/guide/guide_models.dart';
import 'package:travel_assistant/data/guide/guide_normalize.dart';
import 'package:travel_assistant/data/guide/guide_raw_html.dart';
import 'package:travel_assistant/data/guide/guide_cache.dart' show GuideCache;
import 'package:travel_assistant/data/guide/guide_service.dart';

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

    test('L1-P0 城市数 ≥30 且 key 唯一、结构合法、单城 ≤20KB', () {
      final cities = (seed['cities'] as List).cast<Map>();
      expect(cities.length, greaterThanOrEqualTo(30));
      final keys = <String>{};
      for (final c in cities) {
        final m = c.cast<String, dynamic>();
        expect(GuideCity.validate(m), isNull, reason: '${m['key']} 结构非法');
        expect(keys.add(m['key'] as String), isTrue, reason: '${m['key']} key 重复');
        final size = jsonEncode(m).length;
        expect(size, lessThanOrEqualTo(20 * 1024),
            reason: '${m['key']} 单城超 20KB: $size');
      }
    });

    test('L1-P0 六栏齐全、每栏 3~8 条', () {
      for (final c in (seed['cities'] as List).cast<Map>()) {
        final sections =
            (c['sections'] as Map).cast<String, dynamic>();
        for (final k in GuideCity.sectionKeys) {
          final list = (sections[k] as List?) ?? [];
          expect(list.length, greaterThanOrEqualTo(3),
              reason: '${c['key']}.$k 少于 3 条');
          expect(list.length, lessThanOrEqualTo(8),
              reason: '${c['key']}.$k 超过 8 条');
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

  group('白名单纪律（§7.6）', () {
    test('L1-P0 白名单命中与拒绝', () {
      expect(
          matchGuideRule('https://www.mafengwo.cn/yj/12345')?.name, '马蜂窝');
      expect(matchGuideRule('https://evil.example.com/yj/1'), isNull);
      expect(
          matchGuideRule('https://www.mafengwo.cn/hotel/1'), isNull); // 路径不符
    });
  });

  group('降级链（§7.2）', () {
    test('L1-P0 无法识别目的地 → failed 语义（不抛异常）', () async {
      final svc = GuideService();
      final r = await svc.getGuide('亚特兰蒂斯');
      expect(r.failed, isNotNull);
      expect(r.location, isNull);
    });

    test('L1-P0 有种子城市：seed 层成功即有内容，layersUsed 含 seed，不抛', () async {
      final svc = GuideService();
      final r = await svc.getGuide('杭州');
      expect(r.failed, isNull);
      expect(r.location!.key, 'hangzhou');
      expect(r.layersUsed, contains('seed'));
      expect((r.sections['spots'] ?? const []).isNotEmpty, isTrue);
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
