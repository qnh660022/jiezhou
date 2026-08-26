/// 航班服务单元测试：IATA/ICAO正则 + 内置航线 + WMO映射。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_assistant/data/seed/airlines.dart';
import 'package:travel_assistant/data/seed/airports.dart';
import 'package:travel_assistant/data/seed/common_routes.dart';
import 'package:travel_assistant/data/seed/wmo_codes.dart';

void main() {
  group('航班号正则验证', () {
    final iataRe = RegExp(r'^[A-Z0-9]{2}\d{1,4}$');
    final icaoRe = RegExp(r'^[A-Z][A-Z0-9]{2}\d{1,4}$');

    test('IATA格式匹配', () {
      expect(iataRe.hasMatch('MU5137'), isTrue);
      expect(iataRe.hasMatch('CA1833'), isTrue);
      expect(iataRe.hasMatch('3U8881'), isTrue);
      expect(iataRe.hasMatch('CZ3101'), isTrue);
    });

    test('IATA格式不匹配', () {
      expect(iataRe.hasMatch(''), isFalse);
      expect(iataRe.hasMatch('M'), isFalse);
      expect(iataRe.hasMatch('MU51378'), isFalse); // too many digits
      expect(iataRe.hasMatch('mu5137'), isFalse); // lowercase
    });

    test('ICAO格式匹配', () {
      expect(icaoRe.hasMatch('CES5137'), isTrue);
      expect(icaoRe.hasMatch('CCA1833'), isTrue);
      expect(icaoRe.hasMatch('CSN3101'), isTrue);
    });

    test('ICAO格式不匹配', () {
      expect(icaoRe.hasMatch(''), isFalse);
      expect(icaoRe.hasMatch('CE'), isFalse); // too short
      expect(icaoRe.hasMatch('5U5137'), isFalse); // starts with digit
    });
  });

  group('内置航司库', () {
    test('按IATA查找航司', () {
      expect(findAirlineByIata('MU')?.name, '中国东方航空');
      expect(findAirlineByIata('CA')?.name, '中国国际航空');
      expect(findAirlineByIata('CZ')?.name, '中国南方航空');
      expect(findAirlineByIata('XX'), isNull);
    });

    test('按ICAO查找航司', () {
      expect(findAirlineByIcao('CES')?.name, '中国东方航空');
      expect(findAirlineByIcao('CCA')?.name, '中国国际航空');
      expect(findAirlineByIcao('XXX'), isNull);
    });

    test('航司数量>=62', () {
      expect(kAirlines.length, greaterThanOrEqualTo(62));
    });
  });

  group('内置机场库', () {
    test('按IATA查找机场', () {
      final pek = findAirport('PEK');
      expect(pek, isNotNull);
      expect(pek!.name, contains('首都'));
      expect(findAirport('XXX'), isNull);
    });

    test('机场数量>=138', () {
      expect(kAirports.length, greaterThanOrEqualTo(138));
    });
  });

  group('常用航线', () {
    test('按航班号查找航线', () {
      final r = findCommonRoute('CA1833');
      expect(r, isNotNull);
      expect(r!.from, 'PEK');
      expect(r.to, 'SHA');
    });

    test('忽略大小写和空格', () {
      final r1 = findCommonRoute('ca1833');
      final r2 = findCommonRoute('CA 1833');
      final r3 = findCommonRoute('CA-1833');
      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r3, isNotNull);
    });

    test('未知航线返回null', () {
      expect(findCommonRoute('XX9999'), isNull);
    });

    test('航线数量>=11', () {
      expect(kCommonRoutes.length, greaterThanOrEqualTo(11));
    });
  });

  group('WMO天气代码映射', () {
    test('所有分组代码都有映射', () {
      for (final group in kWmoCodeGroups) {
        for (final code in group.codes) {
          final w = kWmoWeatherByCode[code];
          expect(w, isNotNull, reason: 'WMO code $code should have mapping');
          expect(w!.icon, isNotEmpty);
          expect(w.text, isNotEmpty);
        }
      }
    });

    test('覆盖>=12个独立代码', () {
      expect(kWmoWeatherByCode.length, greaterThanOrEqualTo(12));
    });

    test('未知代码返回兜底', () {
      final w = kWmoWeatherByCode[999];
      expect(w, isNull);
      expect(kWmoUnknown.icon, isNotEmpty);
      expect(kWmoUnknown.text, '未知');
    });

    test('常见天气代码', () {
      expect(kWmoWeatherByCode[0]?.icon, '☀️');
      expect(kWmoWeatherByCode[0]?.text, '晴');
      expect(kWmoWeatherByCode[3]?.text, '阴');
      expect(kWmoWeatherByCode[61]?.text, '雨');
      expect(kWmoWeatherByCode[95]?.text, '雷雨');
    });
  });
}
