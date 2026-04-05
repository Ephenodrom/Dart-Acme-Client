// Example code intentionally prints the manual steps for the operator.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  final accountCredentials = AcmeAccountCredentials.fromJson(
    await File('account-credentials.json').readAsString(),
  );

  final account = await Account.fetch(
    accountCredentials,
    connection: AcmeConnection.staging,
  );

  const domainIdentifier = DomainIdentifier('example.com');

  // Reuse stored certificate credentials to renew with the same private key.
  // Generate fresh credentials here instead if you want key rotation.
  final certificateCredentials = CertificateCredentials.fromJson(
    await File('certificate-credentials.json').readAsString(),
  );

  final order = await account.createOrderForDnsPersist(
    identifiers: [domainIdentifier],
  );
  final authorization = await order.getAuthorization(domainIdentifier);
  final challenge = authorization.getChallenge();
  final proof = challenge.buildProof();

  print('Publish the following TXT record:');
  print('${proof.txtRecordName} IN TXT "${proof.txtRecordValue}"');
  print('Press Enter once the DNS record is visible to the CA.');
  stdin.readLineSync(encoding: utf8);

  if (!await challenge.selfTest()) {
    throw StateError('dns-persist renewal self-test failed');
  }
  if (!await challenge.validate()) {
    throw StateError('dns-persist renewal validation failed');
  }
  if (!await order.isReady()) {
    throw StateError('Renewal order is not ready');
  }

  await order.finalize(certificateCredentials);
  final certificates = await order.getCertificates();
  print(jsonEncode(certificates));
}
