// Example code intentionally prints and uses async file I/O for clarity.
// ignore_for_file: avoid_print, avoid_slow_async_io

import 'dart:io';

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  const domainIdentifier = DomainIdentifier('example.com');
  final credentialsPath = _resolveCredentialsPath(domainIdentifier);

  final credentials = await _loadOrCreateCertificateCredentials(
    credentialsPath,
    identifiers: [domainIdentifier],
  );

  print('Using certificate credentials from ${credentialsPath.path}');
  print(
    'CSR covers: ${credentials.identifiers.map((id) => id.value).join(', ')}',
  );
}

Future<CertificateCredentials> _loadOrCreateCertificateCredentials(
  File credentialsPath, {
  required List<DomainIdentifier> identifiers,
}) async {
  if (await credentialsPath.exists()) {
    return CertificateCredentials.fromJson(
      await credentialsPath.readAsString(),
    );
  }

  await credentialsPath.parent.create(recursive: true);
  final credentials = CertificateCredentials.generate(identifiers: identifiers);
  await credentialsPath.writeAsString(credentials.toJson());

  print(
    'Generated new certificate credentials and stored them at '
    '${credentialsPath.path}.',
  );
  print(
    'Persist this file if you want to renew with the same certificate private '
    'key. Generate a new one if you want key rotation on renewal.',
  );

  return credentials;
}

File _resolveCredentialsPath(DomainIdentifier identifier) {
  final override = Platform.environment['ACME_CERTIFICATE_CREDENTIALS_PATH'];
  if (override != null && override.isNotEmpty) {
    return File(override);
  }

  final home = Platform.environment['HOME'];
  final fileName = 'certificate-${identifier.value}.json';
  if (home == null || home.isEmpty) {
    return File(fileName);
  }

  return File('$home/.config/acme_client/$fileName');
}
