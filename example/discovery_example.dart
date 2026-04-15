// Example code intentionally writes discovered values to stdout.
// ignore_for_file: avoid_print

import 'package:acme_client/acme_client.dart';

void main(List<String> args) async {
  const privateKeyPem =
      '''-----BEGIN RSA PRIVATE KEY----- ... -----END RSA PRIVATE KEY-----''';

  const publicKeyPem =
      '''-----BEGIN PUBLIC KEY----- ... -----END PUBLIC KEY-----''';

  const connection = AcmeConnection.staging;
  const credentials = AcmeAccountCredentials(
    privateKeyPem: privateKeyPem,
    publicKeyPem: publicKeyPem,
    acceptTerms: true,
    contacts: ['mailto:jon@doe.com'],
  );
  final account = await Account.fetch(credentials, connection: connection);

  /// Discover what challenged types the CA supports for the given domain.
  const domainIdentifier = DomainIdentifier('example.com');
  final availableChallenges = await account.discoverAvailableChallenges(
    identifier: domainIdentifier,
  );

  for (final challengeType in availableChallenges) {
    print(challengeType.name);
  }
}
