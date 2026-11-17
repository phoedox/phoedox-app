// Interactive blocks (poll, decision matrix, calculator, quiz): the same
// source format as the web (web/src/blocks/*.ts) and the server checks
// (internal/blocks/interactive.go). Parsing only, no widgets.

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
      // A flag on its own line: "multiple" or "closed".
      if (l.toLowerCase() == 'multiple') {
        multiple = true;
        continue;
      }
      if (l.toLowerCase() == 'closed') {
        closed = true;
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
