import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/files.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../sync/providers.dart';
import '../../sync/uploads.dart';
import '../entity/entity_page.dart';
import 'plan.dart';

/// A floor plan, read only: rooms, walls, devices and photos drawn from the
/// document JSON. Editors can take a photo and place it on the plan; it goes
/// into the plan's draft (never published from the app).
class FloorplanBody extends ConsumerStatefulWidget {
  const FloorplanBody(
      {super.key,
      required this.project,
      required this.doc,
      required this.canEdit});

  final String project;

  /// The document as the API returns it (content = the plan).
  final Map<String, dynamic> doc;
  final bool canEdit;

  @override
  ConsumerState<FloorplanBody> createState() => _FloorplanBodyState();
}

class _FloorplanBodyState extends ConsumerState<FloorplanBody> {
  /// The photo being placed: waiting for a tap on the plan.
  XFile? _photo;
  bool _busy = false;

  Map<String, dynamic> get _plan =>
      (widget.doc['content'] as Map?)?.cast<String, dynamic>() ?? {};

  String get _docId => widget.doc['id'] as String;

  Future<void> _takePhoto() async {
    final camera = Platform.isAndroid || Platform.isIOS;
    final photo = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 85);
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _placeAt(Offset mm) async {
    final photo = _photo;
    if (photo == null || _busy) return;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final room = roomAt(_plan, mm);
    final caption = await showDialog<String>(
      context: context,
      builder: (_) => _CaptionDialog(
          photo: File(photo.path), initial: room?['name'] as String? ?? ''),
    );
    if (caption == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(uploadsProvider.notifier);
      final taken = {
        ...planIds(_plan),
        for (final u
            in ref.read(uploadsProvider).value ?? const <PendingUpload>[])
          if (u.place != null) u.place!.photoId,
      };
      final queued = await notifier.add(
        project: widget.project,
        name: 'plan-photo-${DateTime.now().millisecondsSinceEpoch}.jpg',
        source: File(photo.path),
        document: _docId,
        place: PlanPlacement(
            doc: _docId,
            photoId: newPlanId('ph', taken),
            x: mm.dx,
            y: mm.dy,
            caption: caption),
      );
      setState(() => _photo = null);
      final report = await notifier.sync();
      final left = (ref.read(uploadsProvider).value ?? const <PendingUpload>[])
          .where((u) => u.id == queued.id)
          .firstOrNull;
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(left?.error != null
            ? t.uploadRefused(left!.error!)
            : left != null || report == null
                ? t.planPhotoQueued
                : report.placedInDraft > 0
                    ? t.planPhotoDraft
                    : t.planPhotoDone),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tap(PlanTransform tf, Offset px) {
    if (_photo != null) {
      if (tf.contains(px)) _placeAt(tf.toPlan(px));
      return;
    }
    final hit = hitItem(_plan, tf, px);
    if (hit == null) return;
    if (hit.$1 == 'device') {
      final slug = hit.$2['entity'];
      if (slug is String && slug.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EntityPage(project: widget.project, entity: slug)));
      }
    } else if (hit.$2['file'] is String) {
      showDialog<void>(
          context: context,
          builder: (_) => _PhotoDialog(
              file: hit.$2['file'] as String,
              caption: hit.$2['caption'] as String? ?? ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pending = (ref.watch(uploadsProvider).value ?? const [])
        .where((u) => u.place?.doc == _docId)
        .toList();
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Expanded(
                  child: Text(widget.doc['title'] as String? ?? '',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
              ]),
            ),
            if (_photo != null)
              _Banner(
                icon: LucideIcons.crosshair,
                text: t.planPhotoTap,
                color: scheme.primaryContainer,
                action: TextButton(
                    onPressed: () => setState(() => _photo = null),
                    child: Text(t.cancel)),
              )
            else if (pending.isNotEmpty)
              _Banner(
                icon: pending.any((u) => u.error != null)
                    ? LucideIcons.circleAlert
                    : LucideIcons.cloudUpload,
                text: pending.any((u) => u.error != null)
                    ? t.uploadRefused(
                        pending.firstWhere((u) => u.error != null).error!)
                    : t.planPhotosPending(pending.length),
                color: scheme.secondaryContainer,
                action: TextButton(
                    onPressed: () => ref.read(uploadsProvider.notifier).sync(),
                    child: Text(t.syncNow)),
              ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final size = c.biggest;
                final tf = PlanTransform(planBounds(_plan), size);
                return InteractiveViewer(
                  maxScale: 10,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _tap(tf, d.localPosition),
                    child: CustomPaint(
                      size: size,
                      painter: PlanPainter(
                        plan: _plan,
                        scheme: scheme,
                        labelStyle: Theme.of(context).textTheme.labelSmall ??
                            const TextStyle(fontSize: 11),
                        pending: [
                          for (final u in pending)
                            Offset(u.place!.x, u.place!.y)
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        if (widget.canEdit && _photo == null)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'plan-photo',
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.camera, size: 18),
              label: Text(t.planPhoto),
              tooltip: t.planDraftNote,
              onPressed: _busy ? null : _takePhoto,
            ),
          ),
      ],
    );
  }
}

/// The device or photo under a point of the view (within [reach] pixels),
/// as ("device" | "photo", item).
(String, Map<String, dynamic>)? hitItem(
    Map<String, dynamic> plan, PlanTransform tf, Offset px,
    {double reach = 22}) {
  (String, Map<String, dynamic>)? best;
  var bestDist = reach;
  for (final kind in ['photo', 'device']) {
    for (final item in planList(plan, '${kind}s')) {
      final p = itemPoint(item);
      if (p == null) continue;
      final d = (tf.toView(p) - px).distance;
      if (d < bestDist) {
        best = (kind, item);
        bestDist = d;
      }
    }
  }
  return best;
}

/// Room colours of the web app (planColorRe on the server).
Color roomColor(String? name, ColorScheme scheme) => switch (name) {
      'red' => Colors.red,
      'orange' => Colors.orange,
      'yellow' => Colors.amber,
      'green' => Colors.green,
      'blue' => Colors.blue,
      'purple' => Colors.purple,
      'pink' => Colors.pink,
      'gray' => Colors.blueGrey,
      _ => scheme.primary,
    };

/// Draws a plan: rooms with their names, walls, devices, photos and photos
/// still waiting on the device ([pending], in mm).
class PlanPainter extends CustomPainter {
  PlanPainter(
      {required this.plan,
      required this.scheme,
      required this.labelStyle,
      this.pending = const []});

  final Map<String, dynamic> plan;
  final ColorScheme scheme;
  final TextStyle labelStyle;
  final List<Offset> pending;

  @override
  void paint(Canvas canvas, Size size) {
    final tf = PlanTransform(planBounds(plan), size);
    canvas.drawRect(
        Rect.fromPoints(
            tf.toView(tf.plan.topLeft), tf.toView(tf.plan.bottomRight)),
        Paint()..color = scheme.surfaceContainerLow);

    for (final room in planList(plan, 'rooms')) {
      final pts = roomPoints(room).map(tf.toView).toList();
      if (pts.length < 3) continue;
      final path = Path()..addPolygon(pts, true);
      final c = roomColor(room['color'] as String?, scheme);
      canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.14));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = c.withValues(alpha: 0.7));
      final name = room['name'] as String? ?? '';
      if (name.isNotEmpty) {
        final centre = pts.reduce((a, b) => a + b) / pts.length.toDouble();
        _label(canvas, name, centre, scheme.onSurface);
      }
    }

    final wall = Paint()
      ..color = scheme.onSurfaceVariant
      ..strokeCap = StrokeCap.square;
    for (final w in planList(plan, 'walls')) {
      final a = w['a'], b = w['b'];
      if (a is! List || b is! List || a.length < 2 || b.length < 2) continue;
      final pa = Offset((a[0] as num).toDouble(), (a[1] as num).toDouble());
      final pb = Offset((b[0] as num).toDouble(), (b[1] as num).toDouble());
      final thick = (w['thickness'] as num?)?.toDouble() ?? 120;
      canvas.drawLine(tf.toView(pa), tf.toView(pb),
          wall..strokeWidth = (thick * tf.scale).clamp(1.5, 40.0));
    }

    for (final d in planList(plan, 'devices')) {
      final p = itemPoint(d);
      if (p == null) continue;
      _dot(canvas, tf.toView(p), 6, scheme.primary, scheme.onPrimary);
    }
    for (final ph in planList(plan, 'photos')) {
      final p = itemPoint(ph);
      if (p == null) continue;
      _dot(canvas, tf.toView(p), 9, scheme.tertiary, scheme.onTertiary);
      _icon(canvas, LucideIcons.camera, tf.toView(p), scheme.onTertiary);
    }
    for (final p in pending) {
      final c = tf.toView(p);
      canvas.drawCircle(
          c,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = scheme.tertiary);
      _icon(canvas, LucideIcons.camera, c, scheme.tertiary);
    }
  }

  void _dot(Canvas canvas, Offset c, double r, Color fill, Color ring) {
    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = ring);
  }

  void _icon(Canvas canvas, IconData icon, Offset c, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: 11,
              color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _label(Canvas canvas, String text, Offset c, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle.copyWith(color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(PlanPainter old) =>
      old.plan != plan ||
      old.scheme != scheme ||
      old.pending.length != pending.length;
}

class _Banner extends StatelessWidget {
  const _Banner(
      {required this.icon,
      required this.text,
      required this.color,
      required this.action});

  final IconData icon;
  final String text;
  final Color color;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          action,
        ]),
      );
}

class _CaptionDialog extends StatefulWidget {
  const _CaptionDialog({required this.photo, required this.initial});

  final File photo;
  final String initial;

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.planPhoto),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(widget.photo,
                height: 160, fit: BoxFit.cover, cacheHeight: 320),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLength: 500,
            decoration: InputDecoration(labelText: t.planPhotoCaption),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          Text(t.planDraftNote, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _text.text.trim()),
            child: Text(t.save)),
      ],
    );
  }
}

/// A photo of the plan, large (downloaded once, then kept offline).
class _PhotoDialog extends ConsumerWidget {
  const _PhotoDialog({required this.file, required this.caption});

  final String file;
  final String caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(localFileProvider(file));
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        f.when(
          loading: () => const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => SizedBox(
              height: 160,
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.imageOff, size: 32),
                const SizedBox(height: 8),
                Text(t.loadFailed),
              ]))),
          data: (file) => InteractiveViewer(child: Image.file(file)),
        ),
        if (caption.isNotEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text(caption)),
      ]),
    );
  }
}
