// L1-P0 文案令牌表完整性（§4.1）：id 唯一、text 非空、无占位残留。
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_assistant/shared/copy_tokens.dart';

void main() {
  test('L1-P0 copy token：id 唯一', () {
    final ids = allCopyTokens.map((t) => t.id).toList();
    expect(ids.length, ids.toSet().length, reason: '存在重复 id');
  });

  test('L1-P0 copy token：text 非空且无 TODO/占位残留', () {
    for (final t in allCopyTokens) {
      expect(t.text.trim(), isNotEmpty, reason: '${t.id} 文案为空');
      expect(t.text.contains('TODO'), isFalse, reason: '${t.id} 含 TODO');
      expect(t.text.contains('{{'), isFalse, reason: '${t.id} 含占位符');
      expect(t.text.contains('刚写'), isFalse, reason: '${t.id} 含残留');
    }
  });

  test('L1-P0 copy()：8 品牌触点 id 可取；缺 id 抛断言', () {
    // 8 触点全部命中
    final touchIds = [
      CopyTokens.splashSubtitle,
      CopyTokens.profileQuotesNote,
      CopyTokens.tripsEmpty,
      CopyTokens.tripsEmptyAction,
      CopyTokens.ledgerEmpty,
      CopyTokens.ledgerEmptyAction,
      CopyTokens.checklistEmpty,
      CopyTokens.exportDone,
      CopyTokens.shareDone,
      CopyTokens.cloudLoginIntro,
      CopyTokens.themeSubtitle,
    ];
    for (final id in touchIds) {
      expect(copy(id), isNot(id), reason: '$id 缺失（copy 返回了 id 本身）');
    }
  });
}
