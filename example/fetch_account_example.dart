// Example code intentionally prints and uses async file I/O for clarity.
// ignore_for_file: avoid_print, avoid_slow_async_io

import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  final credentialsPath = _resolveCredentialsPath();
  const connection = AcmeConnection.staging;

  final credentials = await _loadOrCreateCredentials(credentialsPath);
  final account = await Account.fetch(credentials, connection: connection);

  print('Using ACME account credentials from ${credentialsPath.path}');
  print('Fetched existing account: ${account.accountURL}');
}

Future<AcmeAccountCredentials> _loadOrCreateCredentials(
  File credentialsPath,
) async {
  if (await credentialsPath.exists()) {
    return AcmeAccountCredentials.fromJson(
      await credentialsPath.readAsString(),
    );
  }

  await credentialsPath.parent.create(recursive: true);
  final credentials = AcmeAccountCredentials.generate(
    acceptTerms: true,
    contacts: ['mailto:admin@example.com'],
  );
  await credentialsPath.writeAsString(credentials.toJson());

  print(
    'Generated new ACME account credentials and stored them at '
    '${credentialsPath.path}.',
  );
  print(
    'Keep this file outside your repository and restrict access to the '
    'current user.',
  );

  return credentials;
}

File _resolveCredentialsPath() {
  final override = Platform.environment['ACME_ACCOUNT_CREDENTIALS_PATH'];
  if (override != null && override.isNotEmpty) {
    return File(override);
  }

  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return File('acme-account-credentials.json');
  }

  return File('$home/.config/acme_client/account-credentials.json');
}
