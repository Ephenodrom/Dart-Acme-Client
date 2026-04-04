import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  final persistedCredentialsPath = 'acme-account-credentials.json';
  final connection = AcmeConnection.letsEncryptStaging();
  final newCredentials = AcmeAccountCredentials.generate(
    acceptTerms: true,
    contacts: ['mailto:jon@doe.com'],
  );

  // First run: generate fresh account credentials, create an ACME account,
  // and persist the credentials so the same account can be restored later.
  final createdAccount = await Account.create(
    newCredentials,
    connection: connection,
  );
  await File(
    persistedCredentialsPath,
  ).writeAsString(newCredentials.toJson());
  print('Persisted account credentials to $persistedCredentialsPath');
  print('Created account: ${createdAccount.accountURL}');
  print('Use fetch_account_example.dart to restore and fetch this account later.');
}
