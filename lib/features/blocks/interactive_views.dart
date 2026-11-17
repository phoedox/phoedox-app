import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../charts/chart.dart';
import '../doc/doc_page.dart';
import 'blocks.dart';
import 'formula.dart';
import 'interactive.dart';

/// The per-reader state of a block (block_states on the server).
String blockStatePath(BlockCtx c, String key) =>
    '/projects/${c.project}/documents/${Uri.encodeComponent(c.doc)}/blocks/${Uri.encodeComponent(key)}';

class _Frame extends StatelessWidget {
  const _Frame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

Widget _title(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));

// --- poll -------------------------------------------------------------------------

class PollView extends ConsumerStatefulWidget {
  const PollView(
      {super.key, required this.poll, required this.ctx, required this.source});
  final Poll poll;
  final BlockCtx ctx;
  final String source;

  @override
  ConsumerState<PollView> createState() => _PollViewState();
}

class _PollViewState extends ConsumerState<PollView> {
  List<String> _mine = [];
  Map<String, int> _votes = {};
  int _voters = 0;
  bool _busy = false;
  Timer? _timer;

  String get _key => widget.ctx.key ?? blockKey(widget.source, widget.poll.id);
  bool get _remote =>
      widget.ctx.project.isNotEmpty && widget.ctx.doc.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    // Others vote too: look again now and then.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _apply(Object? r) {
    if (r is! Map || !mounted) return;
    final mine = r['mine'];
    setState(() {
      _mine = [
        if (mine is Map && mine['choices'] is List)
          for (final c in mine['choices'] as List)
            if (widget.poll.options.contains(c)) c as String
      ];
      _votes = {
        if (r['votes'] is Map)
          for (final e in (r['votes'] as Map).entries)
            '${e.key}': (e.value as num).toInt()
      };
      _voters = (r['voters'] as num?)?.toInt() ?? 0;
    });
  }

  Future<void> _load() async {
    if (!_remote) return;
    try {
      final c = await ref.read(clientProvider.future);
      _apply((await c?.get(blockStatePath(widget.ctx, _key)))?.data);
    } catch (_) {
      // keep what is shown
    }
  }

  Future<void> _vote(String? option) async {
    final p = widget.poll;
    List<String>? next;
    if (option != null) {
      next = p.multiple
          ? (_mine.contains(option)
              ? [..._mine.where((x) => x != option)]
              : [..._mine, option])
          : [option];
      if (next.isEmpty) next = null;
    }
    setState(() => _busy = true);
    final t = AppLocalizations.of(context);
    try {
      final c = await ref.read(clientProvider.future);
      _apply(await c?.send('PUT', blockStatePath(widget.ctx, _key), {
        'data': next == null ? null : {'choices': next}
      }));
    } on OfflineException {
      if (mounted) _snack(context, t.blockOffline);
    } catch (_) {
      if (mounted) _snack(context, t.blockSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final p = widget.poll;
    final show = p.closed || p.resultsAlways || _mine.isNotEmpty;
    final canVote = !p.closed && _remote && !_busy;
    final style = ChartStyle.of(context);
    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(context, p.question),
        for (final o in p.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Semantics(
              checked: _mine.contains(o),
              inMutuallyExclusiveGroup: !p.multiple,
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color:
                            _mine.contains(o) ? cs.primary : cs.outlineVariant,
                        width: _mine.contains(o) ? 2 : 1)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: canVote ? () => _vote(o) : null,
                  child: Stack(children: [
                    if (show)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: p.share(o, _votes, _voters).clamp(0, 1),
                          child: ColoredBox(color: style.tb('blue')),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Icon(
                            p.multiple
                                ? (_mine.contains(o)
                                    ? LucideIcons.squareCheck
                                    : LucideIcons.square)
                                : (_mine.contains(o)
                                    ? LucideIcons.circleDot
                                    : LucideIcons.circle),
                            size: 18,
                            color: _mine.contains(o)
                                ? cs.primary
                                : cs.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(child: Text(o)),
                        if (show)
                          Text(
                              '${_votes[o] ?? 0} · ${(p.share(o, _votes, _voters) * 100).round()} %',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        Row(children: [
          Expanded(
            child: Text(
              p.closed
                  ? t.pollClosed
                  : show
                      ? t.pollVoters(_voters)
                      : (p.multiple ? t.pollChooseMany : t.pollChooseOne),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          if (_mine.isNotEmpty && canVote)
            TextButton(onPressed: () => _vote(null), child: Text(t.pollUndo)),
        ]),
      ]),
    );
  }
}

void paintPoll(Canvas canvas, Rect r, Poll p, ChartStyle s) {
  _paintText(canvas, p.question, r.topLeft + const Offset(6, 2), r.width - 12,
      15, s.fg,
      bold: true);
  final row = ((r.height - 34) / p.options.length).clamp(22.0, 40.0);
  for (var i = 0; i < p.options.length; i++) {
    final y = r.top + 34 + i * row;
    if (y + row - 6 > r.bottom) break;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + 6, y, r.width - 12, row - 6),
            const Radius.circular(6)),
        Paint()..color = s.line.withValues(alpha: 0.5));
    _paintText(canvas, p.options[i], Offset(r.left + 16, y + (row - 6) / 2 - 8),
        r.width - 32, 13, s.fg);
  }
}

// --- decision matrix -----------------------------------------------------------

class MatrixView extends ConsumerStatefulWidget {
  const MatrixView({super.key, required this.matrix, required this.ctx});
  final Matrix matrix;
  final BlockCtx ctx;

  @override
  ConsumerState<MatrixView> createState() => _MatrixViewState();
}

class _MatrixViewState extends ConsumerState<MatrixView> {
  late List<double> _weights = [
    for (final c in widget.matrix.criteria) c.weight
  ];
  bool _tuning = false;

  String _n(double v) =>
      formatValue(v, Localizations.localeOf(context).languageCode);

  Future<void> _toDecision() async {
    final t = AppLocalizations.of(context);
    final m = widget.matrix;
    final scores = m.scores(_weights);
    try {
      final c = await ref.read(clientProvider.future);
      final r =
          await c?.send('POST', '/projects/${widget.ctx.project}/documents', {
        'type': 'adr',
        'title': m.title.isEmpty ? t.matrixDecisionTitle : m.title,
        'adr': {
          'status': 'proposed',
          'context': t.matrixDecisionContext,
          'options': [
            for (var i = 0; i < m.options.length; i++)
              {
                'title': m.options[i].name,
                'description': '${[
                  for (var j = 0; j < m.criteria.length; j++)
                    '- ${m.criteria[j].name} (× ${_n(_weights[j])}): ${_n(m.options[i].scores[j])}'
                ].join('\n')}\n\n**${t.matrixTotal}: ${(scores[i] * 100).round()} %**',
              }
          ],
        },
      });
      if (!mounted) return;
      _snack(context, t.matrixDecisionMade);
      final slug =
          r is Map && r['document'] is Map ? r['document']['slug'] : null;
      if (slug is String) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DocPage(project: widget.ctx.project, doc: slug)));
      }
    } on OfflineException {
      if (mounted) _snack(context, t.blockOffline);
    } catch (_) {
      if (mounted) _snack(context, t.matrixDecisionFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final m = widget.matrix;
    final scores = m.scores(_weights);
    final best = scores.reduce((a, b) => a > b ? a : b);
    final changed = [
      for (var i = 0; i < _weights.length; i++)
        _weights[i] != m.criteria[i].weight
    ].any((x) => x);
    final muted = TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5);
    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.title.isNotEmpty) _title(context, m.title),
        // The ranking first: it is what people look for on a phone.
        for (var i = 0; i < m.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: Text(m.options[i].name,
                    style: TextStyle(
                        fontWeight:
                            scores[i] == best ? FontWeight.w600 : null)),
              ),
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: scores[i].clamp(0, 1),
                    minHeight: 10,
                    color:
                        scores[i] == best ? Colors.green.shade600 : cs.outline,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ),
              SizedBox(
                  width: 52,
                  child: Text('${(scores[i] * 100).round()} %',
                      textAlign: TextAlign.right, style: muted)),
            ]),
          ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: _tuning ? 76 : 48,
            columnSpacing: 18,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 40,
            horizontalMargin: 4,
            columns: [
              DataColumn(label: Text(t.matrixOption)),
              for (var j = 0; j < m.criteria.length; j++)
                DataColumn(
                  numeric: true,
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(m.criteria[j].name),
                      if (_tuning)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: t.matrixWeightLess(m.criteria[j].name),
                            icon: const Icon(LucideIcons.minus, size: 16),
                            onPressed: _weights[j] <= 0
                                ? null
                                : () => setState(() => _weights[j] =
                                    (_weights[j] - 1).clamp(0, 10)),
                          ),
                          Text(_n(_weights[j])),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: t.matrixWeightMore(m.criteria[j].name),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            onPressed: _weights[j] >= 10
                                ? null
                                : () => setState(() => _weights[j] =
                                    (_weights[j] + 1).clamp(0, 10)),
                          ),
                        ])
                      else
                        Text('× ${_n(_weights[j])}', style: muted),
                    ],
                  ),
                ),
            ],
            rows: [
              for (final o in m.options)
                DataRow(cells: [
                  DataCell(Text(o.name)),
                  for (final s in o.scores) DataCell(Text(_n(s))),
                ]),
            ],
          ),
        ),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _tuning = !_tuning),
                child: Text(_tuning ? t.matrixTuneDone : t.matrixTune),
              ),
              if (changed) ...[
                TextButton(
                  onPressed: () => setState(
                      () => _weights = [for (final c in m.criteria) c.weight]),
                  child: Text(t.matrixReset),
                ),
                Text(t.matrixNotSaved, style: muted),
              ],
              if (widget.ctx.project.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(LucideIcons.scale, size: 16),
                  onPressed: _toDecision,
                  label: Text(t.matrixToDecision),
                ),
            ]),
      ]),
    );
  }
}

void paintMatrix(Canvas canvas, Rect r, Matrix m, ChartStyle s) {
  final scores = m.scores();
  final best = scores.reduce((a, b) => a > b ? a : b);
  var top = r.top;
  if (m.title.isNotEmpty) {
    _paintText(
        canvas, m.title, r.topLeft + const Offset(6, 2), r.width - 12, 15, s.fg,
        bold: true);
    top += 30;
  }
  final row = ((r.bottom - top) / m.options.length).clamp(22.0, 38.0);
  final label = (r.width * 0.38).clamp(60.0, 220.0);
  for (var i = 0; i < m.options.length; i++) {
    final y = top + i * row;
    if (y + row > r.bottom + 2) break;
    _paintText(canvas, m.options[i].name, Offset(r.left + 6, y + row / 2 - 8),
        label - 12, 13, s.fg,
        bold: scores[i] == best);
    final w = (r.width - label - 54) * scores[i];
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + label, y + 4, w < 2 ? 2 : w, row - 10),
            const Radius.circular(5)),
        Paint()..color = s.tc(scores[i] == best ? 'green' : 'gray'));
    _paintText(
        canvas,
        '${(scores[i] * 100).round()} %',
        Offset(r.left + label + (w < 2 ? 2 : w) + 6, y + row / 2 - 8),
        50,
        12,
        s.muted);
  }
}

// --- calculator --------------------------------------------------------------------

class CalcView extends ConsumerStatefulWidget {
  const CalcView({super.key, required this.calc, required this.ctx});
  final Calc calc;
  final BlockCtx ctx;

  @override
  ConsumerState<CalcView> createState() => _CalcViewState();
}

class _CalcViewState extends ConsumerState<CalcView> {
  final _inputs = <String, double>{};
  final _fields = <String, TextEditingController>{};
  String _lang = 'de';

  /// A number for an input field, with the decimal comma in German.
  String _show(double? v) {
    if (v == null) return '';
    final s = v == v.truncateToDouble() ? v.toInt().toString() : '$v';
    return _lang == 'de' ? s.replaceAll('.', ',') : s;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lang = Localizations.localeOf(context).languageCode;
    for (final r in widget.calc.rows) {
      if (r.input && !_fields.containsKey(r.name)) {
        _fields[r.name] = TextEditingController(text: _show(r.value));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Inputs from entries: their current attribute values.
  Future<void> _loadEntities() async {
    final rows = widget.calc.rows.where((r) => r.entity != null).toList();
    if (rows.isEmpty || widget.ctx.project.isEmpty) return;
    final c = await ref.read(clientProvider.future);
    for (final r in rows) {
      try {
        final e = (await c
                ?.get('/projects/${widget.ctx.project}/entities/${r.entity}'))
            ?.data;
        final v = e is Map && e['attrs'] is Map ? e['attrs'][r.attr] : null;
        final n = v is num ? v.toDouble() : double.tryParse('$v');
        if (n != null && mounted) {
          setState(() {
            r.value = n;
            _fields[r.name]?.text = _show(n);
          });
        }
      } catch (_) {
        // entry not readable: stays empty
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final c = widget.calc;
    final vals = c.values(_inputs);
    final muted = TextStyle(color: cs.onSurfaceVariant);
    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (c.title.isNotEmpty) _title(context, c.title),
        for (final r in c.rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text(r.label,
                    style: r.input
                        ? muted
                        : const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (r.input)
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _fields[r.name],
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixText: r.unit.isEmpty ? null : r.unit,
                    ),
                    onChanged: (s) => setState(() {
                      final v = double.tryParse(s.trim().replaceAll(',', '.'));
                      if (v == null) {
                        _inputs.remove(r.name);
                      } else {
                        _inputs[r.name] = v;
                      }
                    }),
                  ),
                )
              else
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${formatValue(vals[r.name], lang)}${r.unit.isEmpty ? '' : ' ${r.unit}'}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: vals[r.name] is FormulaError ? cs.error : null),
                  ),
                ),
            ]),
          ),
        if (_inputs.keys
            .any((k) => c.rows.any((r) => r.name == k && r.entity == null)))
          Row(children: [
            TextButton(
              onPressed: () => setState(() {
                for (final r in c.rows) {
                  if (r.input && r.entity == null) {
                    _inputs.remove(r.name);
                    _fields[r.name]?.text = _show(r.value);
                  }
                }
              }),
              child: Text(t.calcReset),
            ),
            Flexible(
                child: Text(t.calcNotSaved,
                    style: muted.copyWith(fontSize: 12.5))),
          ]),
      ]),
    );
  }
}

void paintCalc(Canvas canvas, Rect r, Calc c, ChartStyle s) {
  final vals = c.values(const {});
  var top = r.top;
  if (c.title.isNotEmpty) {
    _paintText(
        canvas, c.title, r.topLeft + const Offset(6, 2), r.width - 12, 15, s.fg,
        bold: true);
    top += 30;
  }
  final row = ((r.bottom - top) / c.rows.length).clamp(20.0, 30.0);
  for (var i = 0; i < c.rows.length; i++) {
    final x = c.rows[i];
    final y = top + i * row + row / 2 - 8;
    if (y + 16 > r.bottom) break;
    final v = x.entity != null ? '–' : formatValue(vals[x.name], s.lang);
    final value = '$v${x.unit.isEmpty ? '' : ' ${x.unit}'}';
    final vw = _paintText(
        canvas, value, Offset(r.left, y), r.width - 12, 13, s.fg,
        bold: !x.input, alignRight: true, right: r.right - 6);
    _paintText(canvas, x.label, Offset(r.left + 6, y), r.width - vw - 24, 13,
        x.input ? s.muted : s.fg);
  }
}

// --- quiz ------------------------------------------------------------------------------

class QuizView extends ConsumerStatefulWidget {
  const QuizView(
      {super.key, required this.quiz, required this.ctx, required this.source});
  final Quiz quiz;
  final BlockCtx ctx;
  final String source;

  @override
  ConsumerState<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends ConsumerState<QuizView> {
  Map<String, Object?> _answers = {};
  final _shown = <int>{};

  String get _key => widget.ctx.key ?? blockKey(widget.source, widget.quiz.id);
  bool get _remote =>
      widget.ctx.project.isNotEmpty && widget.ctx.doc.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_remote) return;
    try {
      final c = await ref.read(clientProvider.future);
      final r = (await c?.get(blockStatePath(widget.ctx, _key)))?.data;
      final mine = r is Map ? r['mine'] : null;
      if (mine is Map && mine['answers'] is Map && mounted) {
        setState(
            () => _answers = Map<String, Object?>.from(mine['answers'] as Map));
      }
    } catch (_) {
      // nothing saved
    }
  }

  Future<void> _save() async {
    if (!_remote) return;
    try {
      final c = await ref.read(clientProvider.future);
      await c?.send('PUT', blockStatePath(widget.ctx, _key), {
        'data': _answers.isEmpty ? null : {'answers': _answers}
      });
    } catch (_) {
      // answers stay on screen; saving is best effort
    }
  }

  void _answer(int q, Object v) {
    setState(() => _answers['$q'] = v);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final z = widget.quiz;
    final muted = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    final good = Colors.green.shade600, bad = cs.error;
    return _Frame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (z.title.isNotEmpty)
            Expanded(
                child: Text(z.title,
                    style: Theme.of(context).textTheme.titleMedium))
          else
            const Spacer(),
          Semantics(
              liveRegion: true,
              child: Text(t.quizScore(z.right(_answers), z.questions.length),
                  style: muted)),
          if (_answers.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _answers = {};
                  _shown.clear();
                });
                _save();
              },
              child: Text(t.quizAgain),
            ),
        ]),
        for (var i = 0; i < z.questions.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          Text('${i + 1}. ${z.questions[i].q}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ..._question(context, i, good, bad, muted),
        ],
      ]),
    );
  }

  List<Widget> _question(
      BuildContext context, int i, Color good, Color bad, TextStyle muted) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final q = widget.quiz.questions[i];
    final a = _answers['$i'];
    final out = <Widget>[];
    if (q.options.isNotEmpty) {
      for (var j = 0; j < q.options.length; j++) {
        final o = q.options[j];
        final chosen = a is num && a.toInt() == j;
        final color =
            a == null ? null : (o.right ? good : (chosen ? bad : null));
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Semantics(
            label: a == null
                ? null
                : (o.right ? t.quizRight : (chosen ? t.quizWrong : null)),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(40),
                side: BorderSide(
                    color: color ?? cs.outlineVariant,
                    width: color == null ? 1 : 2),
                backgroundColor: color?.withValues(alpha: 0.1),
                foregroundColor: cs.onSurface,
                disabledForegroundColor: cs.onSurface,
              ),
              onPressed: a == null ? () => _answer(i, j) : null,
              child: Row(children: [
                Expanded(child: Text(o.text)),
                if (color != null)
                  Icon(o.right ? LucideIcons.check : LucideIcons.x,
                      size: 16, color: color),
              ]),
            ),
          ),
        ));
      }
    } else if (a == null && !_shown.contains(i)) {
      out.add(OutlinedButton(
          onPressed: () => setState(() => _shown.add(i)),
          child: Text(t.quizShow)));
    } else {
      // Flashcards: reveal, then the reader says whether they knew it.
      out.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8)),
        child: Text(q.answer ?? ''),
      ));
      if (a == null) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () => _answer(i, 'known'), child: Text(t.quizKnew)),
            OutlinedButton(
                onPressed: () => _answer(i, 'unknown'),
                child: Text(t.quizMissed)),
          ]),
        ));
      } else {
        out.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child:
                Text(a == 'known' ? t.quizKnew : t.quizMissed, style: muted)));
      }
    }
    if (a != null && q.explain != null) {
      out.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(q.explain!, style: muted)));
    }
    return out;
  }
}

// --- drawing helpers ------------------------------------------------------------------

/// Paints one line of text; returns its width.
double _paintText(Canvas canvas, String text, Offset at, double maxWidth,
    double size, Color color,
    {bool bold = false, bool alignRight = false, double? right}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth < 1 ? 1 : maxWidth);
  tp.paint(canvas,
      alignRight && right != null ? Offset(right - tp.width, at.dy) : at);
  return tp.width;
}
