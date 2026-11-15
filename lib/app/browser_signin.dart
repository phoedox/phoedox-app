import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Sign-in in the browser (ADR-0065): the app opens
/// `<instance>/identify?client_id=phoedox-app&…`, the person signs in there
/// (password, passkey, SSO, two-factor – whatever the instance offers) and
/// allows the app. The instance sends a one-time code to `phoedox://signin`;
/// together with the PKCE verifier it becomes a personal API token.
const appClientId = 'phoedox-app';
const appRedirect = 'phoedox://signin';
const appScheme = 'phoedox';

/// A PKCE pair (S256) and the state that ties the answer to the request.
class Pkce {
  Pkce._(this.verifier, this.challenge, this.state);

  final String verifier;
  final String challenge;
  final String state;

  factory Pkce.generate([Random? random]) {
    final r = random ?? Random.secure();
    String token(int bytes) =>
        base64UrlEncode(List<int>.generate(bytes, (_) => r.nextInt(256)))
            .replaceAll('=', '');
    final verifier = token(48); // 64 characters
    return Pkce._(verifier, challengeOf(verifier), token(18));
  }

  static String challengeOf(String verifier) =>
      base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
}

/// The address the browser opens on the instance.
Uri signInUrl(Uri base, Pkce p) =>
    base.replace(path: '/identify', queryParameters: {
      'client_id': appClientId,
      'redirect_uri': appRedirect,
      'state': p.state,
      'code_challenge': p.challenge,
      'code_challenge_method': 'S256',
    });

/// Reads the code from the answer; null if it does not belong to this
/// request or was refused.
String? codeFrom(String callback, Pkce p) {
  final u = Uri.tryParse(callback);
  if (u == null || u.scheme != appScheme) return null;
  if (u.queryParameters['state'] != p.state) return null;
  final code = u.queryParameters['code'];
  return (code == null || code.isEmpty) ? null : code;
}
