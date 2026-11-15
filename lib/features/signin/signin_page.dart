import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../l10n/gen/app_localizations.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _instance = TextEditingController();
  final _token = TextEditingController();
  bool _busy = false;
  bool _failed = false;
  bool _withToken = false;

  Future<void> _browser() async {
    if (_instance.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref
        .read(sessionProvider.notifier)
        .signInWithBrowser(_instance.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !ok;
      });
    }
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref
        .read(sessionProvider.notifier)
        .signIn(_instance.text, _token.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 16),
                Text(t.signInTitle,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(t.signInHint),
                const SizedBox(height: 20),
                TextField(
                  controller: _instance,
                  decoration: InputDecoration(
                      labelText: t.instance, hintText: 'app.example.org'),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: _busy ? null : _browser,
                    icon: const Icon(Icons.open_in_browser),
                    label: Text(t.signInBrowser)),
                const SizedBox(height: 8),
                Text(t.signInBrowserHint,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: () => setState(() => _withToken = !_withToken),
                    child: Text(t.signInWithToken)),
                if (_withToken) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _token,
                    decoration:
                        InputDecoration(labelText: t.token, hintText: 'phx_…'),
                    obscureText: true,
                    autocorrect: false,
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _busy ? null : _connect,
                      child: Text(t.connect)),
                ],
                if (_failed) ...[
                  const SizedBox(height: 12),
                  Text(t.signInFailed,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
