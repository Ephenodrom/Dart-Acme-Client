import 'dart:convert';
import 'dart:typed_data';

import 'package:acme_client/acme_client.dart';
import 'package:acme_client/src/account_key_digest.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:test/test.dart';

/// @Throwing(ArgumentError, reason: 'test setup may construct incomplete authorization data for the model helpers')
void main() {
  test('Test DnsChallenge.buildChallengeData()', () {
    final credentials = AcmeAccountCredentials.generate(
      acceptTerms: true,
      contacts: const ['mailto:test@example.com'],
    );

    var auth = Authorization(
      identifier: const DomainIdentifier('foobar.de'),
      challenges: [
        DnsChallenge(token: 'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE'),
      ],
    );

    final challenge = Challenge.get<DnsChallenge>(auth.challenges!);
    final challengeData = challenge.buildChallengeData(
      domainIdentifier: auth.identifier! as DomainIdentifier,
      publicKeyPem: credentials.publicKeyPem,
    );
    final keyAuthorization = challenge.buildKeyAuthorization(
      acmeAccountKeyDigestFromPublicKeyPem(credentials.publicKeyPem),
    );
    final expectedDnsValue = base64Url
        .encode(CryptoUtils.getHashPlain(Uint8List.fromList(keyAuthorization.codeUnits)))
        .replaceAll('=', '');

    var bind = challengeData.toBindString();

    expect(challengeData.txtRecordValue, expectedDnsValue);
    expect(challengeData.txtRecordName, '_acme-challenge.foobar.de');
    expect(bind, contains('_acme-challenge.foobar.de'));
  });

  test('Test HttpChallenge.buildChallengeData()', () {
    final credentials = AcmeAccountCredentials.generate(
      acceptTerms: true,
      contacts: const ['mailto:test@example.com'],
    );

    var auth = Authorization(
      identifier: const DomainIdentifier('foobar.de'),
      challenges: [
        HttpChallenge(token: 'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE'),
      ],
    );

    final challenge = Challenge.get<HttpChallenge>(auth.challenges!);
    var httpChallengeData = challenge.buildChallengeData(
      domainIdentifier: auth.identifier! as DomainIdentifier,
      publicKeyPem: credentials.publicKeyPem,
    );
    final keyAuthorization = challenge.buildKeyAuthorization(
      acmeAccountKeyDigestFromPublicKeyPem(credentials.publicKeyPem),
    );

    expect(
      httpChallengeData.fileContent,
      keyAuthorization,
    );
    expect(
      httpChallengeData.fileName,
      'foobar.de/.well-known/acme-challenge/ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE',
    );
  });

  test('Test DnsPersistChallenge.buildDnsPersistChallengeData()', () {
    final auth = Authorization(
      identifier: const DomainIdentifier('example.com'),
      challenges: [
        DnsPersistChallenge(
          url: 'https://example.com/acme/challenge/1',
          authorizationUrl: 'https://example.com/acme/authz/1',
          issuerDomainNames: ['ca.example', 'backup-ca.example'],
        ),
      ],
    );

    final order = Order(identifiers: [const DomainIdentifier('example.com')]);
    final challenge = order.getChallengeForIdentifier<DnsPersistChallenge>(
      auth.identifier!,
      [auth],
    );

    final challengeData = challenge.buildDnsPersistChallengeData(
      domainIdentifier: auth.identifier! as DomainIdentifier,
      accountUri: 'https://ca.example/acme/acct/123',
      issuerDomainName: 'ca.example',
      persistUntil: DateTime.utc(2026, 1, 1),
    );

    expect(challengeData.txtRecordName, '_validation-persist.example.com');
    expect(
      challengeData.txtRecordValue,
      'ca.example; accounturi=https://ca.example/acme/acct/123; '
      'policy=wildcard; persistUntil=1767225600',
    );
    expect(
      challengeData.toBindString(),
      contains('_validation-persist.example.com'),
    );
    expect(challengeData.issuerDomainName, 'ca.example');
    expect(challengeData.accountUri, 'https://ca.example/acme/acct/123');
  });
}
