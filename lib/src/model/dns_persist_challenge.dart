import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/challenge_type.dart';
import 'package:acme_client/src/model/dns_persist_challenge_data.dart';
import 'package:acme_client/src/model/dns_persist_policy.dart';
import 'package:acme_client/src/model/identifiers.dart';
import 'package:acme_client/src/payloads/empty_validation_payload.dart';
import 'package:acme_client/src/payloads/validation_payload.dart';

class DnsPersistChallenge extends Challenge {
  DnsPersistChallenge({
    super.url,
    super.status,
    super.token,
    super.issuerDomainNames,
    super.authorizationUrl,
  });

  @override
  ChallengeType get challengeType => ChallengeType.dnsPersist;

  @override
  ValidationPayload createValidationPayload({
    required String Function() accountKeyDigestProvider,
  }) {
    final issuers = issuerDomainNames;
    if (issuers == null || issuers.isEmpty) {
      throw AcmeDnsPersistException(
        'ACME dns-persist-01 challenge is missing issuer-domain-names',
        uri: Uri.tryParse(url ?? authorizationUrl ?? ''),
      );
    }
    return const EmptyValidationPayload();
  }

  DnsPersistChallengeData buildDnsPersistChallengeData({
    required DomainIdentifier domainIdentifier,
    required String accountUri,
    String? issuerDomainName,
    DnsPersistPolicy policy = DnsPersistPolicy.wildcard,
    DateTime? persistUntil,
  }) {
    final issuers = issuerDomainNames;
    if (issuers == null || issuers.isEmpty) {
      throw AcmeDnsPersistException(
        'ACME dns-persist-01 challenge is missing issuer-domain-names',
        uri: Uri.tryParse(url ?? authorizationUrl ?? ''),
      );
    }

    final selectedIssuer = issuerDomainName ?? issuers.first;
    if (!issuers.contains(selectedIssuer)) {
      throw AcmeDnsPersistException(
        'Requested issuer-domain-name is not offered by the ACME challenge',
        uri: Uri.tryParse(url ?? authorizationUrl ?? ''),
        detail: selectedIssuer,
        rawBody: issuers,
      );
    }

    return DnsPersistChallengeData.forAuthorization(
      domainIdentifier: domainIdentifier,
      challenge: this,
      issuerDomainName: selectedIssuer,
      accountUri: accountUri,
      policy: policy,
      persistUntil: persistUntil,
    );
  }
}
