import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/features/desktop/sync/sync_code.dart';

/// 不可压缩随机串（避免 gzip 后码过短）。
String _randomHex(int n) {
  final r = Random(42);
  const chars = '0123456789abcdef';
  return List.generate(n, (_) => chars[r.nextInt(16)]).join();
}

void main() {
  group('encodeSyncCode / decodeSyncCode', () {
    test('往返一致（中文 + 长内容）', () {
      final json = '{"app":"t","name":"关西之行","note":"¥&中文,含引号\\"x\\""}';
      final code = encodeSyncCode(json);
      expect(code, isNot(contains(json)), reason: '同步码不应暴露明文');
      expect(decodeSyncCode(code), json);
    });

    test('非法输入抛 FormatException', () {
      expect(() => decodeSyncCode('!@#not-base64'), throwsFormatException);
      expect(() => decodeSyncCode(''), throwsFormatException);
      expect(() => decodeSyncCode('   '), throwsFormatException);
    });
  });

  group('chunkSyncCode / combineChunks', () {
    test('小内容不分块可往返', () {
      final json = '{"a":1}';
      final code = encodeSyncCode(json);
      final chunks = chunkSyncCode(code);
      expect(chunks.length, 1);
      expect(combineChunks(chunks), code);
    });

    test('超长内容分多块并按序合并', () {
      final big = _randomHex(8000);
      final code = encodeSyncCode('{"data":"$big"}');
      final chunks = chunkSyncCode(code);
      expect(chunks.length, greaterThan(1));
      expect(combineChunks(chunks.reversed.toList()), code,
          reason: '合并不依赖输入顺序');
    });

    test('缺失块抛 StateError', () {
      final big = _randomHex(8000);
      final code = encodeSyncCode('{"data":"$big"}');
      final chunks = chunkSyncCode(code);
      expect(() => combineChunks(chunks.sublist(0, chunks.length - 1)),
          throwsStateError);
    });

    test('parseChunk 解析正确 / 非分块返回 null', () {
      final parsed = parseChunk('TSQ1|3|2|abc');
      expect(parsed, (3, 2, 'abc'));
      expect(parseChunk('随便一段文本'), isNull);
      expect(parseChunk('TSQ1|x|y|z'), isNull);
    });

    test('syncCodeFitsQr 判定', () {
      expect(syncCodeFitsQr(encodeSyncCode('{"a":1}')), isTrue);
      final huge = encodeSyncCode('{"data":"${_randomHex(30000)}"}');
      expect(syncCodeFitsQr(huge), isFalse);
    });
  });
}
