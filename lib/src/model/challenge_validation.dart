import '../acme_client_exception.dart';
import '../payloads/empty_validation_payload.dart';
import '../payloads/key_authorization_validation_payload.dart';
import '../payloads/validation_payload.dart';
import 'challenge.dart';
import 'dns_challenge.dart';
import 'dns_persist_challenge.dart';
import 'http_challenge.dart';

ValidationPayload acmeChallengeCreateValidationPayload(
  Challenge challenge, {
  required String Function() accountKeyDigestProvider,
}) {
  if (challenge case DnsChallenge()) {
    return KeyAuthorizationValidationPayload(
      challenge.buildKeyAuthorization(accountKeyDigestProvider()),
    );
  }

  if (challenge case HttpChallenge()) {
    return KeyAuthorizationValidationPayload(
      challenge.buildKeyAuthorization(accountKeyDigestProvider()),
    );
  }

  if (challenge case DnsPersistChallenge()) {
    final issuers = challenge.issuerDomainNames;
    if (issuers.isEmpty) {
      throw AcmeDnsPersistException(
        'ACME dns-persist-01 challenge is missing issuer-domain-names',
        uri: Uri.tryParse(challenge.url ?? challenge.authorizationUrl ?? ''),
      );
    }
    return const EmptyValidationPayload();
  }

  throw UnsupportedError(
    'Unsupported ACME challenge type: ${challenge.runtimeType}',
  );
}
