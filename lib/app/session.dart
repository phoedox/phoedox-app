import 'dart:io';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../api/cache.dart';
import '../api/client.dart';
import 'browser_signin.dart';

/// The connected instance. The token lives in the platform's secure storage.
class Session {
  const Session(
      {required this.base, required this.token, required this.userName});

  final Uri base;
  final String token;
  final String userName;
}

const _storage = FlutterSecureStorage();

Future<OfflineCache> _cache() async => OfflineCache(
    Directory('${(await getApplicationSupportDirectory()).path}/cache'));

/// Normalizes what people type: "app.example.org" → https://app.example.org.
Uri instanceUri(String raw) {
  var s = raw.trim();
  if (!s.contains('://')) s = 'https://$s';
  final u = Uri.parse(s);
  return Uri(scheme: u.scheme, host: u.host, port: u.hasPort ? u.port : null);
}

class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final base = await _storage.read(key: 'instance');
    final token = await _storage.read(key: 'token');
    if (base == null || token == null) return null;
    return Session(
        base: Uri.parse(base),
        token: token,
        userName: await _storage.read(key: 'user') ?? '');
  }

  /// Checks the token against /me and keeps it.
  Future<bool> signIn(String instance, String token) async {
    final base = instanceUri(instance);
    try {
      final me = await PhxClient(base: base, token: token.trim()).get('/me');
      if (me.offline) return false;
      final name = (me.data as Map)['name'] as String? ?? '';
      await _storage.write(key: 'instance', value: base.toString());
      await _storage.write(key: 'token', value: token.trim());
      await _storage.write(key: 'user', value: name);
      state =
          AsyncData(Session(base: base, token: token.trim(), userName: name));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Signs in through the instance's own sign-in page in the browser
  /// (ADR-0065) and keeps the personal token it hands out for this device.
  Future<bool> signInWithBrowser(String instance) async {
    final base = instanceUri(instance);
    final pkce = Pkce.generate();
    try {
      final answer = await FlutterWebAuth2.authenticate(
          url: signInUrl(base, pkce).toString(), callbackUrlScheme: appScheme);
      final code = codeFrom(answer, pkce);
      if (code == null) return false;
      final res = await http.post(base.replace(path: '/api/v1/app/token'),
          headers: {'Content-Type': 'application/json', 'X-Phoedox': '1'},
          body: jsonEncode({
            'code': code,
            'code_verifier': pkce.verifier,
            'device': _deviceName(),
          }));
      if (res.statusCode != 200) return false;
      final token = (jsonDecode(res.body) as Map)['token'] as String?;
      if (token == null || token.isEmpty) return false;
      return await signIn(base.toString(), token);
    } catch (_) {
      return false; // cancelled, offline or refused
    }
  }

  static String _deviceName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iPhone/iPad';
    return Platform.operatingSystem;
  }

  Future<void> signOut() async {
    await _storage.deleteAll();
    await (await _cache()).clear();
    state = const AsyncData(null);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

final cacheProvider = FutureProvider<OfflineCache>((ref) => _cache());

final clientProvider = FutureProvider<PhxClient?>((ref) async {
  final s = ref.watch(sessionProvider).value;
  if (s == null) return null;
  return PhxClient(
      base: s.base,
      token: s.token,
      cache: await ref.watch(cacheProvider.future));
});

/// GET of an API path with offline fallback, e.g. "/projects".
final apiProvider =
    FutureProvider.family<ApiResult<dynamic>, String>((ref, path) async {
  final c = await ref.watch(clientProvider.future);
  if (c == null) throw OfflineException();
  return c.get(path);
});
