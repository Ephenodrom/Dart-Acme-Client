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

  final connection = AcmeConnection.letsEncryptStaging();
  final credentials = AcmeAccountCredentials(
    privateKeyPem: privateKeyPem,
    publicKeyPem: publicKeyPem,
    acceptTerms: true,
    contacts: ['mailto:jon@doe.com'],
  );
  final account = await Account.fetch(credentials, connection: connection);

  final order = await account.createOrder(
    Order(identifiers: [DomainIdentifier(domain)]),
  );

  final authorizations = await order.getAuthorizations();
  final domainIdentifier = DomainIdentifier(domain);
  final persistChallenge = order.getChallengeForIdentifier<DnsPersistChallenge>(
    domainIdentifier,
    authorizations,
  );
  final persistData = persistChallenge.buildDnsPersistChallengeData(
    domainIdentifier: domainIdentifier,
    accountUri: account.accountURL!,
  );

  print('Publish the following TXT record:');
  print('${persistData.txtRecordName} IN TXT "${persistData.txtRecordValue}"');
  print('Press Enter once the DNS record is visible to the CA');
  stdin.readLineSync(encoding: utf8);

  final authValid = await account.validate(persistData.challenge);
  if (!authValid) {
    print('Authorization failed');
    exit(1);
  }

  final ready = await order.isReady();
  if (!ready) {
    print('Order is not ready');
    exit(1);
  }

  final finalizedOrder = await order.finalize(csr);
  final certificates = await finalizedOrder.getCertificates();
  print(jsonEncode(certificates));
}
