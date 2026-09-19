/// V2.8.1 S5：记一笔连算表达式（纯 Dart，无 IO 无时钟直读）。
///
/// 仅支持 `+ −` 与十进制金额，单位分。规则：
/// * 运算符出现在开头 / 连续 / 结尾 → 忽略该非法键；
/// * 小数位 ≤2（分域截断）；单个金额与合计上限 99,999,999 分；
/// * [totalFen] 为 null 表示当前无有效数值；[display] 为原样表达式（如 "58+32"）。
library;

enum MoneyOp { add, subtract }

class MoneyExpression {
  /// 展示段（操作数与运算符交错）；操作数以「原始输入串」保存。
  final List<String> _terms = [];
  final Set<MoneyOp> _ops = <MoneyOp>{};

  bool get _currentIsNumber =>
      _terms.isNotEmpty && _terms.length == _ops.length + 1;

  /// 当前正在输入的操作数是否已含小数点
  bool get _currentHasDot => _currentIsNumber && _terms.last.contains('.');

  /// 当前操作数的小数位数
  int get _currentDecimals {
    if (!_currentHasDot) return 0;
    return _terms.last.split('.').last.length;
  }

  void pushDigit(int d) {
    if (d < 0 || d > 9) return;
    final cur = _currentIsNumber ? _terms.last : null;
    if (cur != null) {
      if (cur == '0' && d == 0) return; // 前导零
      if (_currentDecimals >= 2) return; // 小数位 ≤2
      final candidate = cur == '0' ? '$d' : cur + '$d';
      final fen = _parseFen(candidate);
      // 上限保护：单笔 99,999,999 分（约 99.99 万元）
      if (fen == null || fen > _maxFen) return;
      _terms[_terms.length - 1] = candidate;
    } else {
      _terms.add('$d');
    }
  }

  void pushOp(MoneyOp op) {
    // 开头 / 连续运算符 / 覆盖末尾运算符：仅当存在一个完整操作数时合法
    if (_currentIsNumber && _parseFen(_terms.last) != null) {
      _ops.add(op);
    }
  }

  void pushDot() {
    if (!_currentIsNumber) {
      _terms.add('0.'); // 表达式开头的 ".5" → "0.5"
      return;
    }
    if (_currentHasDot) return; // 已有小数点
    _terms[_terms.length - 1] = '${_terms.last}.';
  }

  void backspace() {
    if (_terms.isEmpty) return;
    if (_terms.length == _ops.length) {
      // 末尾是运算符：删运算符
      _ops.remove(_ops.last);
      return;
    }
    final cur = _terms.last;
    if (cur.length <= 1) {
      _terms.removeLast();
    } else {
      _terms[_terms.length - 1] = cur.substring(0, cur.length - 1);
    }
  }

  void clear() {
    _terms.clear();
    _ops.clear();
  }

  /// 实时合计（分）：无有效数值 → null。
  int? get totalFen {
    if (_terms.isEmpty || _terms.length != _ops.length + 1) return null;
    final acc = <int>[];
    for (var i = 0; i < _terms.length; i++) {
      final fen = _parseFen(_terms[i]);
      if (fen == null || fen > _maxFen) return null;
      if (i == 0) {
        acc.add(fen);
      } else {
        final op = _ops.elementAt(i - 1);
        final prev = acc.last;
        final next = op == MoneyOp.add ? prev + fen : prev - fen;
        if (next > _maxFen || next < -_maxFen) return null;
        acc.add(next);
      }
    }
    return acc.isEmpty ? null : acc.last;
  }

  /// 原样表达式展示（"58+32"）；操作数去掉无意义的尾点。
  String get display {
    final buf = StringBuffer();
    for (var i = 0; i < _terms.length; i++) {
      var term = _terms[i];
      if (term.endsWith('.')) term = term.substring(0, term.length - 1);
      if (i > 0) {
        buf.write(_ops.elementAt(i - 1) == MoneyOp.add ? '+' : '−');
      }
      buf.write(term);
    }
    return buf.toString();
  }

  bool get isEmpty => _terms.isEmpty;

  /// 从既有金额文本恢复（编辑模式回填口径：元字符串）。
  void setText(String yuanText) {
    clear();
    final fen = _parseFen(yuanText);
    if (fen == null) return;
    _terms.add(_fenToOperand(fen));
  }

  static const int _maxFen = 99999999;

  /// 元字符串 → 分（≤2 位小数；非法 → null）。
  static int? _parseFen(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (m == null) return null;
    final yuan = int.parse(m.group(1)!);
    final dec = m.group(2) ?? '';
    final fen = dec.isEmpty
        ? 0
        : dec.length == 1
            ? int.parse(dec) * 10
            : int.parse(dec);
    return yuan * 100 + fen;
  }

  static String _fenToOperand(int fen) {
    final yuan = fen ~/ 100;
    final rest = fen % 100;
    return rest == 0 ? '$yuan' : '$yuan.${rest.toString().padLeft(2, '0')}';
  }
}
