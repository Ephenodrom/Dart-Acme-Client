// Tests intentionally keep a few signatures and literals compact.
// ignore_for_file: unnecessary_async

import 'package:acme_client/acme_client.dart';
import 'package:acme_client/src/acme_connection.dart';
import 'package:acme_client/src/model/account.dart';
import 'package:test/test.dart';

void main() {
  test('AcmeAccountCredentials can be generated from scratch', () {
    final credentials = AcmeAccountCredentials.generate(
      acceptTerms: true,
      contacts: const ['mailto:admin@example.com'],
    );

    expect(credentials.privateKeyPem, contains('BEGIN'));
    expect(credentials.publicKeyPem, contains('BEGIN'));
    expect(credentials.acceptTerms, isTrue);
    expect(credentials.contacts, ['mailto:admin@example.com']);
  });

  test('AcmeAccountCredentials round-trip through JSON', () {
    const credentials = AcmeAccountCredentials(
      privateKeyPem: 'private-pem',
      publicKeyPem: 'public-pem',
      acceptTerms: true,
      contacts: ['mailto:admin@example.com'],
    );

    final restored = AcmeAccountCredentials.fromMap(credentials.toMap());

    expect(restored.privateKeyPem, credentials.privateKeyPem);
    expect(restored.publicKeyPem, credentials.publicKeyPem);
    expect(restored.acceptTerms, credentials.acceptTerms);
    expect(restored.contacts, credentials.contacts);
  });

  test('AcmeAccountCredentials round-trip through JSON string', () {
    const credentials = AcmeAccountCredentials(
      privateKeyPem: 'private-pem',
      publicKeyPem: 'public-pem',
      acceptTerms: true,
      contacts: ['mailto:admin@example.com'],
    );

    final restored = AcmeAccountCredentials.fromJson(credentials.toJson());

    expect(restored.privateKeyPem, credentials.privateKeyPem);
    expect(restored.publicKeyPem, credentials.publicKeyPem);
    expect(restored.acceptTerms, credentials.acceptTerms);
    expect(restored.contacts, credentials.contacts);
  });

  test(
    'AcmeConnection can be recreated from persisted account credentials',
    () async {
      const connection = AcmeConnection(baseUrl: 'https://example.com/acme');
      const credentials = AcmeAccountCredentials(
        privateKeyPem: 'private-pem',
        publicKeyPem: 'public-pem',
        acceptTerms: true,
        contacts: ['mailto:admin@example.com'],
      );

      final restored = acmeConnectionToAccountCredentials(
        acmeConnectionBindCredentials(connection, credentials),
      );

      expect(restored.privateKeyPem, credentials.privateKeyPem);
      expect(restored.publicKeyPem, credentials.publicKeyPem);
      expect(restored.acceptTerms, credentials.acceptTerms);
      expect(restored.contacts, credentials.contacts);
    },
  );

  test('attached account can recreate account credentials', () async {
    const credentials = AcmeAccountCredentials(
      privateKeyPem: 'private-pem',
      publicKeyPem: 'public-pem',
      acceptTerms: true,
      contacts: ['mailto:admin@example.com'],
    );
    const connection = AcmeConnection(baseUrl: 'https://example.com/acme');
    final client = acmeConnectionBindCredentials(connection, credentials);
    final account = acmeAccountAttachConnection(
      Account(accountURL: 'https://example.com/acme/account/1'),
      client,
    );

    final restored = account.toAccountCredentials();

    expect(restored.privateKeyPem, credentials.privateKeyPem);
    expect(restored.publicKeyPem, credentials.publicKeyPem);
    expect(restored.contacts, credentials.contacts);
  });

  test(
    'account wrappers delegate validation helpers to the attached connection',
    () async {
      const credentials = AcmeAccountCredentials(
        privateKeyPem: 'private-pem',
        publicKeyPem: 'public-pem',
        acceptTerms: true,
        contacts: ['mailto:admin@example.com'],
      );
      const connection = AcmeConnection(baseUrl: 'https://example.com/acme');
      final client = acmeConnectionBindCredentials(connection, credentials);
      acmeConnectionTestSetAccount(
        client,
        Account(accountURL: 'https://example.com/acme/account/1'),
      );
      final account = acmeAccountAttachConnection(
        Account(accountURL: 'https://example.com/acme/account/1'),
        client,
      );

      expect(account.toAccountCredentials().contacts, credentials.contacts);
    },
  );
}
