import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../doc/doc_page.dart';
import '../scan/nfc.dart';
import 'nameplate_flow.dart';
import 'voice_notes.dart';

/// An entry of the knowledge graph: attributes, relations, pages mentioning it.
class EntityPage extends ConsumerWidget {
  const EntityPage({super.key, required this.project, required this.entity});

  final String project;
  final String entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final path = '/projects/$project/entities/$entity';
    final loaded = ref.watch(apiProvider(path)).value;
    final data = loaded?.data as Map<String, dynamic>?;
    final ent = data == null
        ? null
        : ((data['entity'] as Map?)?.cast<String, dynamic>() ?? data);
    final role = (ref.watch(apiProvider('/projects/$project')).value?.data
        as Map?)?['role'] as String?;
    final canEdit = role == 'editor' || role == 'owner';
    return Scaffold(
      appBar: AppBar(actions: [
        if (ent != null && loaded?.offline != true)
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'plate',
                  child: ListTile(
                      leading: const Icon(LucideIcons.camera),
                      title: Text(t.nameplateAction))),
              PopupMenuItem(
                  value: 'nfc',
                  child: ListTile(
                      leading: const Icon(LucideIcons.nfc),
                      title: Text(t.nfcWrite))),
            ],
            onSelected: (v) async {
              if (v == 'plate') {
                return captureNameplate(context, ref, project, ent);
              }
              final messenger = ScaffoldMessenger.of(context);
              if (!await nfcAvailable()) {
                messenger
                    .showSnackBar(SnackBar(content: Text(t.nfcUnavailable)));
                return;
              }
              final base = ref.read(sessionProvider).value!.base;
              final url =
                  base.replace(path: '/e/$project/${ent['slug']}').toString();
              messenger.showSnackBar(SnackBar(content: Text(t.nfcHold)));
              final err = await writeNfcLink(url, prompt: t.nfcHold);
              messenger.showSnackBar(SnackBar(
                  content: Text(err == null
                      ? t.nfcWritten
                      : err == 'readonly'
                          ? t.nfcReadonly
                          : t.nfcWriteFailed)));
            },
          ),
      ]),
      body: ApiView(
        path: path,
        builder: (context, data) {
          final d = data as Map<String, dynamic>;
          final e = (d['entity'] as Map?)?.cast<String, dynamic>() ?? d;
          final attrs = (e['attrs'] as Map?)?.cast<String, dynamic>() ?? {};
          final edges =
              (d['edges'] as List? ?? []).cast<Map<String, dynamic>>();
          final docs =
              (d['documents'] as List? ?? []).cast<Map<String, dynamic>>();
          final id = e['id'];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Text(e['name'] as String? ?? '',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('${e['kind']} · @${e['slug']}',
                  style: Theme.of(context).textTheme.bodySmall),
              if (attrs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(t.attributes.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall),
                for (final a in attrs.entries
                    .where((a) => a.value != null && a.value != ''))
                  ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.key),
                      trailing: Text(showValue(a.value))),
              ],
              if (e['slug'] is String)
                VoiceNotesSection(
                    project: project,
                    entity: e['slug'] as String,
                    canRecord: canEdit),
              if (edges.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(t.relations.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall),
                for (final x in edges)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        x['from'] == id
                            ? LucideIcons.arrowRight
                            : LucideIcons.arrowLeft,
                        size: 16),
                    title: Text(x['from'] == id
                        ? (x['toName'] as String? ?? '')
                        : (x['fromName'] as String? ?? '')),
                    subtitle: Text(x['rel'] as String? ?? ''),
                    onTap: () {
                      final slug =
                          x['from'] == id ? x['toSlug'] : x['fromSlug'];
                      if (slug is String) {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                EntityPage(project: project, entity: slug)));
                      }
                    },
                  ),
              ],
              if (docs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(t.mentionedIn.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall),
                for (final doc in docs)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.fileText, size: 16),
                    title: Text(doc['title'] as String? ?? ''),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DocPage(
                            project: project, doc: doc['slug'] as String))),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
