// Example code intentionally prints the manual steps for the operator.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  const privateKeyPem =
      '''-----BEGIN RSA PRIVATE KEY----- ... -----END RSA PRIVATE KEY-----''';

  const publicKeyPem =
      '''-----BEGIN PUBLIC KEY----- ... -----END PUBLIC KEY-----''';

  const domain = 'example.com';

  const connection = AcmeConnection.staging;
  const credentials = AcmeAccountCredentials(
    privateKeyPem: privateKeyPem,
    publicKeyPem: publicKeyPem,
    acceptTerms: true,
    contacts: ['mailto:jon@doe.com'],
  );
  final account = await Account.fetch(credentials, connection: connection);

  const domainIdentifier = DomainIdentifier(domain);
  final certificateCredentials = CertificateCredentials.generate(
    identifiers: [domainIdentifier],
  );
  final order = await account.createOrderForDnsPersist(
    identifiers: [domainIdentifier],
  );

  final authorization = await order.getAuthorization(domainIdentifier);
  final persistChallenge = authorization.getChallenge();
  final persistProof = persistChallenge.buildProof();

  print('Publish the following TXT record:');
  print(
    '${persistProof.txtRecordName} IN TXT "${persistProof.txtRecordValue}"',
  );
  print('Press Enter once the DNS record is visible to the CA');
  stdin.readLineSync(encoding: utf8);

  final selfTestPassed = await persistChallenge.selfTest();
  if (!selfTestPassed) {
    print('Self-test failed, persistent DNS TXT record is not visible.');
    exit(1);
  }

  /// Request the CA to validate the DNS record.
  final authValid = await persistChallenge.validate();
  if (!authValid) {
    print('Authorization failed');
    exit(1);
  }

  final ready = await order.isReady();
  if (!ready) {
    print('Order is not ready');
    exit(1);
  }

  await order.finalize(certificateCredentials);
  final certificates = await order.getCertificates();
  print(jsonEncode(certificates));
}
