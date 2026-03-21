import 'package:acme_client/acme_client.dart';
import 'package:test/test.dart';

void main() {
  test('validateData throws AcmeConfigurationException for invalid contacts',
      () {
    final client = AcmeClient(
      'https://acme-staging-v02.api.letsencrypt.org',
      'private',
      'public',
      true,
      ['admin@example.com'],
    );

    expect(
      client.validateData,
      throwsA(isA<AcmeConfigurationException>()),
    );
  });

  test('validateData throws AcmeConfigurationException for missing baseUrl',
      () {
    final client = AcmeClient(
      '',
      'private',
      'public',
      true,
      ['mailto:admin@example.com'],
    );

    expect(
      client.validateData,
      throwsA(isA<AcmeConfigurationException>()),
    );
  });
}
