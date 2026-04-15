import 'package:meta/meta.dart';

import '../../acme_client.dart' show ChallengeAuthorization;
import '../acme_client_exception.dart';
import '../acme_connection.dart';
import 'challenge.dart';
import 'challenge_order.dart' show ChallengeAuthorization;
import 'challenge_type.dart';
import 'dns_persist_challenge_proof.dart';
import 'identifiers.dart';

/// A `dns-persist-01` challenge returned by the CA for one identifier.
///
/// This challenge is used for persistent delegated DNS validation. In the
/// normal flow you obtain it from a [ChallengeAuthorization], call [buildProof]
/// to get the TXT record to publish, optionally call [selfTest], and then call
/// [validate].
class DnsPersistChallenge extends Challenge {
  @internal
  DnsPersistChallenge({
    super.url,
    super.status,
    super.token,
    this.issuerDomainNames = const [],
    super.authorizationUrl,
  });

  final List<String> issuerDomainNames;

  @override
  ChallengeType get challengeType => ChallengeType.dnsPersist;

  /// Builds the persistent DNS proof record the caller must publish for this
  /// `dns-persist-01` challenge using the execution context attached to the
  /// challenge.
  ///
  /// The first issuer-domain-name offered by the CA is selected automatically
  /// and the default persistence policy is FQDN-only.
  ///
  /// The returned proof tells you exactly what persistent TXT record to
  /// publish before validation begins.
  /// @Throwing(AcmeDnsPersistException)
  DnsPersistChallengeProof buildProof() {
    final domainIdentifier = requireIdentifier() as DomainIdentifier;
    final accountUri = requireAccount().accountURL!;
    if (issuerDomainNames.isEmpty) {
      throw AcmeDnsPersistException(
        'ACME dns-persist-01 challenge is missing issuer-domain-names',
        uri: Uri.tryParse(url ?? authorizationUrl ?? ''),
      );
    }

    return DnsPersistChallengeProof.forAuthorization(
      domainIdentifier: domainIdentifier,
      challenge: this,
      issuerDomainName: issuerDomainNames.first,
      accountUri: accountUri,
    );
  }

  /// Checks whether the derived `dns-persist-01` TXT record is publicly
  /// visible.
  ///
  /// This is a best-effort operational probe and is not part of the ACME
  /// protocol itself. The current implementation reuses the challenge's bound
  /// [AcmeConnection] only for logger output and shared client configuration;
  /// it does not contact the CA. DNS visibility is checked via Google Public
  /// DNS.
  /// @Throwing(AcmeDnsPersistException)
  Future<bool> selfTest({int maxAttempts = 15}) =>
      acmeConnectionSelfDnsPersistTest(
        requireConnection(),
        buildProof(),
        maxAttempts: maxAttempts,
      );
}
