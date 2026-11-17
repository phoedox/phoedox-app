// Formulas of calculator blocks, the same rules as web/src/formula.ts:
// numbers, text in quotes, names of other values, + - * / ^ & %,
// comparisons and a few functions – without eval.

import 'dart:math' as math;

class FormulaError implements Exception {
  const FormulaError(this.code);

  /// syntax, name, value, div0 or cycle.
  final String code;

  @override
  String toString() => 'FormulaError($code)';
}

double _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v == null || v == '') return 0;
  final n = double.tryParse('$v');
  if (n == null) throw const FormulaError('value');
  return n;
}

List<double> _nums(List<Object?> a) => [
      for (final v in a)
        if (v is num)
          v.toDouble()
        else if (v is String && double.tryParse(v) != null)
          double.parse(v)
    ];

bool _truthy(Object? v) => v is String
    ? v.isNotEmpty && v.toUpperCase() != 'FALSE'
    : v is num
        ? v != 0
        : v == true;

double _round(double x, num d) {
  final f = math.pow(10, d.toInt()).toDouble();
  return (x * f).round() / f;
}

final Map<String, Object? Function(List<Object?>)> _funcs = {
  'SUM': (a) => _nums(a).fold<double>(0, (x, y) => x + y),
  'AVERAGE': (a) {
    final n = _nums(a);
    return n.isEmpty ? 0.0 : n.fold<double>(0, (x, y) => x + y) / n.length;
  },
  'MIN': (a) => _nums(a).fold<double>(double.infinity, (x, y) => x < y ? x : y),
  'MAX': (a) =>
      _nums(a).fold<double>(double.negativeInfinity, (x, y) => x > y ? x : y),
  'ROUND': (a) =>
      _round(_num(a.isNotEmpty ? a[0] : 0), a.length > 1 ? _num(a[1]) : 0),
  'CEIL': (a) => _num(a.isNotEmpty ? a[0] : 0).ceilToDouble(),
  'FLOOR': (a) => _num(a.isNotEmpty ? a[0] : 0).floorToDouble(),
  'ABS': (a) => _num(a.isNotEmpty ? a[0] : 0).abs(),
  'SQRT': (a) {
    final x = _num(a.isNotEmpty ? a[0] : 0);
    return math.sqrt(x);
  },
  'IF': (a) => _truthy(a.isNotEmpty ? a[0] : null)
      ? (a.length > 1 ? a[1] : '')
      : (a.length > 2 ? a[2] : ''),
};

typedef FormulaToken = ({String t, Object v});

final _ws = RegExp(r'^\s+');
final _numRe = RegExp(r'^\d+(?:[.,]\d+)?');
final _strRe = RegExp(r'^"([^"]*)"');
final _fnRe = RegExp(r'^[\p{L}_][\p{L}\p{N}_]*(?=\s*\()', unicode: true);
final _nameRe = RegExp(r'^[\p{L}_][\p{L}\p{N}_]*', unicode: true);
final _opRe = RegExp(r'^(<=|>=|<>|[-+*/^&(),;=<>%])');

List<FormulaToken> formulaTokens(String src) {
  final out = <FormulaToken>[];
  var i = 0;
  while (i < src.length) {
    final rest = src.substring(i);
    RegExpMatch? m;
    if ((m = _ws.firstMatch(rest)) != null) {
      i += m!.group(0)!.length;
      continue;
    }
    if ((m = _numRe.firstMatch(rest)) != null) {
      out.add((t: 'num', v: double.parse(m!.group(0)!.replaceAll(',', '.'))));
    } else if ((m = _strRe.firstMatch(rest)) != null) {
      out.add((t: 'str', v: m!.group(1)!));
    } else if ((m = _fnRe.firstMatch(rest)) != null &&
        _funcs.containsKey(m!.group(0)!.toUpperCase())) {
      out.add((t: 'fn', v: m.group(0)!.toUpperCase()));
    } else if ((m = _nameRe.firstMatch(rest)) != null) {
      out.add((t: 'name', v: m!.group(0)!));
    } else if ((m = _opRe.firstMatch(rest)) != null) {
      out.add((t: 'op', v: m!.group(0) == ';' ? ',' : m.group(0)!));
    } else {
      throw const FormulaError('syntax');
    }
    i += m.group(0)!.length;
  }
  return out;
}

/// The names a formula uses.
List<String> formulaNames(String src) => {
      for (final t in formulaTokens(src))
        if (t.t == 'name') t.v as String
    }.toList();

/// Evaluates a formula; [get] gives another value (throws FormulaError('name')
/// if unknown).
Object? evaluate(String src, Object? Function(String name) get) {
  final ts = formulaTokens(src);
  var p = 0;
  FormulaToken? peek() => p < ts.length ? ts[p] : null;
  FormulaToken? take() => p < ts.length ? ts[p++] : null;
  void expect(String v) {
    final t = take();
    if (t == null || t.v != v) throw const FormulaError('syntax');
  }

  late Object? Function() compare;
  late Object? Function() power;

  Object? primary() {
    final t = take();
    if (t == null) throw const FormulaError('syntax');
    if (t.t == 'num' || t.t == 'str') return t.v;
    if (t.t == 'name') return get(t.v as String);
    if (t.t == 'fn') {
      expect('(');
      final args = <Object?>[];
      if (peek()?.v != ')') {
        do {
          args.add(compare());
        } while (peek()?.v == ',' && take() != null);
      }
      expect(')');
      return _funcs[t.v]!(args);
    }
    if (t.v == '(') {
      final v = compare();
      expect(')');
      return v;
    }
    if (t.v == '-') return -_num(power());
    if (t.v == '+') return _num(power());
    throw const FormulaError('syntax');
  }

  Object? percent() {
    var v = primary();
    while (peek()?.v == '%') {
      take();
      v = _num(v) / 100;
    }
    return v;
  }

  power = () {
    var v = percent();
    while (peek()?.v == '^') {
      take();
      final r = _num(percent());
      v = math.pow(_num(v), r).toDouble();
    }
    return v;
  };

  Object? term() {
    var v = power();
    while (peek()?.v == '*' || peek()?.v == '/') {
      final o = take()!.v;
      final r = _num(power());
      if (o == '/' && r == 0) throw const FormulaError('div0');
      v = o == '*' ? _num(v) * r : _num(v) / r;
    }
    return v;
  }

  Object? sum() {
    var v = term();
    while (peek()?.v == '+' || peek()?.v == '-' || peek()?.v == '&') {
      final o = take()!.v;
      final r = term();
      v = o == '&'
          ? '${_text(v)}${_text(r)}'
          : o == '+'
              ? _num(v) + _num(r)
              : _num(v) - _num(r);
    }
    return v;
  }

  compare = () {
    var v = sum();
    const ops = ['=', '<>', '<', '>', '<=', '>='];
    while (ops.contains(peek()?.v)) {
      final o = take()!.v;
      final r = sum();
      if (v is num || r is num) {
        final x = _num(v), y = _num(r);
        v = switch (o) {
          '=' => x == y,
          '<>' => x != y,
          '<' => x < y,
          '>' => x > y,
          '<=' => x <= y,
          _ => x >= y,
        };
      } else {
        final c = '$v'.compareTo('$r');
        v = switch (o) {
          '=' => c == 0,
          '<>' => c != 0,
          '<' => c < 0,
          '>' => c > 0,
          '<=' => c <= 0,
          _ => c >= 0,
        };
      }
    }
    return v;
  };

  final v = compare();
  if (p < ts.length) throw const FormulaError('syntax');
  return v;
}

String _text(Object? v) {
  if (v is double && v == v.truncateToDouble() && v.abs() < 1e15) {
    return v.toInt().toString();
  }
  return '${v ?? ''}';
}
