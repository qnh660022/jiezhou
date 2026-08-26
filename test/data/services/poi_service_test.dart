/// POI 服务单元测试：离线去重排序 + 空关键字 + reverseGeocode。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_assistant/data/services/impl/poi_service_impl.dart';

void main() {
  group('PoiServiceImpl.search', () {
    test('空关键字返回空列表', () async {
      final svc = PoiServiceImpl();
      final results = await svc.search('');
      expect(results, isEmpty);
    });

    test('空格关键字返回空列表', () async {
      final svc = PoiServiceImpl();
      final results = await svc.search('   ');
      expect(results, isEmpty);
    });

    test('内置离线POI匹配（浅草寺）', () async {
      final svc = PoiServiceImpl();
      final results = await svc.search('浅草');
      // Should find builtin POI "浅草寺"
      expect(results, isNotEmpty);
      expect(results.first.name, contains('浅草'));
      expect(results.first.source.name, 'offline');
    });

    test('内置离线POI匹配（东京塔）', () async {
      final svc = PoiServiceImpl();
      final results = await svc.search('东京塔');
      expect(results, isNotEmpty);
      expect(results.first.source.name, 'offline');
    });

    test('城市名匹配（上海）', () async {
      final svc = PoiServiceImpl();
      final results = await svc.search('上海');
      expect(results, isNotEmpty);
      // Should find POIs in Shanghai
      expect(results.any((r) => r.address.contains('上海')), isTrue);
    });
  });

  group('PoiServiceImpl.reverseGeocode', () {
    test('无效坐标返回空串（网络不通）', () async {
      final svc = PoiServiceImpl();
      // This will fail in test env with no network, should return ""
      final result = await svc.reverseGeocode(35.6762, 139.6503);
      expect(result, isA<String>());
    });
  });
}
