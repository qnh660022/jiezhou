// V2.7.1 S1 G2：备份信封默认魔数白名单收口 —— 三格式 round-trip + 四负例。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/export/backup_format.dart';

void main() {
  final sample = <String, dynamic>{
    'app': 'travel-assistant-v2',
    'version': 1,
    'group': {'id': 'g1', 'name': '团', 'kind': 'travel'},
    'members': [
      {'id': 'm1', 'name': '甲', 'archived': false},
    ],
    'expenses': [
      {'id': 'e1', 'amountCents': 1234, 'note': '中文/换行\n与引号"'},
    ],
  };

  group('三格式 round-trip（decode → encode → decode 逐字段一致）', () {
    for (final entry in {
      'TA1G 团备份': kGroupBackupMagic,
      'TA1T 行程备份': kTripBackupMagic,
      'TA1A 全量备份': kFullBackupMagic,
    }.entries) {
      test(entry.key, () {
        final bytes = encodeBackup(entry.value, sample);
        final first = decodeBackup(bytes); // 默认白名单应全部接受
        final second = decodeBackup(encodeBackup(entry.value, first));
        expect(second['group'], first['group']);
        expect(second['members'], first['members']);
        expect(second['expenses'], first['expenses']);
        expect(second['app'], 'travel-assistant-v2');
      });
    }
  });

  group('G2 默认白名单收口', () {
    test('decoded 默认接受 TA1A（修复前会误判「不是芥舟备份」）', () {
      final bytes = encodeBackup(kFullBackupMagic, sample);
      expect(looksLikeBackupEnvelope(bytes), isTrue);
      expect(() => decodeBackup(bytes), returnsNormally);
    });

    test('kAllBackupMagics 三格式齐全', () {
      expect(kAllBackupMagics, hasLength(3));
      expect(kAllBackupMagics, containsAll(<List<int>>[
        kGroupBackupMagic, kTripBackupMagic, kFullBackupMagic,
      ]));
    });

    test('显式传参能力保留：只接受 TA1G 时 TA1T 被拒', () {
      final trip = encodeBackup(kTripBackupMagic, sample);
      expect(looksLikeBackupEnvelope(trip, acceptedMagics: [kGroupBackupMagic]), isFalse);
      expect(() => decodeBackup(trip, acceptedMagics: [kGroupBackupMagic]),
          throwsA(isA<FormatException>()));
    });
  });

  group('四负例（均抛 FormatException）', () {
    test('长度不足 10 字节', () {
      expect(() => decodeBackup(Uint8List(5)),
          throwsA(isA<FormatException>()));
    });

    test('魔数不匹配', () {
      final bytes = encodeBackup(kGroupBackupMagic, sample);
      bytes[0] = 0x58; // 'X'
      expect(() => decodeBackup(bytes), throwsA(isA<FormatException>()));
    });

    test('版本不支持', () {
      final bytes = encodeBackup(kGroupBackupMagic, sample);
      bytes[4] = 9;
      expect(() => decodeBackup(bytes), throwsA(isA<FormatException>()));
    });

    test('payload 长度不匹配', () {
      final bytes = encodeBackup(kGroupBackupMagic, sample);
      // 把长度字段改大 100 → 实际字节不足
      final bd = ByteData.sublistView(bytes);
      bd.setUint32(6, bytes.length + 100, Endian.big);
      expect(() => decodeBackup(bytes), throwsA(isA<FormatException>()));
    });
  });
}
