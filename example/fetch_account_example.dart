import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  final persistedCredentialsPath = 'acme-account-credentials.json';
  final connection = AcmeConnection.letsEncryptStaging();

  final restoredCredentials = AcmeAccountCredentials.fromJson(
    await File(persistedCredentialsPath).readAsString(),
  );
  final restoredAccount = await Account.fetch(
    restoredCredentials,
    connection: connection,
  );

  print('Fetched existing account: ${restoredAccount.accountURL}');
}
