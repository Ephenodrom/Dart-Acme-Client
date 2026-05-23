// Tests keep a few long diagnostic strings intact for readability.
// ignore_for_file: lines_longer_than_80_chars

import 'package:acme_client/src/acme_account_credentials.dart';
import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/acme_connection.dart';
import 'package:acme_client/src/model/account.dart';
import 'package:acme_client/src/model/acme_directories.dart';
import 'package:acme_client/src/model/dns_challenge.dart';
import 'package:acme_client/src/model/dns_persist_challenge.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// @Throwing(ArgumentError, reason: 'matcher input validation may fail while asserting thrown exceptions in tests')
void main() {
  test(
    'validateData throws AcmeConfigurationException for invalid contacts',
    () {
      const client = AcmeConnection(
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
      const client = AcmeConnection(baseUrl: '');
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

  test(
    'createOrder repackages JWS construction failures as AcmeJwsException',
    () {
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
          Account(accountURL: 'https://example.com/acme/account/1'),
          client,
        ),
      );

      expect(
        () => acmeConnectionAccount(
          client,
        )!.createOrderForHttp(identifiers: const []),
        throwsA(isA<AcmeJwsException>()),
      );
    },
  );

  test(
    'validate does not parse public JWK for kid-based challenge requests',
    () async {
      final generated = AcmeAccountCredentials.generate(
        acceptTerms: true,
        contacts: const ['mailto:admin@example.com'],
      );
      final dio = _buildMockDio((options) {
        switch ('${options.method} ${options.uri}') {
          case 'POST https://example.com/acme/challenge/1':
            return _jsonResponse(options, const {'status': 'pending'});
          case 'POST https://example.com/acme/authz/1':
            return _jsonResponse(options, {
              'status': 'valid',
              'identifier': {'type': 'dns', 'value': 'example.com'},
              'challenges': const <Object?>[],
            });
        }
        throw StateError(
          'Unexpected request: ${options.method} ${options.uri}',
        );
      });
      final client = acmeConnectionBindCredentials(
        AcmeConnection(
          baseUrl: 'https://acme-staging-v02.api.letsencrypt.org',
          dio: dio,
        ),
        AcmeAccountCredentials(
          privateKeyPem: generated.privateKeyPem,
          publicKeyPem: 'not-a-public-key',
          acceptTerms: true,
          contacts: const ['mailto:admin@example.com'],
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

      await expectLater(acmeConnectionValidate(client, challenge), completes);
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

Dio _buildMockDio(
  Response<Object?> Function(RequestOptions options) responder,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(responder(options)),
    ),
  );
  return dio;
}

Response<Object?> _jsonResponse(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  Map<String, List<String>> headers = const {},
}) => Response<Object?>(
  requestOptions: options,
  data: data,
  statusCode: statusCode,
  headers: Headers.fromMap({
    'replay-nonce': ['nonce-next'],
    ...headers,
  }),
);
