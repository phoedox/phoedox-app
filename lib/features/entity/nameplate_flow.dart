import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/client.dart';
import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';
import 'nameplate.dart';

/// Takes a photo of a type plate, attaches it to the entry and offers the
/// values the server's text recognition found as attributes.
Future<void> captureNameplate(BuildContext context, WidgetRef ref,
    String project, Map<String, dynamic> entity) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final camera = Platform.isAndroid || Platform.isIOS;
  final photo = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 3000,
      imageQuality: 90);
  if (photo == null || !context.mounted) return;
  final client = await ref.read(clientProvider.future);
  if (client == null || !context.mounted) return;
  final slug = entity['slug'] as String;
  var cancelled = false;
  final progress = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      content: Row(children: [
        const CircularProgressIndicator(),
        const SizedBox(width: 16),
        Expanded(child: Text(t.nameplateReading))
      ]),
      actions: [
        TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.pop(c);
            },
            child: Text(t.cancel))
      ],
    ),
  );
  Map<String, String> found = {};
  String? failure;
  try {
    final file = await client.upload(
        project, 'nameplate-$slug.jpg', await photo.readAsBytes(),
        entity: slug);
    // Text recognition runs on the server after the upload (OCR, if enabled there).
    for (var i = 0; i < 30 && !cancelled; i++) {
      final r = await client.send(
          'GET', '/projects/$project/files/${file['id']}/text') as Map;
      final status = r['status'] as String? ?? '';
      if (status.isNotEmpty) {
        found = parseNameplate(r['text'] as String? ?? '');
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  } on OfflineException {
    failure = t.nameplateOffline;
  } on ApiException catch (e) {
    failure = '${t.error} (${e.key})';
  }
  if (!cancelled && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  await progress;
  if (cancelled || !context.mounted) return;
  if (failure != null) {
    messenger.showSnackBar(SnackBar(content: Text(failure)));
    return;
  }
  ref.invalidate(apiProvider('/projects/$project/entities/$slug'));
  if (found.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(t.nameplateNothing)));
    return;
  }
  final attrs = Map<String, dynamic>.from((entity['attrs'] as Map?) ?? {});
  final chosen = await showDialog<Map<String, String>>(
      context: context, builder: (_) => _Choose(found: found, current: attrs));
  if (chosen == null || chosen.isEmpty) return;
  try {
    await client.send('POST', '/projects/$project/entities', {
      'kind': entity['kind'],
      'slug': slug,
      'name': entity['name'],
      'attrs': {...attrs, ...chosen},
    });
    ref.invalidate(apiProvider('/projects/$project/entities/$slug'));
    messenger
        .showSnackBar(SnackBar(content: Text(t.nameplateSaved(chosen.length))));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${t.error} (${e.key})')));
  } on OfflineException {
    messenger.showSnackBar(SnackBar(content: Text(t.nameplateOffline)));
  }
}

class _Choose extends StatefulWidget {
  const _Choose({required this.found, required this.current});

  final Map<String, String> found;
  final Map<String, dynamic> current;

  @override
  State<_Choose> createState() => _ChooseState();
}

class _ChooseState extends State<_Choose> {
  // Values that would replace something already filled in start unticked.
  late final Map<String, bool> _on = {
    for (final k in widget.found.keys)
      k: (widget.current[k] ?? '').toString().isEmpty,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.nameplateFound),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in widget.found.entries)
            CheckboxListTile(
              value: _on[e.key],
              onChanged: (v) => setState(() => _on[e.key] = v ?? false),
              title: Text(e.value),
              subtitle: Text((widget.current[e.key] ?? '').toString().isEmpty
                  ? e.key
                  : '${e.key} · ${t.nameplateReplaces(widget.current[e.key].toString())}'),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, {
                  for (final e in widget.found.entries)
                    if (_on[e.key]!) e.key: e.value
                }),
            child: Text(t.save)),
      ],
    );
  }
}
