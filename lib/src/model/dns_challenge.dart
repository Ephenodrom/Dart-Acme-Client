import 'package:acme_client/src/account_key_digest.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/challenge_type.dart';
import 'package:acme_client/src/model/dns_dcv_data.dart';
import 'package:acme_client/src/model/identifiers.dart';
import 'package:acme_client/src/payloads/key_authorization_validation_payload.dart';
import 'package:acme_client/src/payloads/validation_payload.dart';

class DnsChallenge extends Challenge {
  DnsChallenge({
    super.url,
    super.status,
    super.token,
    super.authorizationUrl,
  });

  @override
  ChallengeType get challengeType => ChallengeType.dns;

  @override
  ValidationPayload createValidationPayload({
    required String Function() accountKeyDigestProvider,
  }) {
    return KeyAuthorizationValidationPayload(
      buildKeyAuthorization(accountKeyDigestProvider()),
    );
  }

  DnsChallengeData buildChallengeData({
    required DomainIdentifier domainIdentifier,
    required String publicKeyPem,
  }) {
    return DnsChallengeData.forAuthorization(
      domainIdentifier: domainIdentifier,
      keyAuthorization: buildKeyAuthorization(
        AccountKeyDigest.fromPublicKeyPem(publicKeyPem).value,
      ),
      challenge: this,
    );
  }
}
