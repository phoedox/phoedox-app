import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/markdown.dart';
import '../../app/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entity/entity_page.dart';

/// Reads a page: Markdown, decision, link or board (read-only).
class DocPage extends ConsumerWidget {
  const DocPage({super.key, required this.project, required this.doc});

  final String project;
  final String doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: ApiView(
        path: '/projects/$project/documents/$doc',
        builder: (context, data) {
          final d = data as Map<String, dynamic>;
          final c = (d['content'] as Map?)?.cast<String, dynamic>() ?? {};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Text(d['title'] as String? ?? '',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              ...switch (d['type']) {
                'adr' => [
                    Wrap(spacing: 6, children: [
                      Chip(
                          label: Text(
                              'ADR-${(d['number'] ?? 0).toString().padLeft(4, '0')}')),
                      if (c['status'] != null)
                        Chip(label: Text(c['status'] as String)),
                    ]),
                    for (final (k, label) in [
                      ('context', t.context),
                      ('decision', t.decision),
                      ('consequences', t.consequences),
                      ('alternatives', t.alternatives)
                    ])
                      if ((c[k] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(label.toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(letterSpacing: 1.2)),
                        _md(context, c[k] as String),
                      ],
                  ],
                'link' => [
                    FilledButton.tonalIcon(
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                      label: Text(t.openLink),
                      onPressed: () => launchUrl(Uri.parse(c['url'] as String),
                          mode: LaunchMode.externalApplication),
                    ),
                    if ((c['description'] as String? ?? '').isNotEmpty)
                      _md(context, c['description'] as String),
                  ],
                'board' => [
                    _Board(
                        project: project,
                        board: d['id'] as String,
                        columns: (c['columns'] as List? ?? [])
                            .cast<Map<String, dynamic>>())
                  ],
                _ => [_md(context, c['markdown'] as String? ?? '')],
              },
            ],
          );
        },
      ),
    );
  }

  Widget _md(BuildContext context, String md) => MarkdownBody(
        data: toPlainMarkdown(md).replaceAllMapped(
            RegExp(r'(^|[^\w@./-])@([a-z0-9]+(?:-[a-z0-9]+)*)'),
            (m) => '${m[1]}[@${m[2]}](phx-entity:${m[2]})'),
        selectable: true,
        onTapLink: (text, href, title) {
          if (href == null) return;
          if (href.startsWith('phx-entity:')) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EntityPage(project: project, entity: href.substring(11))));
          } else if (href.startsWith('http')) {
            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          }
        },
      );
}

class _Board extends ConsumerWidget {
  const _Board(
      {required this.project, required this.board, required this.columns});

  final String project;
  final String board;
  final List<Map<String, dynamic>> columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 520,
      child: ApiView(
        path: '/projects/$project/tasks?board=$board',
        builder: (context, data) {
          final tasks = (data as List).cast<Map<String, dynamic>>();
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final col in columns)
                Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10)),
                  child: ListView(
                    children: [
                      Text(col['name'] as String? ?? '',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final task
                          in tasks.where((x) => x['column'] == col['id']))
                        Card(
                          child: ListTile(
                            dense: true,
                            title: Text(task['title'] as String? ?? '',
                                style: col['done'] == true
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough)
                                    : null),
                            subtitle: _meta(task),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget? _meta(Map<String, dynamic> task) {
    final parts = [
      ...(task['labels'] as List? ?? []).cast<String>(),
      if ((task['due'] as String? ?? '').isNotEmpty) task['due'] as String,
      if (task['assigneeName'] != null) task['assigneeName'] as String
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }
}

/// Pretty JSON for unknown values.
String showValue(dynamic v) => v is String ? v : jsonEncode(v);
