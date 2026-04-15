// Integration-style test setup keeps long environment names and URLs intact.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:io';

import 'package:acme_client/acme_client.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:test/test.dart';

const _pebbleEnabledEnv = 'ACME_PEBBLE_ENABLE_TESTS';
const _pebbleBaseUrlEnv = 'ACME_PEBBLE_BASE_URL';
const _pebbleManagementUrlEnv = 'ACME_PEBBLE_MANAGEMENT_URL';
const _pebbleHttp01AddressEnv = 'ACME_PEBBLE_HTTP01_ADDRESS';
const _pebbleTrustedRootEnv = 'ACME_PEBBLE_TRUSTED_ROOT';
const _pebbleConfigPathEnv = 'ACME_PEBBLE_CONFIG_PATH';
const _defaultPebbleConfigPath = 'tool/pebble/pebble-test.local.json';

/// @Throwing(ArgumentError)
void main() {
  final enabled = Platform.environment[_pebbleEnabledEnv] == 'true';
  final baseUrl =
      Platform.environment[_pebbleBaseUrlEnv] ?? 'https://localhost:14000/dir';
  final managementUrl =
      Platform.environment[_pebbleManagementUrlEnv] ?? 'http://localhost:8055';
  final trustedRootPath = Platform.environment[_pebbleTrustedRootEnv];
  final pebbleConfigPath =
      Platform.environment[_pebbleConfigPathEnv] ?? _defaultPebbleConfigPath;

  group('Pebble integration', () {
    late Dio dio;
    late AcmeConnection connection;
    late AcmeAccountCredentials accountCredentials;
    late String http01Address;

    setUpAll(() async {
      dio = _buildPebbleDio(trustedRootPath);
      connection = AcmeConnection(baseUrl: baseUrl, dio: dio);
      accountCredentials = _loadPebbleCredentials(pebbleConfigPath);
      http01Address = await _resolveHttp01Address();
    });

    test(
      'http-01 acquisition and renewal',
      () async {
        final account = await _fetchOrCreateAccount(
          accountCredentials,
          connection,
        );
        const identifier = DomainIdentifier('challtestsrv');
        final certificateCredentials = CertificateCredentials.generate(
          identifiers: const [DomainIdentifier('challtestsrv')],
        );

        final firstChain = await _issueHttpCertificate(
          account: account,
          identifier: identifier,
          certificateCredentials: certificateCredentials,
          managementUrl: managementUrl,
          http01Address: http01Address,
        );
        final renewalChain = await _issueHttpCertificate(
          account: account,
          identifier: identifier,
          certificateCredentials: certificateCredentials,
          managementUrl: managementUrl,
          http01Address: http01Address,
        );

        expect(firstChain, isNotEmpty);
        expect(renewalChain, isNotEmpty);
      },
      skip: enabled
          ? false
          : 'Set $_pebbleEnabledEnv=true to run against the local Pebble harness.',
    );

    test(
      'dns-01 acquisition and renewal',
      () async {
        final account = await _fetchOrCreateAccount(
          accountCredentials,
          connection,
        );
        const identifier = DomainIdentifier('dns-example.com');
        final certificateCredentials = CertificateCredentials.generate(
          identifiers: const [DomainIdentifier('dns-example.com')],
        );

        final firstChain = await _issueDnsCertificate(
          account: account,
          identifier: identifier,
          certificateCredentials: certificateCredentials,
          managementUrl: managementUrl,
        );
        final renewalChain = await _issueDnsCertificate(
          account: account,
          identifier: identifier,
          certificateCredentials: certificateCredentials,
          managementUrl: managementUrl,
        );

        expect(firstChain, isNotEmpty);
        expect(renewalChain, isNotEmpty);
      },
      skip: enabled
          ? false
          : 'Set $_pebbleEnabledEnv=true to run against the local Pebble harness.',
    );

    test(
      'dns-persist-01 acquisition and renewal',
      () async {
        final account = await _fetchOrCreateAccount(
          accountCredentials,
          connection,
        );
        const identifier = DomainIdentifier('persist-example.com');
        final certificateCredentials = CertificateCredentials.generate(
          identifiers: const [DomainIdentifier('persist-example.com')],
        );

        final firstChain = await _issueDnsPersistCertificate(
          account: account,
          identifier: identifier,
          certificateCredentials: certificateCredentials,
          managementUrl: managementUrl,
        );
        final renewalChain = await _issueDnsPersistCertificate(
          account: account,
          identifier: identifier,
          certificateCredentials: certificateCredentials,
          managementUrl: managementUrl,
        );

        expect(firstChain, isNotEmpty);
        expect(renewalChain, isNotEmpty);
      },
      skip: enabled
          ? false
          : 'Set $_pebbleEnabledEnv=true to run against the local Pebble harness.',
    );
  });
}

Future<Account> _fetchOrCreateAccount(
  AcmeAccountCredentials credentials,
  AcmeConnection connection,
) async {
  try {
    return await Account.fetch(credentials, connection: connection);
  } on AcmeAccountException {
    return Account.create(credentials, connection: connection);
  }
}

/// @Throwing(ArgumentError)
Future<List<String>> _issueHttpCertificate({
  required Account account,
  required DomainIdentifier identifier,
  required CertificateCredentials certificateCredentials,
  required String managementUrl,
  required String http01Address,
}) async {
  await _configureHttpValidationHost(
    managementUrl,
    identifier.value,
    http01Address,
  );

  final order = await account.createOrderForHttp(identifiers: [identifier]);
  final authorization = await order.getAuthorization(identifier);
  final challenge = authorization.getChallenge();
  final proof = challenge.buildProof();

  await _publishHttpChallenge(
    managementUrl,
    token: proof.pathToWellKnownChallenge.split('/').last,
    content: proof.wellKnownChallengeFileContent,
  );

  final authValid = await challenge.validate();
  expect(authValid, isTrue);

  await _waitForOrderReady(order);
  await order.finalize(certificateCredentials);
  final certs = await order.getCertificates();
  expect(certs, isNotEmpty);
  return certs;
}

/// @Throwing(ArgumentError)
Future<List<String>> _issueDnsCertificate({
  required Account account,
  required DomainIdentifier identifier,
  required CertificateCredentials certificateCredentials,
  required String managementUrl,
}) async {
  final order = await account.createOrderForDns(identifiers: [identifier]);
  final authorization = await order.getAuthorization(identifier);
  final challenge = authorization.getChallenge();
  final proof = challenge.buildProof();

  await _publishTxtRecord(
    managementUrl,
    _normalizeTxtHost(proof.txtRecordName),
    proof.txtRecordValue,
  );

  final authValid = await challenge.validate();
  expect(authValid, isTrue);

  await _waitForOrderReady(order);
  await order.finalize(certificateCredentials);
  final certs = await order.getCertificates();
  expect(certs, isNotEmpty);
  return certs;
}

/// @Throwing(ArgumentError)
Future<List<String>> _issueDnsPersistCertificate({
  required Account account,
  required DomainIdentifier identifier,
  required CertificateCredentials certificateCredentials,
  required String managementUrl,
}) async {
  final order = await account.createOrderForDnsPersist(
    identifiers: [identifier],
  );
  final authorization = await order.getAuthorization(identifier);
  final challenge = authorization.getChallenge();
  final proof = challenge.buildProof();

  await _publishTxtRecord(
    managementUrl,
    _normalizeTxtHost(proof.txtRecordName),
    proof.txtRecordValue,
  );

  final authValid = await challenge.validate();
  expect(authValid, isTrue);

  await _waitForOrderReady(order);
  await order.finalize(certificateCredentials);
  final certs = await order.getCertificates();
  expect(certs, isNotEmpty);
  return certs;
}

Future<void> _waitForOrderReady<TChallenge extends Challenge>(
  ChallengeOrder<TChallenge> order, {
  int maxAttempts = 10,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (await order.isReady()) {
      return;
    }
    await Future.delayed(const Duration(seconds: 1), () {});
  }
  fail('Order did not become ready in time');
}

/// @Throwing(ArgumentError)
AcmeAccountCredentials _loadPebbleCredentials(String configPath) {
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    throw ArgumentError(
      'Pebble config file not found at $configPath. '
      'Copy tool/pebble/pebble-test.example.json to $configPath and add your key pair.',
    );
  }

  final decoded = json.decode(configFile.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw ArgumentError(
      'Pebble config file at $configPath must contain a JSON object.',
    );
  }

  final privateKeyPem = decoded['privateKeyPem'];
  final publicKeyPem = decoded['publicKeyPem'];
  if (privateKeyPem is! String || privateKeyPem.isEmpty) {
    throw ArgumentError(
      'Pebble config file at $configPath is missing a non-empty privateKeyPem.',
    );
  }
  if (publicKeyPem is! String || publicKeyPem.isEmpty) {
    throw ArgumentError(
      'Pebble config file at $configPath is missing a non-empty publicKeyPem.',
    );
  }

  final contactsValue = decoded['contacts'];
  final contacts = contactsValue is List
      ? contactsValue.whereType<String>().toList()
      : const <String>[];

  return AcmeAccountCredentials(
    privateKeyPem: privateKeyPem,
    publicKeyPem: publicKeyPem,
    acceptTerms: decoded['acceptTerms'] == true,
    contacts: contacts.isEmpty ? ['mailto:test@example.com'] : contacts,
  );
}

Future<void> _publishTxtRecord(
  String managementUrl,
  String host,
  String value,
) async {
  final managementClient = Dio();
  await managementClient.post<void>(
    '$managementUrl/set-txt',
    data: json.encode({'host': host, 'value': value}),
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
}

Future<void> _publishHttpChallenge(
  String managementUrl, {
  required String token,
  required String content,
}) async {
  final managementClient = Dio();
  await managementClient.post<void>(
    '$managementUrl/add-http01',
    data: json.encode({'token': token, 'content': content}),
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
}

Future<void> _configureHttpValidationHost(
  String managementUrl,
  String host,
  String address,
) async {
  final managementClient = Dio();
  await managementClient.post<void>(
    '$managementUrl/add-a',
    data: json.encode({
      'host': host,
      'addresses': [address],
    }),
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
  await managementClient.post<void>(
    '$managementUrl/add-aaaa',
    data: json.encode({
      'host': host,
      'addresses': ['::ffff:$address'],
    }),
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
}

Future<String> _resolveHttp01Address() async {
  final configured = Platform.environment[_pebbleHttp01AddressEnv];
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }

  final result = await Process.run(
    'docker',
    const [
      'inspect',
      '-f',
      '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}',
      'pebble-challtestsrv-1',
    ],
  );
  if (result.exitCode == 0) {
    final address = '${result.stdout}'.trim();
    if (address.isNotEmpty) {
      return address;
    }
  }

  return '127.0.0.1';
}

String _normalizeTxtHost(String host) => host.endsWith('.') ? host : '$host.';

Dio _buildPebbleDio(String? trustedRootPath) =>
    Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final context = SecurityContext();
          if (trustedRootPath != null && trustedRootPath.isNotEmpty) {
            context.setTrustedCertificates(trustedRootPath);
          }
          final client = HttpClient(context: context);
          if (trustedRootPath == null || trustedRootPath.isEmpty) {
            client.badCertificateCallback = (certificate, host, port) => true;
          }
          return client;
        },
      );
