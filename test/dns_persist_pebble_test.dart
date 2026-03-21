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

  test(
    'Pebble dns-persist-01 end-to-end',
    () async {
      final dio = _buildPebbleDio(trustedRootPath);
      final client = AcmeClient(
        baseUrl,
        _testPrivateKeyPem,
        _testPublicKeyPem,
        true,
        ['mailto:test@example.com'],
        dio: dio,
      );

      await client.init();

      final order = await client.order(
        Order(
          identifiers: [Identifiers(type: 'dns', value: identifier)],
        ),
      );

      final persistData = await client.getDnsPersistDcvDataForOrder(
        order,
        identifier: identifier,
        policy: 'wildcard',
      );

      await _publishTxtRecord(
        managementUrl,
        persistData.rRecord.name,
        persistData.rRecord.data.toString(),
      );

      final authValid = await client.validate(persistData.challenge);
      expect(authValid, isTrue);
    },
    skip: enabled
        ? false
        : 'Set $_pebbleEnabledEnv=true to run against the local Pebble harness.',
  );
}

Future<void> _publishTxtRecord(
  String managementUrl,
  String host,
  String value,
) async {
  final managementClient = Dio();
  await managementClient.post(
    '$managementUrl/set-txt',
    data: json.encode({
      'host': host,
      'value': value,
    }),
    options: Options(
      headers: {'Content-Type': 'application/json'},
    ),
  );
}

Dio _buildPebbleDio(String? trustedRootPath) {
  final dio = Dio();
  dio.httpClientAdapter = IOHttpClientAdapter(
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
  return dio;
}

const _testPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAOr+6EkyKWSipVMk
AXUCpv4Idw3Kq6QSLCFBv4Kkho2b2nDsatenSfJjjSihQbY0RLcS5JB+YKuvbSuH
6Ydy33EYWPCi8kjb7w8HHZkoyRWU8sJw80HxfM2IXZlbWv/nKDBtE9W9aPc06RyK
e2wvIV66yFIHaKKTxhfXUiMxJvLLAgMBAAECgYEAi8f61ec/lfvlSVImh7p/KKZS
YuLGPD8O/u1EBGrnGn61bexDFWoN419yDNP26XGn2hoj2QtDZ3xe/MDImWgsHc7e
98ahDfl7Wrr01KucDI6Ce0A+hkLDpZiCzJcCUdL94G3FmKz/+qizTT1MsB2miW4q
fQYawNZLRiUSodriaEECQQD5desoTKrrywVMyc1x8YkCEi8Ep3elgZo0AHsXcage
xkNvQ9IkibilmtxI/gvxgSDJhax0Y9TynBzQleA9iZ9hAkEA8Sfq8dNJRfFM3CFg
hnwVVWxf/7nUXLAvBvMjzx5dnLbTyH7FbHz6giirLNmqU7aCkAYZHbv2fSgWHox2
CFudqwJAAnCd0TIWxeGhdqPOp5umLGgDH7eHmw3OdU2/5nXNICfuRutR5duW+7+t
AeXCNiV+LZpqGmVTkt/mBEBDBjcPYQJAE7c9wBOUFAHMVNrtt1EBtYAswQ2CTSmi
TqEmNlK3OI7B9cxXe60kFewZQotxH3L2bavx9bpeRpE2bbzyEXDcDQJAat40a3o8
UCWL0h7hfXC2PqBBa1L5HGDAJwryB1y0C6uQ3ydOQSnyGXKru2R9TL6yhWmxF6EC
aXgPLF+G46B8rA==
-----END PRIVATE KEY-----
''';

const _testPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDq/uhJMilkoqVTJAF1Aqb+CHcN
yqukEiwhQb+CpIaNm9pw7GrXp0nyY40ooUG2NES3EuSQfmCrr20rh+mHct9xGFjw
ovJI2+8PBx2ZKMkVlPLCcPNB8XzNiF2ZW1r/5ygwbRPVvWj3NOkcintsLyFeushS
B2iik8YX11IjMSbyywIDAQAB
-----END PUBLIC KEY-----
''';
