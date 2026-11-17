import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../charts/chart.dart';
import 'blocks.dart';
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
