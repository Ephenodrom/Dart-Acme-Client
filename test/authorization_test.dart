// Tests keep long key and proof material unwrapped for readability.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:typed_data';

import 'package:acme_client/acme_client.dart';
import 'package:acme_client/src/account_key_digest.dart';
import 'package:acme_client/src/acme_connection.dart';
import 'package:acme_client/src/model/authorization.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/dns_persist_policy.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:test/test.dart';

/// @Throwing(ArgumentError, reason: 'test setup may construct incomplete authorization data for the model helpers')
void main() {
  test('Test DnsChallenge.buildChallengeProof()', () {
    final credentials = AcmeAccountCredentials.generate(
      acceptTerms: true,
      contacts: const ['mailto:test@example.com'],
    );

    final auth = Authorization(
      identifier: const DomainIdentifier('foobar.de'),
      challengeType: ChallengeType.dns,
      challenges: [
        DnsChallenge(token: 'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE'),
      ],
    );

    final challenge = auth.getChallenge() as DnsChallenge;
    acmeChallengeAttachExecutionContext(
      challenge,
      connection: acmeConnectionBindCredentials(
        const AcmeConnection(baseUrl: 'https://example.com/acme/directory'),
        credentials,
      ),
      account: Account(accountURL: 'https://example.com/acme/acct/123'),
      identifier: auth.identifier!,
    );
    final challengeProof = challenge.buildProof();
    final keyAuthorization = challenge.buildKeyAuthorization(
      acmeAccountKeyDigestFromPublicKeyPem(credentials.publicKeyPem),
    );
    final expectedDnsValue = base64Url
        .encode(
          CryptoUtils.getHashPlain(
            Uint8List.fromList(keyAuthorization.value.codeUnits),
          ),
        )
        .replaceAll('=', '');

    final bind = challengeProof.toBindString();

    expect(challengeProof.txtRecordValue, expectedDnsValue);
    expect(challengeProof.txtRecordName, '_acme-challenge.foobar.de');
    expect(
      keyAuthorization.token,
      'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE',
    );
    expect(keyAuthorization.accountKeyDigest, isNotEmpty);
    expect(bind, contains('_acme-challenge.foobar.de'));
  });

  test('Test HttpChallenge.buildChallengeProof()', () {
    final credentials = AcmeAccountCredentials.generate(
      acceptTerms: true,
      contacts: const ['mailto:test@example.com'],
    );

    final auth = Authorization(
      identifier: const DomainIdentifier('foobar.de'),
      challengeType: ChallengeType.http,
      challenges: [
        HttpChallenge(token: 'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE'),
      ],
    );

    final challenge = auth.getChallenge() as HttpChallenge;
    acmeChallengeAttachExecutionContext(
      challenge,
      connection: acmeConnectionBindCredentials(
        const AcmeConnection(baseUrl: 'https://example.com/acme/directory'),
        credentials,
      ),
      account: Account(accountURL: 'https://example.com/acme/acct/123'),
      identifier: auth.identifier!,
    );
    final httpChallengeProof = challenge.buildProof();
    final keyAuthorization = challenge.buildKeyAuthorization(
      acmeAccountKeyDigestFromPublicKeyPem(credentials.publicKeyPem),
    );

    expect(
      httpChallengeProof.wellKnownChallengeFileContent,
      keyAuthorization.value,
    );
    expect(
      httpChallengeProof.pathToWellKnownChallenge,
      '/.well-known/acme-challenge/ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE',
    );
  });

  test('Test DnsPersistChallenge.buildDnsPersistChallengeProof()', () {
    final auth = Authorization(
      identifier: const DomainIdentifier('example.com'),
      challengeType: ChallengeType.dnsPersist,
      challenges: [
        DnsPersistChallenge(
          url: 'https://example.com/acme/challenge/1',
          authorizationUrl: 'https://example.com/acme/authz/1',
          issuerDomainNames: ['ca.example', 'backup-ca.example'],
        ),
      ],
    );

    final challenge = auth.getChallenge() as DnsPersistChallenge;
    acmeChallengeAttachExecutionContext(
      challenge,
      connection: acmeConnectionBindCredentials(
        const AcmeConnection(baseUrl: 'https://example.com/acme/directory'),
        const AcmeAccountCredentials(
          privateKeyPem: 'private',
          publicKeyPem: 'public',
          acceptTerms: true,
          contacts: ['mailto:test@example.com'],
        ),
      ),
      account: Account(accountURL: 'https://ca.example/acme/acct/123'),
      identifier: auth.identifier!,
    );

    final challengeProof = challenge.buildProof();

    expect(challengeProof.txtRecordName, '_validation-persist.example.com');
    expect(
      challengeProof.txtRecordValue,
      'ca.example; accounturi=https://ca.example/acme/acct/123',
    );
    expect(
      challengeProof.toBindString(),
      contains('_validation-persist.example.com'),
    );
    expect(challengeProof.issuerDomainName, 'ca.example');
    expect(challengeProof.accountUri, 'https://ca.example/acme/acct/123');
    expect(challengeProof.policy, DnsPersistPolicy.fqdn);
  });
}
