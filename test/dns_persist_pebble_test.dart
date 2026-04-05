// Integration-style test setup keeps long environment names and URLs intact.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:io';

import 'package:acme_client/acme_client.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:test/test.dart';

const _pebbleEnabledEnv = 'ACME_PEBBLE_ENABLE_TESTS';
const _pebbleBaseUrlEnv = 'ACME_PEBBLE_BASE_URL';
const _pebbleManagementUrlEnv = 'ACME_PEBBLE_MANAGEMENT_URL';
const _pebbleIdentifierEnv = 'ACME_PEBBLE_IDENTIFIER';
const _pebbleTrustedRootEnv = 'ACME_PEBBLE_TRUSTED_ROOT';
const _pebbleConfigPathEnv = 'ACME_PEBBLE_CONFIG_PATH';
const _defaultPebbleConfigPath = 'tool/pebble/pebble-test.local.json';

/// @Throwing(AcmeAuthorizationException, reason: 'the Pebble test server may not expose dns-persist-01 for the requested identifier')
/// @Throwing(AcmeDirectoryException, reason: 'the Pebble test server directory endpoint may be unavailable')
/// @Throwing(AcmeDnsPersistException, reason: 'the Pebble test server may return malformed dns-persist-01 challenge data')
/// @Throwing(AcmeAccountException, reason: 'the Pebble test account lookup or creation may fail')
/// @Throwing(AcmeJwsException, reason: 'the Pebble test requests may fail to sign')
/// @Throwing(AcmeNonceException, reason: 'the Pebble test server may fail to provide replay nonces')
/// @Throwing(AcmeValidationException, reason: 'the Pebble test dns-persist-01 validation may fail')
/// @Throwing(ArgumentError)
void main() {
  final enabled = Platform.environment[_pebbleEnabledEnv] == 'true';
  final baseUrl =
      Platform.environment[_pebbleBaseUrlEnv] ?? 'https://localhost:14000/dir';
  final managementUrl =
      Platform.environment[_pebbleManagementUrlEnv] ?? 'http://localhost:8055';
  final identifier =
      Platform.environment[_pebbleIdentifierEnv] ?? 'example.com';
  final trustedRootPath = Platform.environment[_pebbleTrustedRootEnv];
  final pebbleConfigPath =
      Platform.environment[_pebbleConfigPathEnv] ?? _defaultPebbleConfigPath;

  test(
    'Pebble dns-persist-01 end-to-end',
    () async {
      final dio = _buildPebbleDio(trustedRootPath);
      final connection = AcmeConnection(baseUrl: baseUrl, dio: dio);
      final credentials = _loadPebbleCredentials(pebbleConfigPath);
      final account = await Account.fetch(credentials, connection: connection);

      final order = await account.createOrderForDnsPersist(
        identifiers: [DomainIdentifier(identifier)],
      );

      final domainIdentifier = DomainIdentifier(identifier);
      final authorization = await order.getAuthorization(domainIdentifier);
      final persistChallenge = authorization.getChallenge();
      final persistProof = persistChallenge.buildProof();

      await _publishTxtRecord(
        managementUrl,
        persistProof.txtRecordName,
        persistProof.txtRecordValue,
      );

      final authValid = await persistChallenge.validate();
      expect(authValid, isTrue);
    },
    skip: enabled
        ? false
        : 'Set $_pebbleEnabledEnv=true to run against the local Pebble harness.',
  );
}

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
