import 'package:flutter_test/flutter_test.dart';
import 'package:phoedox/app/session.dart';

void main() {
  test('instance addresses are normalized', () {
    expect(
        instanceUri('app.example.org').toString(), 'https://app.example.org');
    expect(instanceUri(' https://app.example.org/login ').toString(),
        'https://app.example.org');
    expect(instanceUri('http://localhost:8080').toString(),
        'http://localhost:8080');
  });
}
