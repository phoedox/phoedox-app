import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../calendar/calendar.dart';
import '../doc/doc_page.dart';
import '../entity/entity_page.dart';

IconData docIcon(String? type) => switch (type) {
      'adr' => LucideIcons.scale,
      'link' => LucideIcons.link,
      'board' => LucideIcons.squareKanban,
      'floorplan' => LucideIcons.landPlot,
      'calendar' => LucideIcons.calendarDays,
      _ => LucideIcons.fileText,
    };

/// Pages of a project by folder, with search.
class ProjectPage extends ConsumerStatefulWidget {
  const ProjectPage({super.key, required this.project});

  final Map<String, dynamic> project;

  @override
  ConsumerState<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends ConsumerState<ProjectPage> {
  String _query = '';

  String get _slug => widget.project['slug'] as String;

  /// The project's optional tabs (features), from the list or, once
  /// loaded, from the project itself.
  Set<String> get _features {
    final p = ref.watch(apiProvider('/projects/$_slug')).value?.data;
    final list =
        (p is Map ? p['features'] : null) ?? widget.project['features'];
    return {for (final f in (list as List? ?? const [])) '$f'};
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color =
        hexColor(widget.project['primaryColor'] as String?, PhxColors.brand);
    // The project's theme (or the one that applies there); without one the
    // project colour tints Phoedox's own look.
    final tokens = ref.watch(projectThemeProvider(_slug)).value;
    final calendar = _features.contains('calendar');
    return Theme(
      data: phxTheme(Theme.of(context).brightness, seed: color, tokens: tokens),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.project['name'] as String? ?? '')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SearchBar(
                hintText: t.search,
                leading: const Icon(LucideIcons.search, size: 18),
                onSubmitted: (v) => setState(() => _query = v.trim()),
                onChanged: (v) {
                  if (v.isEmpty) setState(() => _query = '');
                },
              ),
            ),
            Expanded(
                child: _query.isEmpty
                    ? _tree(t, calendar: calendar)
                    : _results(t)),
          ],
        ),
      ),
    );
  }

  Widget _tree(AppLocalizations t, {bool calendar = false}) => ApiView(
        path: '/projects/$_slug/documents',
        builder: (context, data) {
          final docs = (data as List).cast<Map<String, dynamic>>();
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final d in docs) {
            final cat = d['type'] == 'adr'
                ? t.decisions
                : ((d['category'] as String?)?.isNotEmpty ?? false)
                    ? (d['category'] as String).replaceAll('/', ' › ')
                    : t.uncategorized;
            groups.putIfAbsent(cat, () => []).add(d);
          }
          return ListView(
            children: [
              // The calendar tab (ADR-0089), when the project has it.
              if (calendar)
                ListTile(
                  leading: const Icon(LucideIcons.calendarDays, size: 20),
                  title: Text(t.calTitle),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CalendarPage(project: _slug))),
                ),
              for (final e in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(e.key.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(letterSpacing: 1.2)),
                ),
                for (final d in e.value)
                  ListTile(
                    leading: Icon(docIcon(d['type'] as String?), size: 20),
                    title: Text(d['title'] as String? ?? ''),
                    dense: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            DocPage(project: _slug, doc: d['slug'] as String))),
                  ),
              ],
            ],
          );
        },
      );

  Widget _results(AppLocalizations t) => ApiView(
        path:
            '/search?q=${Uri.encodeQueryComponent(_query)}&project=${Uri.encodeQueryComponent(_slug)}',
        builder: (context, data) {
          final hits = (data as List? ?? [])
              .cast<Map<String, dynamic>>()
              .where(
                  (h) => h['projectSlug'] == _slug || h['projectSlug'] == null)
              .toList();
          if (hits.isEmpty) {
            return ListView(children: [
              Padding(
                  padding: const EdgeInsets.all(24), child: Text(t.noResults))
            ]);
          }
          return ListView(
            children: [
              for (final h in hits)
                ListTile(
                  leading: Icon(
                      h['type'] == 'entity'
                          ? LucideIcons.box
                          : LucideIcons.fileText,
                      size: 20),
                  title: Text(h['title'] as String? ?? ''),
                  subtitle: Text(
                      ((h['snippet'] as String?) ?? '')
                          .replaceAll(RegExp('[]'), ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => h['type'] == 'entity'
                        ? EntityPage(
                            project: _slug, entity: h['slug'] as String)
                        : DocPage(project: _slug, doc: h['slug'] as String),
                  )),
                ),
            ],
          );
        },
      );
}
