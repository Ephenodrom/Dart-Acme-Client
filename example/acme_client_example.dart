// Example code intentionally writes progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  const persistedCredentialsPath = 'acme-account-credentials.json';
  const connection = AcmeConnection.staging;
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
  await File(persistedCredentialsPath).writeAsString(newCredentials.toJson());
  print('Persisted account credentials to $persistedCredentialsPath');
  print('Created account: ${createdAccount.accountURL}');
  print(
    'Use fetch_account_example.dart for a load-or-create credential flow '
    'that stores the key outside the repository.',
  );
}
