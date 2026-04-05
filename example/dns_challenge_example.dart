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
  final order = await account.createOrderForDns(
    identifiers: [domainIdentifier],
  );

  final authorization = await order.getAuthorization(domainIdentifier);
  final challenge = authorization.getChallenge();
  final proof = challenge.buildProof();

  print('Publish the following TXT record:');
  print('${proof.txtRecordName} IN TXT "${proof.txtRecordValue}"');
  print('Press Enter once the DNS record is publicly visible.');
  stdin.readLineSync(encoding: utf8);

  final selfTestPassed = await challenge.selfTest();
  if (!selfTestPassed) {
    print('Self-test failed, DNS TXT record is not publicly visible.');
    exit(1);
  }

  final authValid = await challenge.validate();
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
