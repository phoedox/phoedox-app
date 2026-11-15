import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/app/browser_signin.dart';

void main() {
  test('PKCE pair: verifier length and S256 challenge', () {
    final p = Pkce.generate(Random(1));
    expect(p.verifier.length, greaterThanOrEqualTo(43));
    expect(p.verifier.length, lessThanOrEqualTo(128));
    expect(p.challenge, Pkce.challengeOf(p.verifier));
    // Cross-checked with Python's hashlib (the server does the same in Go):
    // base64url(sha256(verifier)) without padding.
    expect(Pkce.challengeOf('dBjftJeZ4CVP-mJ92K1riNkE5c0bpIM0x6nG1NvQyQk'),
        'WNKUZtErcB9j0A1L111FDIHYkjooLlLHKZ7Sxz9R_Es');
  });

  test('sign-in address on the instance', () {
    final p = Pkce.generate(Random(2));
    final u = signInUrl(Uri.parse('https://app.example.org'), p);
    expect(u.path, '/identify');
    expect(u.queryParameters['client_id'], 'phoedox-app');
    expect(u.queryParameters['redirect_uri'], 'phoedox://signin');
    expect(u.queryParameters['code_challenge'], p.challenge);
    expect(u.queryParameters['state'], p.state);
  });

  test('the answer must carry our state', () {
    final p = Pkce.generate(Random(3));
    expect(codeFrom('phoedox://signin?code=abc&state=${p.state}', p), 'abc');
    expect(codeFrom('phoedox://signin?code=abc&state=other', p), isNull);
    expect(
        codeFrom('https://evil.example/?code=abc&state=${p.state}', p), isNull);
    expect(codeFrom('phoedox://signin?state=${p.state}', p), isNull);
  });
}
