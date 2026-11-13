import 'package:flutter/material.dart';

/// Project list. Data comes from the sync layer (yrs via FFI) once wired up.
class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Projekte', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.home_outlined),
            title: Text('Beispielprojekt'),
            subtitle: Text('Noch nicht mit einer Instanz verbunden'),
          ),
        ),
      ],
    );
  }
}
