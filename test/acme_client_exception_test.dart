import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/acme_account_credentials.dart';
import 'package:acme_client/src/acme_connection.dart';
import 'package:acme_client/src/model/account.dart';
import 'package:acme_client/src/model/acme_directories.dart';
import 'package:acme_client/src/model/dns_challenge.dart';
import 'package:acme_client/src/model/dns_persist_challenge.dart';
import 'package:acme_client/src/model/order.dart';
import 'package:test/test.dart';

/// @Throwing(ArgumentError, reason: 'matcher input validation may fail while asserting thrown exceptions in tests')
void main() {
  test(
    'validateData throws AcmeConfigurationException for invalid contacts',
    () {
      final client = const AcmeConnection(
        baseUrl: 'https://acme-staging-v02.api.letsencrypt.org',
      );
      final boundClient = acmeConnectionBindCredentials(
        client,
        const AcmeAccountCredentials(
          privateKeyPem: 'private',
          publicKeyPem: 'public',
          acceptTerms: true,
          contacts: ['admin@example.com'],
        ),
      );

      expect(
        () => acmeConnectionValidateData(boundClient),
        throwsA(isA<AcmeConfigurationException>()),
      );
    },
  );

  test(
    'validateData throws AcmeConfigurationException for missing baseUrl',
    () {
      final client = const AcmeConnection(baseUrl: '');
      final boundClient = acmeConnectionBindCredentials(
        client,
        const AcmeAccountCredentials(
          privateKeyPem: 'private',
          publicKeyPem: 'public',
          acceptTerms: true,
          contacts: ['mailto:admin@example.com'],
        ),
      );

      expect(
        () => acmeConnectionValidateData(boundClient),
        throwsA(isA<AcmeConfigurationException>()),
      );
    },
  );

  test('createOrder repackages JWS construction failures as AcmeJwsException', () {
    final client = acmeConnectionBindCredentials(
      const AcmeConnection(
        baseUrl: 'https://acme-staging-v02.api.letsencrypt.org',
      ),
      const AcmeAccountCredentials(
        privateKeyPem: 'not-a-private-key',
        publicKeyPem: 'not-a-public-key',
        acceptTerms: true,
        contacts: ['mailto:admin@example.com'],
      ),
    );
    acmeConnectionTestSetDirectories(
      client,
      AcmeDirectories(newOrder: 'https://example.com/acme/new-order'),
    );
    acmeConnectionTestSetNonce(client, 'nonce');
    acmeConnectionTestSetAccount(
      client,
      acmeAccountAttachConnection(
        Account(
          accountURL: 'https://example.com/acme/account/1',
        ),
        client,
      ),
    );

    expect(
      () => acmeConnectionAccount(client)!.createOrder(Order()),
      throwsA(isA<AcmeJwsException>()),
    );
  });

  test(
    'validate repackages key digest failures as AcmeAccountKeyDigestException',
    () {
      final client = acmeConnectionBindCredentials(
        const AcmeConnection(
          baseUrl: 'https://acme-staging-v02.api.letsencrypt.org',
        ),
        const AcmeAccountCredentials(
          privateKeyPem: 'private',
          publicKeyPem: 'not-a-public-key',
          acceptTerms: true,
          contacts: ['mailto:admin@example.com'],
        ),
      );
      acmeConnectionTestSetAccount(
        client,
        Account(accountURL: 'https://example.com/acme/account/1'),
      );
      acmeConnectionTestSetNonce(client, 'nonce');

      final challenge = DnsChallenge(
        token: 'token',
        url: 'https://example.com/acme/challenge/1',
        authorizationUrl: 'https://example.com/acme/authz/1',
      );

      expect(
        () => acmeConnectionValidate(client, challenge),
        throwsA(isA<AcmeAccountKeyDigestException>()),
      );
    },
  );

  test('validate rejects malformed dns-persist-01 challenges', () {
    final client = acmeConnectionBindCredentials(
      const AcmeConnection(
        baseUrl: 'https://acme-staging-v02.api.letsencrypt.org',
      ),
      const AcmeAccountCredentials(
        privateKeyPem: 'private',
        publicKeyPem: 'public',
        acceptTerms: true,
        contacts: ['mailto:admin@example.com'],
      ),
    );

    final challenge = DnsPersistChallenge(
      url: 'https://example.com/acme/challenge/1',
      authorizationUrl: 'https://example.com/acme/authz/1',
    );

    expect(
      () => acmeConnectionValidate(client, challenge),
      throwsA(isA<AcmeDnsPersistException>()),
    );
  });
}
