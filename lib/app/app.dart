import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'dart:async';

import '../features/projects/projects_page.dart';
import '../sync/outbox.dart';
import '../sync/providers.dart';
import '../sync/uploads.dart';
import '../features/scan/scan_page.dart';
import '../features/signin/signin_page.dart';
import '../l10n/gen/app_localizations.dart';
import 'session.dart';
import 'theme.dart';

class PhoedoxApp extends StatelessWidget {
  const PhoedoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => 'Phoedox',
      theme: phxTheme(Brightness.light),
      darkTheme: phxTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates
      ],
      home: const Root(),
    );
  }
}

/// Sign-in until a token is stored, then the app.
class Root extends ConsumerWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return s.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SignInPage(),
      data: (session) =>
          session == null ? const SignInPage() : const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  Timer? _timer;
  AppLifecycleListener? _life;

  @override
  void initState() {
    super.initState();
    // Offline edits are sent at start, when the app comes back and every two minutes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    _life = AppLifecycleListener(onResume: _sync);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _life?.dispose();
    super.dispose();
  }

  /// Sends page edits and queued uploads (voice notes, plan photos).
  Future<void> _sync({bool tell = false}) async {
    final results = await Future.wait([
      ref.read(pendingProvider.notifier).sync(),
      ref.read(uploadsProvider.notifier).sync(),
    ]);
    final edits = results[0] as SyncReport?;
    final uploads = results[1] as UploadReport?;
    if (!tell || !mounted || (edits == null && uploads == null)) return;
    final offline = (edits?.offline ?? false) || (uploads?.offline ?? false);
    final failed = (edits?.failed ?? 0) + (uploads?.failed ?? 0);
    final sent = (edits?.sent ?? 0) + (uploads?.sent ?? 0);
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(offline
            ? t.syncOffline
            : failed > 0
                ? t.syncFailed(failed)
                : t.syncDone(sent))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider).value;
    const pages = [ProjectsPage(), ScanPage()];
    final waiting = (ref.watch(pendingProvider).value?.length ?? 0) +
        (ref.watch(uploadsProvider).value?.length ?? 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? t.projects : t.scan),
        actions: [
          if (waiting > 0)
            IconButton(
              tooltip: t.syncNow,
              onPressed: () => _sync(tell: true),
              icon: Badge(
                label: Text('$waiting'),
                child: const Icon(LucideIcons.cloudUpload),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.circleUser),
            itemBuilder: (_) => [
              PopupMenuItem(
                  enabled: false,
                  child: Text(
                      '${session?.userName ?? ''}\n${session?.base.host ?? ''}')),
              PopupMenuItem(value: 'out', child: Text(t.signOut)),
            ],
            onSelected: (v) {
              if (v == 'out') ref.read(sessionProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(LucideIcons.folderOpen), label: t.projects),
          NavigationDestination(
              icon: const Icon(LucideIcons.scanLine), label: t.scan),
        ],
      ),
    );
  }
}
