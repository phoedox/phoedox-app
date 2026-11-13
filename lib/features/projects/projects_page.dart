import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../project/project_page.dart';

/// The projects of the connected instance.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return ApiView(
      path: '/projects',
      builder: (context, data) {
        final list = (data as List).cast<Map<String, dynamic>>();
        if (list.isEmpty) {
          return ListView(children: [
            Padding(
                padding: const EdgeInsets.all(24), child: Text(t.noProjects))
          ]);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = list[i];
            final color =
                hexColor(p['primaryColor'] as String?, PhxColors.brand);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Text(p['short'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                title: Text(p['name'] as String? ?? ''),
                subtitle: (p['description'] as String? ?? '').isEmpty
                    ? null
                    : Text(p['description'] as String),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProjectPage(project: p))),
              ),
            );
          },
        );
      },
    );
  }
}
