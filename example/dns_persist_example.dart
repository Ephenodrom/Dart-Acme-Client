import 'dart:convert';
import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  final privateKeyPem =
      '''-----BEGIN RSA PRIVATE KEY----- ... -----END RSA PRIVATE KEY-----''';

  final publicKeyPem =
      '''-----BEGIN PUBLIC KEY----- ... -----END PUBLIC KEY-----''';

  final csr =
      '''-----BEGIN CERTIFICATE REQUEST----- ... -----END CERTIFICATE REQUEST-----''';

  final domain = 'example.com';

  final client = AcmeClient(
    'https://acme-staging-v02.api.letsencrypt.org',
    privateKeyPem,
    publicKeyPem,
    true,
    ['mailto:jon@doe.com'],
  );

  await client.init();

  final order = await client.order(
    Order(
      identifiers: [Identifiers(type: 'dns', value: domain)],
    ),
  );

  final persistData = await client.getDnsPersistDcvDataForOrder(
    order,
    identifier: domain,
    policy: 'wildcard',
  );

  print('Publish the following TXT record:');
  print(persistData.toBindString());
  print('Press Enter once the DNS record is visible to the CA');
  stdin.readLineSync(encoding: utf8);

  final authValid = await client.validate(persistData.challenge);
  if (!authValid) {
    print('Authorization failed');
    exit(1);
  }

  final ready = await client.isReady(order);
  if (!ready) {
    print('Order is not ready');
    exit(1);
  }

  final finalizedOrder = await client.finalizeOrder(order, csr);
  final certificates = await client.getCertificate(finalizedOrder);
  print(jsonEncode(certificates));
}
