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
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  decoration:
                      InputDecoration(labelText: t.token, hintText: 'phx_…'),
                  obscureText: true,
                  autocorrect: false,
                  onSubmitted: (_) => _connect(),
                ),
                if (_failed) ...[
                  const SizedBox(height: 12),
                  Text(t.signInFailed,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _connect, child: Text(t.connect)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
