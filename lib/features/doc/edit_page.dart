import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../sync/outbox.dart';
import '../../sync/providers.dart';

/// Edits a Markdown page as text. Works offline: the change is kept on the
/// device and merged with the server's text when it is sent.
class EditPage extends ConsumerStatefulWidget {
  const EditPage({
    super.key,
    required this.project,
    required this.docId,
    required this.title,
    required this.version,
    required this.published,
    required this.text,
  });

  final String project;
  final String docId;
  final String title;

  /// The published version and text this edit starts from.
  final int version;
  final String published;

  /// The text to edit (the device's pending version if there is one).
  final String text;

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage> {
  late final _text = TextEditingController(text: widget.text);
  bool _saving = false;

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() => _saving = true);
    final notifier = ref.read(pendingProvider.notifier);
    await notifier.save(PendingEdit(
      project: widget.project,
      docId: widget.docId,
      title: widget.title,
      baseVersion: widget.version,
      base: widget.published,
      markdown: _text.text,
      savedAt: DateTime.now(),
    ));
    final report = await notifier.sync();
    if (!mounted) return;
    final sent = report != null && report.sent > 0;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent
            ? (report.merged > 0 ? t.editMerged : t.editSynced)
            : t.editQueued)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PopScope(
      canPop: _text.text == widget.text,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(t.editDiscard),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(t.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(t.discard)),
            ],
          ),
        );
        if ((discard ?? false) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: t.save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.check),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.editHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
