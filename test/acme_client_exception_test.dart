import 'package:acme_client/acme_client.dart';
import 'package:test/test.dart';

/// @Throwing(ArgumentError, reason: 'matcher input validation may fail while asserting thrown exceptions in tests')
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

  test('order repackages JWS construction failures as AcmeJwsException', () {
    final client = AcmeClient(
      'https://acme-staging-v02.api.letsencrypt.org',
      'not-a-private-key',
      'not-a-public-key',
      true,
      ['mailto:admin@example.com'],
    )
      ..directories = AcmeDirectories(
        newOrder: 'https://example.com/acme/new-order',
      )
      ..account = Account(accountURL: 'https://example.com/acme/account/1')
      ..nonce = 'nonce';

    expect(
      () => client.order(Order()),
      throwsA(isA<AcmeJwsException>()),
    );
  });

  test(
      'validate repackages key digest failures as AcmeAccountKeyDigestException',
      () {
    final client = AcmeClient(
      'https://acme-staging-v02.api.letsencrypt.org',
      'private',
      'not-a-public-key',
      true,
      ['mailto:admin@example.com'],
    )
      ..account = Account(accountURL: 'https://example.com/acme/account/1')
      ..nonce = 'nonce';

    final challenge = Challenge(
      type: VALIDATION_DNS,
      token: 'token',
      url: 'https://example.com/acme/challenge/1',
      authorizationUrl: 'https://example.com/acme/authz/1',
    );

    expect(
      () => client.validate(challenge),
      throwsA(isA<AcmeAccountKeyDigestException>()),
    );
  });

  test('validate rejects malformed dns-persist-01 challenges', () {
    final client = AcmeClient(
      'https://acme-staging-v02.api.letsencrypt.org',
      'private',
      'public',
      true,
      ['mailto:admin@example.com'],
    );

    final challenge = Challenge(
      type: VALIDATION_DNS_PERSIST,
      url: 'https://example.com/acme/challenge/1',
      authorizationUrl: 'https://example.com/acme/authz/1',
    );

    expect(
      () => client.validate(challenge),
      throwsA(isA<AcmeDnsPersistException>()),
    );
  });
}
