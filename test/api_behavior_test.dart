import 'package:acme_client/acme_client.dart';
import 'package:acme_client/src/acme_connection.dart';
import 'package:acme_client/src/model/account.dart';
import 'package:acme_client/src/model/acme_directories.dart';
import 'package:acme_client/src/model/challenge_validation.dart';
import 'package:acme_client/src/model/order.dart';
import 'package:acme_client/src/payloads/empty_validation_payload.dart';
import 'package:acme_client/src/wire/account_resource.dart';
import 'package:acme_client/src/wire/challenge_resource.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('account resource mapping', () {
    test('defaults missing account fields to clean public values', () {
      final account = acmeAccountFromResponseMap(const {});

      expect(account.contact, isEmpty);
      expect(account.status, AccountStatus.unknown);
      expect(account.termsOfServiceAgreed, isFalse);
      expect(account.ordersUrl, isNull);
    });

    test('maps status and orders URL into typed public fields', () {
      final account = acmeAccountFromResponseMap({
        'contact': ['mailto:admin@example.com'],
        'status': 'valid',
        'termsOfServiceAgreed': true,
        'orders': 'https://ca.example/acct/1/orders',
      });

      expect(account.contact, ['mailto:admin@example.com']);
      expect(account.status, AccountStatus.valid);
      expect(account.termsOfServiceAgreed, isTrue);
      expect(
        account.ordersUrl?.value.toString(),
        'https://ca.example/acct/1/orders',
      );
    });
  });

  test(
    'dns-persist challenge mapping defaults issuer domain names to empty',
    () {
      final challenge =
          acmeChallengeFromResource(
                acmeChallengeResourceFromMap(const {'type': 'dns-persist-01'}),
              )
              as DnsPersistChallenge;

      expect(challenge.issuerDomainNames, isEmpty);
    },
  );

  test('challenge validation uses empty payloads for supported challenge types',
      () {
    expect(
      acmeChallengeCreateValidationPayload(
        DnsChallenge(token: 'token', url: 'https://ca.example/challenge/1'),
      ),
      isA<EmptyValidationPayload>(),
    );
    expect(
      acmeChallengeCreateValidationPayload(
        HttpChallenge(token: 'token', url: 'https://ca.example/challenge/2'),
      ),
      isA<EmptyValidationPayload>(),
    );
    expect(
      acmeChallengeCreateValidationPayload(
        DnsPersistChallenge(
          token: 'token',
          url: 'https://ca.example/challenge/3',
          issuerDomainNames: const ['issuer.example.net'],
        ),
      ),
      isA<EmptyValidationPayload>(),
    );
  });

  test('unsupported challenge types are ignored during list parsing', () {
    final resources = acmeChallengeResourceListFromValue([
      {'type': 'dns-account-01', 'token': 'ignored'},
      {
        'type': 'dns-persist-01',
        'token': 'kept',
        'issuer-domain-names': ['issuer.example.net'],
      },
    ]);

    expect(resources, hasLength(1));
    expect(resources!.single.type, ChallengeType.dnsPersist);
    expect(resources.single.token, 'kept');
  });

  test(
    'discoverAvailableChallenges de-duplicates repeated challenge types',
    () async {
      final dio = _buildMockDio((options) {
        switch ('${options.method} ${options.uri}') {
          case 'POST https://ca.example/acme/new-order':
            return _jsonResponse(
              options,
              {
                'status': 'pending',
                'authorizations': [
                  'https://ca.example/acme/authz/1',
                  'https://ca.example/acme/authz/2',
                ],
                'finalize': 'https://ca.example/acme/order/1/finalize',
                'identifiers': [
                  {'type': 'dns', 'value': 'example.com'},
                ],
              },
              headers: const {
                'location': ['https://ca.example/acme/order/1'],
              },
            );
          case 'POST https://ca.example/acme/authz/1':
            return _jsonResponse(options, {
              'status': 'pending',
              'identifier': {'type': 'dns', 'value': 'example.com'},
              'challenges': [
                {
                  'type': 'dns-01',
                  'url': 'https://ca.example/acme/challenge/dns-1',
                  'token': 'dns-token-1',
                },
                {
                  'type': 'http-01',
                  'url': 'https://ca.example/acme/challenge/http-1',
                  'token': 'http-token-1',
                },
                {
                  'type': 'dns-01',
                  'url': 'https://ca.example/acme/challenge/dns-2',
                  'token': 'dns-token-2',
                },
              ],
            });
          case 'POST https://ca.example/acme/authz/2':
            return _jsonResponse(options, {
              'status': 'pending',
              'identifier': {'type': 'dns', 'value': 'example.com'},
              'challenges': [
                {
                  'type': 'dns-persist-01',
                  'url': 'https://ca.example/acme/challenge/persist-1',
                  'issuer-domain-names': ['issuer.example'],
                },
                {
                  'type': 'http-01',
                  'url': 'https://ca.example/acme/challenge/http-2',
                  'token': 'http-token-2',
                },
              ],
            });
        }
        throw StateError(
          'Unexpected request: ${options.method} ${options.uri}',
        );
      });

      final connection = _boundConnection(dio);
      acmeConnectionTestSetDirectories(
        connection,
        AcmeDirectories(
          newNonce: 'https://ca.example/acme/new-nonce',
          newOrder: 'https://ca.example/acme/new-order',
        ),
      );
      acmeConnectionTestSetNonce(connection, 'nonce-1');

      final account = acmeAccountAttachConnection(
        Account(accountURL: 'https://ca.example/acme/acct/1'),
        connection,
      );

      final available = await account.discoverAvailableChallenges(
        identifier: const DomainIdentifier('example.com'),
      );

      expect(available, [
        ChallengeType.dns,
        ChallengeType.http,
        ChallengeType.dnsPersist,
      ]);
    },
  );

  test('createOrderForDnsPersist reports supported challenge types'
      ' when unsupported', () async {
    final dio = _buildMockDio((options) {
      switch ('${options.method} ${options.uri}') {
        case 'POST https://ca.example/acme/new-order':
          return _jsonResponse(
            options,
            {
              'status': 'pending',
              'authorizations': ['https://ca.example/acme/authz/1'],
              'finalize': 'https://ca.example/acme/order/1/finalize',
              'identifiers': [
                {'type': 'dns', 'value': 'example.com'},
              ],
            },
            headers: const {
              'location': ['https://ca.example/acme/order/1'],
            },
          );
        case 'POST https://ca.example/acme/authz/1':
          return _jsonResponse(options, {
            'status': 'pending',
            'identifier': {'type': 'dns', 'value': 'example.com'},
            'challenges': [
              {
                'type': 'dns-01',
                'url': 'https://ca.example/acme/challenge/dns-1',
                'token': 'dns-token-1',
              },
              {
                'type': 'http-01',
                'url': 'https://ca.example/acme/challenge/http-1',
                'token': 'http-token-1',
              },
            ],
          });
      }
      throw StateError('Unexpected request: ${options.method} ${options.uri}');
    });

    final connection = _boundConnection(dio);
    acmeConnectionTestSetDirectories(
      connection,
      AcmeDirectories(
        newNonce: 'https://ca.example/acme/new-nonce',
        newOrder: 'https://ca.example/acme/new-order',
      ),
    );
    acmeConnectionTestSetNonce(connection, 'nonce-1');

    final account = acmeAccountAttachConnection(
      Account(accountURL: 'https://ca.example/acme/acct/1'),
      connection,
    );

    await expectLater(
      account.createOrderForDnsPersist(
        identifiers: const [DomainIdentifier('example.com')],
      ),
      throwsA(
        isA<AcmeAuthorizationException>()
            .having((e) => e.detail ?? '', 'detail', contains('dns-persist-01'))
            .having(
              (e) => '${e.rawBody}',
              'rawBody',
              allOf(contains('dns-01'), contains('http-01')),
            ),
      ),
    );
  });

  test('ChallengeOrder.finalize rejects certificate identifiers'
      ' that do not match the order', () async {
    final connection = _boundConnection(Dio());
    final account = acmeAccountAttachConnection(
      Account(accountURL: 'https://ca.example/acme/acct/1'),
      connection,
    );
    final order = acmeOrderAttachConnection(
      Order(
        identifiers: const [DomainIdentifier('example.com')],
        finalizeUrl: 'https://ca.example/acme/order/1/finalize',
        orderUrl: 'https://ca.example/acme/order/1',
      ),
      connection,
      account,
    );
    final challengeOrder = ChallengeOrder<HttpChallenge>.internal(
      order,
      connection,
      account,
    );
    final credentials = CertificateCredentials.generate(
      identifiers: const [DomainIdentifier('other.example.com')],
    );

    await expectLater(
      challengeOrder.finalize(credentials),
      throwsA(
        isA<AcmeConfigurationException>().having(
          (e) => e.message,
          'message',
          contains('do not match the identifiers on this order'),
        ),
      ),
    );
  });

  test(
    'ChallengeOrder.finalize accepts matching identifiers by value',
    () async {
    final dio = _buildMockDio((options) {
      switch ('${options.method} ${options.uri}') {
        case 'POST https://ca.example/acme/order/1/finalize':
          return _jsonResponse(options, {
            'status': 'valid',
            'certificate': 'https://ca.example/acme/cert/1',
            'authorizations': ['https://ca.example/acme/authz/1'],
            'finalize': 'https://ca.example/acme/order/1/finalize',
            'identifiers': [
              {'type': 'dns', 'value': 'example.com'},
            ],
          });
      }
      throw StateError('Unexpected request: ${options.method} ${options.uri}');
    });

    final connection = _boundConnection(dio);
    acmeConnectionTestSetDirectories(
      connection,
      AcmeDirectories(newNonce: 'https://ca.example/acme/new-nonce'),
    );
    acmeConnectionTestSetNonce(connection, 'nonce-1');

    final account = acmeAccountAttachConnection(
      Account(accountURL: 'https://ca.example/acme/acct/1'),
      connection,
    );
    final order = acmeOrderAttachConnection(
      Order(
        identifiers: const [DomainIdentifier('example.com')],
        finalizeUrl: 'https://ca.example/acme/order/1/finalize',
        orderUrl: 'https://ca.example/acme/order/1',
      ),
      connection,
      account,
    );
    final challengeOrder = ChallengeOrder<HttpChallenge>.internal(
      order,
      connection,
      account,
    );
    final credentials = CertificateCredentials.generate(
      identifiers: const [DomainIdentifier('example.com')],
    );

    await expectLater(challengeOrder.finalize(credentials), completes);
  });

  test('Order.finalize polls order status using signed POST-as-GET', () async {
    final requests = <String>[];
    final dio = _buildMockDio((options) {
      requests.add('${options.method} ${options.uri}');
      switch ('${options.method} ${options.uri}') {
        case 'POST https://ca.example/acme/order/1/finalize':
          return _jsonResponse(options, {
            'status': 'processing',
            'authorizations': ['https://ca.example/acme/authz/1'],
            'finalize': 'https://ca.example/acme/order/1/finalize',
            'identifiers': [
              {'type': 'dns', 'value': 'example.com'},
            ],
          });
        case 'POST https://ca.example/acme/order/1':
          return _jsonResponse(options, {
            'status': 'valid',
            'certificate': 'https://ca.example/acme/cert/1',
            'authorizations': ['https://ca.example/acme/authz/1'],
            'finalize': 'https://ca.example/acme/order/1/finalize',
            'identifiers': [
              {'type': 'dns', 'value': 'example.com'},
            ],
          });
      }
      throw StateError('Unexpected request: ${options.method} ${options.uri}');
    });

    final connection = _boundConnection(dio);
    acmeConnectionTestSetDirectories(
      connection,
      AcmeDirectories(newNonce: 'https://ca.example/acme/new-nonce'),
    );
    acmeConnectionTestSetNonce(connection, 'nonce-1');

    final account = acmeAccountAttachConnection(
      Account(accountURL: 'https://ca.example/acme/acct/1'),
      connection,
    );
    final order = acmeOrderAttachConnection(
      Order(
        identifiers: const [DomainIdentifier('example.com')],
        finalizeUrl: 'https://ca.example/acme/order/1/finalize',
        orderUrl: 'https://ca.example/acme/order/1',
      ),
      connection,
      account,
    );

    final credentials = CertificateCredentials.generate(
      identifiers: const [DomainIdentifier('example.com')],
    );

    final finalizedOrder = await order.finalize(credentials.csrPem, retries: 2);

    expect(finalizedOrder.certificate, 'https://ca.example/acme/cert/1');
    expect(
      requests,
      containsAllInOrder([
        'POST https://ca.example/acme/order/1/finalize',
        'POST https://ca.example/acme/order/1',
      ]),
    );
    expect(
      requests,
      isNot(contains('GET https://ca.example/acme/order/1')),
    );
  });
}

AcmeConnection _boundConnection(Dio dio) => acmeConnectionBindCredentials(
  AcmeConnection(baseUrl: 'https://ca.example/acme/directory', dio: dio),
  AcmeAccountCredentials.generate(
    acceptTerms: true,
    contacts: const ['mailto:test@example.com'],
  ),
);

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
