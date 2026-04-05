// Live staging inspection uses long environment names and JSON dumps.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:io';

import 'package:acme_client/acme_client.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const _configPathEnv = 'ACME_LE_STAGING_CONFIG_PATH';
const _defaultConfigPath = 'tool/le-staging/le-staging.local.yaml';

void main() {
  final config = _loadConfig();

  group('LE staging system', () {
    test(
      'dns-persist-01 challenge inspection',
      () async {
        final capturedAuthorizations = <Map<String, Object?>>[];
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              final data = response.data;
              if (data is Map<String, Object?> && data['challenges'] is List) {
                capturedAuthorizations.add(data);
              }
              handler.next(response);
            },
          ),
        );

        final connection = AcmeConnection.letsEncryptStaging(dio: dio);
        final credentials = AcmeAccountCredentials.generate(
          acceptTerms: true,
          contacts: [config.contact],
        );

        final account = await Account.create(
          credentials,
          connection: connection,
        );
        final identifier = DomainIdentifier(config.identifier);
        final order = await account.createOrderForDnsPersist(
          identifiers: [identifier],
        );
        final authorization = await order.getAuthorization(identifier);
        final challenge = authorization.getChallenge();
        final proof = challenge.buildProof();

        expect(challenge, isA<DnsPersistChallenge>());
        expect(proof.txtRecordName, '_validation-persist.${config.identifier}');
        expect(proof.accountUri, account.accountURL);

        final dnsPersistChallenge =
            _findDnsPersistChallenge(capturedAuthorizations) ??
            (throw StateError(
              'Could not find a dns-persist-01 challenge in the captured staging authorization response',
            ));

        stderr.writeln(
          'LE staging dns-persist-01 challenge for ${config.identifier}:\n'
          '${const JsonEncoder.withIndent('  ').convert(dnsPersistChallenge)}',
        );
      },
      skip: config.enabled
          ? false
          : "Set enabled: true in ${config.sourcePath} to run against Let's Encrypt staging.",
    );

    test(
      'dns-persist-01 acquisition and renewal via Cloudflare',
      () async {
        final dnsPersist = config.dnsPersist ??
            (throw StateError(
              'dnsPersist configuration is required for the full staging issuance test',
            ));

        final dns = _CloudflareDnsPublisher(
          apiToken: dnsPersist.cloudflareApiToken,
          zoneName: dnsPersist.cloudflareZoneName,
        );
        const connection = AcmeConnection.staging;
        final credentials = AcmeAccountCredentials.generate(
          acceptTerms: true,
          contacts: [config.contact],
        );
        final account = await Account.create(
          credentials,
          connection: connection,
        );
        final identifier = DomainIdentifier(dnsPersist.identifier);
        final certificateCredentials = CertificateCredentials.generate(
          identifiers: [identifier],
        );

        String? publishedRecordName;
        try {
          final firstChain = await _issueDnsPersistCertificate(
            account: account,
            identifier: identifier,
            certificateCredentials: certificateCredentials,
            publishTxt: (host, value) async {
              publishedRecordName = host;
              await dns.upsertTxtRecord(host: host, value: value);
            },
          );
          final renewalChain = await _issueDnsPersistCertificate(
            account: account,
            identifier: identifier,
            certificateCredentials: certificateCredentials,
            publishTxt: (host, value) async {
              publishedRecordName = host;
              await dns.upsertTxtRecord(host: host, value: value);
            },
          );

          expect(firstChain, isNotEmpty);
          expect(renewalChain, isNotEmpty);
        } finally {
          if (publishedRecordName != null) {
            await dns.deleteTxtRecordIfPresent(host: publishedRecordName!);
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
      skip: config.enabled && config.dnsPersist != null
          ? false
          : 'Provide dnsPersist config in ${config.sourcePath} to run the live Cloudflare-backed staging issuance test.',
    );
  });
}

_LeStagingConfig _loadConfig() {
  final configPath = Platform.environment[_configPathEnv] ?? _defaultConfigPath;
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    return _LeStagingConfig.disabled(sourcePath: configPath);
  }

  final loaded = loadYaml(configFile.readAsStringSync());
  if (loaded is! YamlMap) {
    throw ArgumentError('Staging config at $configPath must be a YAML map.');
  }

  final enabled = loaded['enabled'] == true;
  final identifier = (loaded['identifier'] as String?)?.trim();
  final contact = (loaded['contact'] as String?)?.trim();
  final dnsPersistMap = loaded['dnsPersist'];

  _DnsPersistConfig? dnsPersist;
  if (dnsPersistMap is YamlMap) {
    final cloudflare = dnsPersistMap['cloudflare'];
    if (cloudflare is YamlMap) {
      final dnsPersistIdentifier =
          (dnsPersistMap['identifier'] as String?)?.trim();
      final zoneName = (cloudflare['zoneName'] as String?)?.trim();
      final apiToken = (cloudflare['apiToken'] as String?)?.trim();
      if ((dnsPersistIdentifier?.isNotEmpty ?? false) &&
          (zoneName?.isNotEmpty ?? false) &&
          (apiToken?.isNotEmpty ?? false) &&
          apiToken != 'replace-with-cloudflare-api-token') {
        dnsPersist = _DnsPersistConfig(
          identifier: dnsPersistIdentifier!,
          cloudflareZoneName: zoneName!,
          cloudflareApiToken: apiToken!,
        );
      }
    }
  }

  return _LeStagingConfig(
    enabled: enabled,
    identifier: (identifier?.isNotEmpty ?? false) ? identifier! : 'onepub.dev',
    contact: (contact?.isNotEmpty ?? false)
        ? contact!
        : 'mailto:staging-test@acme-client.dev',
    dnsPersist: dnsPersist,
    sourcePath: configPath,
  );
}

Map<String, Object?>? _findDnsPersistChallenge(
  List<Map<String, Object?>> authorizations,
) {
  for (final authorization in authorizations) {
    final challenges = authorization['challenges'];
    if (challenges is! List<Object?>) {
      continue;
    }
    for (final challenge in challenges) {
      if (challenge is! Map<Object?, Object?>) {
        continue;
      }
      final normalized = challenge.map((key, value) => MapEntry('$key', value));
      if (normalized['type'] == 'dns-persist-01') {
        return normalized.cast<String, Object?>();
      }
    }
  }
  return null;
}

Future<List<String>> _issueDnsPersistCertificate({
  required Account account,
  required DomainIdentifier identifier,
  required CertificateCredentials certificateCredentials,
  required Future<void> Function(String host, String value) publishTxt,
}) async {
  final order = await account.createOrderForDnsPersist(
    identifiers: [identifier],
  );
  final authorization = await order.getAuthorization(identifier);
  final challenge = authorization.getChallenge();
  final proof = challenge.buildProof();

  stderr.writeln(
    'Publishing dns-persist record ${proof.txtRecordName} for ${identifier.value}',
  );
  await publishTxt(proof.txtRecordName, proof.txtRecordValue);

  stderr.writeln('Running dns-persist selfTest for ${identifier.value}');
  final selfTestOk = await challenge.selfTest(maxAttempts: 30);
  expect(selfTestOk, isTrue);

  stderr.writeln('Requesting CA validation for ${identifier.value}');
  final authValid = await challenge.validate();
  expect(authValid, isTrue);

  stderr.writeln('Waiting for order ready for ${identifier.value}');
  final ready = await _waitForOrderReady(order);
  expect(ready, isTrue);

  stderr.writeln('Finalizing order for ${identifier.value}');
  await order.finalize(certificateCredentials);
  stderr.writeln('Fetching certificates for ${identifier.value}');
  final certs = await order.getCertificates();
  expect(certs, isNotEmpty);
  return certs;
}

Future<bool> _waitForOrderReady(
  ChallengeOrder<DnsPersistChallenge> order, {
  int maxAttempts = 15,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (await order.isReady()) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

class _CloudflareDnsPublisher {
  _CloudflareDnsPublisher({
    required this.apiToken,
    required this.zoneName,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: 'https://api.cloudflare.com/client/v4',
           headers: {
             'Authorization': 'Bearer $apiToken',
             'Content-Type': 'application/json',
           },
         ),
       );

  final String apiToken;
  final String zoneName;
  final Dio _dio;

  String? _zoneId;

  Future<void> upsertTxtRecord({
    required String host,
    required String value,
  }) async {
    final zoneId = await _getZoneId();
    final existing = await _findTxtRecord(zoneId, host);
    if (existing != null) {
      await _dio.put<Object?>(
        '/zones/$zoneId/dns_records/${existing.id}',
        data: {
          'type': 'TXT',
          'name': host,
          'content': value,
          'ttl': 120,
          'proxied': false,
        },
      );
      return;
    }

    await _dio.post<Object?>(
      '/zones/$zoneId/dns_records',
      data: {
        'type': 'TXT',
        'name': host,
        'content': value,
        'ttl': 120,
        'proxied': false,
      },
    );
  }

  Future<void> deleteTxtRecordIfPresent({required String host}) async {
    final zoneId = await _getZoneId();
    final existing = await _findTxtRecord(zoneId, host);
    if (existing == null) {
      return;
    }

    await _dio.delete<Object?>('/zones/$zoneId/dns_records/${existing.id}');
  }

  Future<String> _getZoneId() async {
    final cached = _zoneId;
    if (cached != null) {
      return cached;
    }

    final response = await _dio.get<Map<String, Object?>>(
      '/zones',
      queryParameters: {'name': zoneName},
    );
    final result = response.data?['result'];
    if (result is! List<Object?> || result.isEmpty) {
      throw StateError('Could not find Cloudflare zone $zoneName');
    }
    final first = result.first;
    if (first is! Map<Object?, Object?> || first['id'] is! String) {
      throw StateError('Cloudflare zone lookup for $zoneName returned no id');
    }
    _zoneId = first['id']! as String;
    return _zoneId!;
  }

  Future<_CloudflareDnsRecord?> _findTxtRecord(String zoneId, String host) async {
    final response = await _dio.get<Map<String, Object?>>(
      '/zones/$zoneId/dns_records',
      queryParameters: {
        'type': 'TXT',
        'name': host,
      },
    );
    final result = response.data?['result'];
    if (result is! List<Object?> || result.isEmpty) {
      return null;
    }
    final first = result.first;
    if (first is! Map<Object?, Object?>) {
      return null;
    }
    final id = first['id'];
    final name = first['name'];
    if (id is! String || name is! String) {
      return null;
    }
    return _CloudflareDnsRecord(id: id, name: name);
  }
}

class _CloudflareDnsRecord {
  const _CloudflareDnsRecord({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _LeStagingConfig {
  const _LeStagingConfig({
    required this.enabled,
    required this.identifier,
    required this.contact,
    required this.dnsPersist,
    required this.sourcePath,
  });

  factory _LeStagingConfig.disabled({required String sourcePath}) =>
      _LeStagingConfig(
        enabled: false,
        identifier: 'onepub.dev',
        contact: 'mailto:staging-test@acme-client.dev',
        dnsPersist: null,
        sourcePath: sourcePath,
      );

  final bool enabled;
  final String identifier;
  final String contact;
  final _DnsPersistConfig? dnsPersist;
  final String sourcePath;
}

class _DnsPersistConfig {
  const _DnsPersistConfig({
    required this.identifier,
    required this.cloudflareZoneName,
    required this.cloudflareApiToken,
  });

  final String identifier;
  final String cloudflareZoneName;
  final String cloudflareApiToken;
}
