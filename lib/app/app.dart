import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/projects/projects_page.dart';
import '../features/scan/scan_page.dart';
import 'theme.dart';

class PhoedoxApp extends StatelessWidget {
  const PhoedoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phoedox',
      theme: phxTheme(Brightness.light),
      darkTheme: phxTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [ProjectsPage(), ScanPage()];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projekte'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scannen'),
        ],
      ),
    );
  }
}
