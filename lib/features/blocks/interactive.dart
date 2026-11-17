// Interactive blocks (poll, decision matrix, calculator, quiz): the same
// source format as the web (web/src/blocks/*.ts) and the server checks
// (internal/blocks/interactive.go). Parsing only, no widgets.

import 'formula.dart';

/// Lines of a block: trimmed, without empty lines and # comments.
List<String> blockLines(String src) => [
      for (final l in src.replaceAll('\r\n', '\n').split('\n'))
        if (l.trim().isNotEmpty && !l.trim().startsWith('#')) l.trim()
    ];

/// "key: value" at the start of a line, for known keys only.
(String, String)? keyValue(String line, List<String> keys) {
  final m = RegExp(r'^([A-Za-z]+)\s*:\s*(.*)$').firstMatch(line);
  if (m == null || !keys.contains(m[1]!.toLowerCase())) return null;
  return (m[1]!.toLowerCase(), m[2]!.trim());
}

bool _yes(String v) =>
    RegExp(r'^(true|yes|ja|1|on)$', caseSensitive: false).hasMatch(v.trim());

/// The state key of a block: its own id, else a hash of its source (FNV-1a
/// over UTF-16 code units, like hashText in web/src/blocks/registry.ts).
String blockKey(String source, [String? id]) {
  if (id != null && RegExp(r'^[A-Za-z0-9-]{1,40}$').hasMatch(id)) return id;
  var h = 2166136261;
  for (final c in source.trim().codeUnits) {
    h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
  }
  return 'h${h.toRadixString(36)}';
}

// --- poll -------------------------------------------------------------------

class Poll {
  Poll(this.question, this.options,
      {this.multiple = false,
      this.closed = false,
      this.resultsAlways = false,
      this.id});

  final String question;
  final List<String> options;
  final bool multiple, closed, resultsAlways;
  final String? id;

  static Poll parse(String src) {
    var q = '';
    final opts = <String>[];
    var multiple = false, closed = false, always = false;
    String? id;
    for (final l in blockLines(src)) {
      final kv = keyValue(
          l, ['question', 'frage', 'multiple', 'closed', 'results', 'id']);
      if (kv != null) {
        switch (kv.$1) {
          case 'question' || 'frage':
            q = kv.$2;
          case 'multiple':
            multiple = _yes(kv.$2);
          case 'closed':
            closed = _yes(kv.$2);
          case 'results':
            always =
                RegExp(r'always|immer', caseSensitive: false).hasMatch(kv.$2);
          case 'id':
            id = kv.$2;
        }
        continue;
      }
      final o = RegExp(r'^[-*+]\s+(.+)$').firstMatch(l);
      if (o != null) {
        opts.add(o[1]!.trim());
      } else if (q.isEmpty) {
        q = l;
      }
    }
    if (q.isEmpty) throw const FormatException('poll.err_question');
    if (opts.length < 2) throw const FormatException('poll.err_options');
    if (opts.length > 30) throw const FormatException('poll.err_too_many');
    if (opts.toSet().length != opts.length) {
      throw const FormatException('poll.err_duplicate');
    }
    return Poll(q, opts,
        multiple: multiple, closed: closed, resultsAlways: always, id: id);
  }

  /// The share of one option: of the people who voted when several answers
  /// are allowed, else of all votes.
  double share(String option, Map<String, int> votes, int voters) {
    final base = multiple ? voters : votes.values.fold<int>(0, (a, b) => a + b);
    return base == 0 ? 0 : (votes[option] ?? 0) / base;
  }
}

// --- decision matrix ----------------------------------------------------------

class Criterion {
  const Criterion(this.name, this.weight);
  final String name;
  final double weight;
}

class MatrixOption {
  const MatrixOption(this.name, this.scores);
  final String name;
  final List<double> scores;
}

class Matrix {
  Matrix(this.title, this.criteria, this.options, this.max);

  final String title;
  final List<Criterion> criteria;
  final List<MatrixOption> options;
  final double max;

  static double _n(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? double.nan;

  static Matrix parse(String src) {
    var title = '';
    final crit = <Criterion>[];
    final opts = <MatrixOption>[];
    var scaleMax = 0.0;
    for (final l in blockLines(src)) {
      final kv = keyValue(
          l, ['title', 'titel', 'criteria', 'kriterien', 'scale', 'skala']);
      if (kv != null) {
        switch (kv.$1) {
          case 'title' || 'titel':
            title = kv.$2;
          case 'scale' || 'skala':
            final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*$').firstMatch(kv.$2);
            scaleMax = m == null ? 0 : _n(m[1]!);
          default:
            crit.clear();
            for (final c in kv.$2.split(',')) {
              final t = c.trim();
              if (t.isEmpty) continue;
              final w =
                  RegExp(r'^(.*?)\s*[*×x]\s*(\d+(?:[.,]\d+)?)$').firstMatch(t);
              crit.add(w == null
                  ? Criterion(t, 1)
                  : Criterion(w[1]!.trim(), _n(w[2]!)));
            }
        }
        continue;
      }
      final o = RegExp(r'^[-*+]\s+(.+?)\s*:\s*(.+)$').firstMatch(l);
      if (o == null) continue;
      final scores = o[2]!.split(RegExp(r'[,;]')).map(_n).toList();
      if (scores.any((x) => x.isNaN)) {
        throw const FormatException('matrix.err_score');
      }
      opts.add(MatrixOption(o[1]!, scores));
    }
    if (crit.isEmpty) throw const FormatException('matrix.err_criteria');
    if (opts.length < 2) throw const FormatException('matrix.err_options');
    if (opts.any((o) => o.scores.length != crit.length)) {
      throw const FormatException('matrix.err_count');
    }
    var max = scaleMax;
    if (max <= 0) {
      max = 5;
      for (final o in opts) {
        for (final s in o.scores) {
          if (s > max) max = s;
        }
      }
    }
    return Matrix(title, crit, opts, max);
  }

  /// Each option's share of the best possible result (0–1).
  List<double> scores([List<double>? weights]) {
    final w = weights ?? [for (final c in criteria) c.weight];
    var wsum = w.fold<double>(0, (a, b) => a + b);
    if (wsum == 0) wsum = 1;
    return [
      for (final o in options)
        [
              for (var i = 0; i < o.scores.length; i++)
                o.scores[i] * (i < w.length ? w[i] : 0)
            ].fold<double>(0, (a, b) => a + b) /
            (wsum * max)
    ];
  }
}

// --- calculator -----------------------------------------------------------------

class CalcRow {
  CalcRow(this.label, this.name, this.unit, this.expr,
      {this.input = false, this.value, this.entity, this.attr});

  final String label, name, unit, expr;
  final bool input;
  double? value;

  /// An entry's attribute as input (`= @slug.attr`).
  final String? entity, attr;
}

/// "Kosten pro Jahr (€)" → name "Kosten_pro_Jahr", unit "€".
({String name, String unit}) calcName(String label) {
  final m = RegExp(r'^(.*?)\s*\(([^)]*)\)\s*$').firstMatch(label);
  final base = (m != null ? m[1]! : label).trim();
  return (
    name: base
        .replaceAll(RegExp(r'[^\p{L}\p{N}_]+', unicode: true), '_')
        .replaceAll(RegExp(r'^_+|_+$'), ''),
    unit: m != null ? m[2]!.trim() : ''
  );
}

class Calc {
  Calc(this.title, this.rows);

  final String title;
  final List<CalcRow> rows;

  static final _number = RegExp(r'^-?\d[\d ]*(?:[.,]\d+)?$');

  static Calc parse(String src) {
    var title = '';
    final rows = <CalcRow>[];
    for (final l in blockLines(src)) {
      final kv = keyValue(l, ['title', 'titel']);
      if (kv != null) {
        title = kv.$2;
        continue;
      }
      final i = l.indexOf('=');
      if (i <= 0) throw const FormatException('calc.err_line');
      final label = l.substring(0, i).trim(), expr = l.substring(i + 1).trim();
      final n = calcName(label);
      if (n.name.isEmpty || expr.isEmpty) {
        throw const FormatException('calc.err_line');
      }
      if (rows.any((r) => r.name == n.name)) {
        throw const FormatException('calc.err_duplicate');
      }
      final ent = RegExp(r'^@([a-z0-9-]+)\.([A-Za-z0-9_]+)$').firstMatch(expr);
      if (_number.hasMatch(expr)) {
        rows.add(CalcRow(label, n.name, n.unit, expr,
            input: true,
            value:
                double.parse(expr.replaceAll(' ', '').replaceAll(',', '.'))));
      } else if (ent != null) {
        rows.add(CalcRow(label, n.name, n.unit, expr,
            input: true, entity: ent[1], attr: ent[2]));
      } else {
        try {
          formulaTokens(expr);
        } on FormulaError {
          throw const FormatException('calc.err_formula');
        }
        rows.add(CalcRow(label, n.name, n.unit, expr));
      }
    }
    if (rows.isEmpty) throw const FormatException('calc.err_empty');
    final names = {for (final r in rows) r.name};
    for (final r in rows) {
      if (!r.input && formulaNames(r.expr).any((n) => !names.contains(n))) {
        throw const FormatException('calc.err_unknown');
      }
    }
    final c = Calc(title, rows);
    if (c
        .values(const {})
        .values
        .any((v) => v is FormulaError && v.code == 'cycle')) {
      throw const FormatException('calc.err_cycle');
    }
    return c;
  }

  /// All values: inputs (overridden by the reader) and formulas; errors as
  /// [FormulaError].
  Map<String, Object?> values(Map<String, double> inputs) {
    final out = <String, Object?>{};
    final byName = {for (final r in rows) r.name: r};
    final busy = <String>{};
    Object? get(String name) {
      if (out.containsKey(name)) {
        final v = out[name];
        if (v is FormulaError) throw v;
        return v;
      }
      final r = byName[name];
      if (r == null) throw const FormulaError('name');
      if (busy.contains(name)) throw const FormulaError('cycle');
      busy.add(name);
      try {
        final v =
            r.input ? (inputs[name] ?? r.value ?? 0) : evaluate(r.expr, get);
        out[name] = v;
        return v;
      } on FormulaError catch (e) {
        out[name] = e;
        rethrow;
      } catch (_) {
        out[name] = const FormulaError('value');
        throw const FormulaError('value');
      } finally {
        busy.remove(name);
      }
    }

    for (final r in rows) {
      try {
        get(r.name);
      } on FormulaError {
        // kept in out
      }
    }
    return out;
  }
}

/// A value as text: numbers with at most 2 decimals (none from 100 on),
/// decimal comma for German.
String formatValue(Object? v, [String lang = 'de']) {
  if (v is FormulaError) {
    return switch (v.code) {
      'div0' => '#DIV/0',
      'cycle' => lang == 'de' ? '#ZYKLUS' : '#CYCLE',
      _ => lang == 'de' ? '#FEHLER' : '#ERROR',
    };
  }
  if (v is bool) return v ? '✓' : '✗';
  if (v is num) {
    if (v.isNaN || v.isInfinite) return lang == 'de' ? '#FEHLER' : '#ERROR';
    final digits = v.abs() >= 100 ? 0 : 2;
    var s = v.toStringAsFixed(digits);
    if (s.contains('.')) s = s.replaceAll(RegExp(r'\.?0+$'), '');
    final neg = s.startsWith('-');
    if (neg) s = s.substring(1);
    final parts = s.split('.');
    final group = lang == 'de' ? '.' : ',';
    final whole = parts[0]
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => group);
    final out = parts.length > 1
        ? '$whole${lang == 'de' ? ',' : '.'}${parts[1]}'
        : whole;
    return neg && out != '0' ? '-$out' : out;
  }
  return '${v ?? ''}';
}

// --- quiz -------------------------------------------------------------------------

class QuizQuestion {
  QuizQuestion(this.q);
  final String q;
  final options = <({String text, bool right})>[];
  String? answer, explain;
}

class Quiz {
  Quiz(this.title, this.questions, this.id);

  final String title;
  final List<QuizQuestion> questions;
  final String? id;

  static Quiz parse(String src) {
    var title = '';
    String? id;
    final qs = <QuizQuestion>[];
    QuizQuestion? cur;
    for (final raw in src.replaceAll('\r\n', '\n').split('\n')) {
      final l = raw.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final kv = cur == null ? keyValue(l, ['title', 'titel', 'id']) : null;
      if (kv != null) {
        if (kv.$1 == 'id') {
          id = kv.$2;
        } else {
          title = kv.$2;
        }
        continue;
      }
      final m = RegExp(r'^([?+\-=>])\s*(.*)$').firstMatch(l);
      if (m == null) throw const FormatException('quiz.err_line');
      final text = m[2]!;
      if (m[1] == '?') {
        cur = QuizQuestion(text);
        qs.add(cur);
        continue;
      }
      if (cur == null) throw const FormatException('quiz.err_line');
      switch (m[1]) {
        case '+' || '-':
          cur.options.add((text: text, right: m[1] == '+'));
        case '=':
          cur.answer = text;
        default:
          cur.explain = cur.explain == null ? text : '${cur.explain} $text';
      }
    }
    if (qs.isEmpty) throw const FormatException('quiz.err_empty');
    for (final q in qs) {
      if (q.options.isEmpty && q.answer == null) {
        throw const FormatException('quiz.err_answers');
      }
      if (q.options.isNotEmpty && !q.options.any((o) => o.right)) {
        throw const FormatException('quiz.err_right');
      }
    }
    return Quiz(title, qs, id);
  }

  /// Right answers so far; an answer is an option index, "known" or "unknown".
  int right(Map<String, Object?> answers) {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      final a = answers['$i'];
      if (a == 'known' ||
          (a is num &&
              a.toInt() < questions[i].options.length &&
              questions[i].options[a.toInt()].right)) {
        n++;
      }
    }
    return n;
  }
}
