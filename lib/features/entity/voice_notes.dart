import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../api/files.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../sync/providers.dart';
import '../../sync/uploads.dart';

/// Voice notes are kept short.
const maxVoiceNote = Duration(minutes: 5);

/// "voice-note-2026-11-14-1205.m4a" (local time of the recording).
String voiceNoteName(DateTime at, {String ext = 'm4a'}) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'voice-note-${at.year}-${two(at.month)}-${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}.$ext';
}

/// "4:07".
String clock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// The audio files among a file listing (by type or name).
List<Map<String, dynamic>> audioFiles(List<dynamic> files) => files
    .whereType<Map>()
    .map((f) => f.cast<String, dynamic>())
    .where((f) =>
        (f['mime'] as String? ?? '').startsWith('audio/') ||
        isAudioName(f['name'] as String? ?? ''))
    .toList();

/// Voice notes of an entry: the ones on the server, the ones waiting on the
/// device, and a button to record one.
class VoiceNotesSection extends ConsumerWidget {
  const VoiceNotesSection(
      {super.key,
      required this.project,
      required this.entity,
      required this.canRecord});

  final String project;

  /// Slug of the entry.
  final String entity;
  final bool canRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final path = '/projects/$project/files?entity=$entity';
    final listed = ref.watch(apiProvider(path));
    final server = audioFiles(listed.value?.data as List? ?? const []);
    final pending = (ref.watch(uploadsProvider).value ?? const [])
        .where((u) => u.project == project && u.entity == entity && u.isAudio)
        .toList();
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: Text(t.voiceNotes.toUpperCase(), style: style.labelSmall)),
          if (canRecord)
            TextButton.icon(
              icon: const Icon(LucideIcons.mic, size: 18),
              label: Text(t.voiceRecord),
              onPressed: () => recordVoiceNote(context, ref, project, entity),
            ),
        ]),
        for (final u in pending)
          VoicePlayer(
            key: ValueKey('pending-${u.id}'),
            title: u.name,
            path: u.path,
            subtitle:
                u.error != null ? t.uploadRefused(u.error!) : t.notSentYet,
            icon: u.error != null
                ? LucideIcons.circleAlert
                : LucideIcons.cloudUpload,
            onDelete: () => ref.read(uploadsProvider.notifier).remove(u.id),
          ),
        for (final f in server)
          VoicePlayer(
            key: ValueKey('file-${f['id']}'),
            title: f['name'] as String? ?? '',
            fileId: f['id'] as String,
            subtitle: _when(context, f['createdAt'] as String?),
          ),
        if (pending.isEmpty && server.isEmpty && listed.hasValue)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(t.voiceNone, style: style.bodySmall),
          ),
      ],
    );
  }

  String? _when(BuildContext context, String? iso) {
    final at = DateTime.tryParse(iso ?? '')?.toLocal();
    if (at == null) return null;
    return '${MaterialLocalizations.of(context).formatShortDate(at)} '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
  }
}

/// Plays a voice note from the device ([path]) or a project file ([fileId],
/// downloaded once and kept for offline use).
class VoicePlayer extends ConsumerStatefulWidget {
  const VoicePlayer(
      {super.key,
      required this.title,
      this.path,
      this.fileId,
      this.subtitle,
      this.icon,
      this.onDelete})
      : assert(path != null || fileId != null);

  final String title;
  final String? path;
  final String? fileId;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onDelete;

  @override
  ConsumerState<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends ConsumerState<VoicePlayer> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<Object?>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loading = false;
  bool _failed = false;

  AudioPlayer _ensurePlayer() {
    final p = _player;
    if (p != null) return p;
    final n = AudioPlayer();
    _subs.addAll([
      n.onPlayerStateChanged.listen((s) => setState(() => _state = s)),
      n.onPositionChanged.listen((d) => setState(() => _position = d)),
      n.onDurationChanged.listen((d) => setState(() => _duration = d)),
      n.onPlayerComplete.listen((_) => setState(() {
            _state = PlayerState.completed;
            _position = Duration.zero;
          })),
    ]);
    return _player = n;
  }

  Future<void> _toggle() async {
    final player = _ensurePlayer();
    if (_state == PlayerState.playing) return player.pause();
    if (_state == PlayerState.paused) return player.resume();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final path = widget.path ??
          (await ref.read(localFileProvider(widget.fileId!).future)).path;
      await player.play(DeviceFileSource(path));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final playing = _state == PlayerState.playing;
    final total = _duration;
    final active = playing || _state == PlayerState.paused;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: _loading
          ? const SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2)))
          : IconButton(
              tooltip: playing ? t.pause : t.play,
              icon: Icon(playing ? LucideIcons.pause : LucideIcons.play),
              onPressed: _toggle,
            ),
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active && total != null && total > Duration.zero)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(
                  value: (_position.inMilliseconds / total.inMilliseconds)
                      .clamp(0.0, 1.0)),
            ),
          if (_failed)
            Text(t.loadFailed)
          else if (active && total != null)
            Text('${clock(_position)} / ${clock(total)}')
          else if (widget.subtitle != null)
            Row(children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14),
                const SizedBox(width: 4),
              ],
              Expanded(child: Text(widget.subtitle!)),
            ]),
        ],
      ),
      trailing: widget.onDelete == null
          ? null
          : IconButton(
              tooltip: t.discard,
              icon: const Icon(LucideIcons.trash2, size: 18),
              onPressed: widget.onDelete,
            ),
    );
  }
}

/// Records a voice note and queues it as an attachment of the entry; it is
/// sent right away when online, otherwise with the next sync.
Future<void> recordVoiceNote(
    BuildContext context, WidgetRef ref, String project, String entity) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final probe = AudioRecorder();
  try {
    if (!await probe.hasPermission(request: false)) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(LucideIcons.mic),
          title: Text(t.voiceMicTitle),
          content: Text(t.voiceMicRationale),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(t.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(t.voiceMicContinue)),
          ],
        ),
      );
      if (go != true) return;
      if (!await probe.hasPermission()) {
        messenger.showSnackBar(SnackBar(content: Text(t.voiceMicDenied)));
        return;
      }
    }
  } finally {
    await probe.dispose();
  }
  if (!context.mounted) return;
  final recorded = await showModalBottomSheet<File>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _RecorderSheet(),
  );
  if (recorded == null) return;
  final ext = recorded.path.split('.').last;
  final notifier = ref.read(uploadsProvider.notifier);
  await notifier.add(
      project: project,
      name: voiceNoteName(DateTime.now(), ext: ext),
      source: recorded,
      entity: entity);
  try {
    await recorded.delete();
  } catch (_) {}
  final report = await notifier.sync();
  messenger.showSnackBar(SnackBar(
      content: Text(
          report != null && report.sent > 0 ? t.voiceSent : t.voiceQueued)));
}

class _RecorderSheet extends StatefulWidget {
  const _RecorderSheet();

  @override
  State<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<_RecorderSheet> {
  final _rec = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _tick;
  String? _path;
  bool _recording = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // AAC in an MPEG-4 container (.m4a); WAV where AAC is not available.
      final aac = await _rec.isEncoderSupported(AudioEncoder.aacLc);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.${aac ? 'm4a' : 'wav'}';
      await _rec.start(
          RecordConfig(
              encoder: aac ? AudioEncoder.aacLc : AudioEncoder.wav,
              bitRate: 64000,
              sampleRate: 44100,
              numChannels: 1),
          path: path);
      _watch.start();
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_watch.elapsed >= maxVoiceNote) {
          _stop();
        } else {
          setState(() {});
        }
      });
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _stop() async {
    _tick?.cancel();
    _watch.stop();
    final path = await _rec.stop();
    if (mounted) {
      setState(() {
        _recording = false;
        _path = path;
        _failed = path == null;
      });
    }
  }

  Future<void> _discard() async {
    if (_recording) await _rec.cancel();
    final p = _path;
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme;
    final elapsed =
        _watch.elapsed > maxVoiceNote ? maxVoiceNote : _watch.elapsed;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.voiceRecord, style: style.titleMedium),
            const SizedBox(height: 4),
            Text(t.voiceLimit(maxVoiceNote.inMinutes), style: style.bodySmall),
            const SizedBox(height: 20),
            if (_failed)
              Text(t.voiceRecordFailed)
            else if (_path == null) ...[
              Row(children: [
                Icon(LucideIcons.mic,
                    color: _recording
                        ? Theme.of(context).colorScheme.error
                        : null),
                const SizedBox(width: 8),
                Text(_recording ? t.voiceRecording : '…'),
                const Spacer(),
                Text('${clock(elapsed)} / ${clock(maxVoiceNote)}',
                    style: style.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                  value: elapsed.inMilliseconds / maxVoiceNote.inMilliseconds),
            ] else
              VoicePlayer(title: clock(elapsed), path: _path),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _discard, child: Text(t.discard)),
                const SizedBox(width: 8),
                if (_recording)
                  FilledButton.icon(
                    icon: const Icon(LucideIcons.square, size: 16),
                    label: Text(t.voiceStop),
                    onPressed: _stop,
                  )
                else
                  FilledButton(
                    onPressed: _path == null
                        ? null
                        : () => Navigator.pop(context, File(_path!)),
                    child: Text(t.save),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
