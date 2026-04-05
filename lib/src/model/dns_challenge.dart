import 'package:meta/meta.dart';

import '../../acme_client.dart' show ChallengeAuthorization;
import '../acme_connection.dart';
import 'challenge.dart';
import 'challenge_order.dart' show ChallengeAuthorization;
import 'challenge_type.dart';
import 'dns_challenge_proof.dart';
import 'identifiers.dart';

/// A `dns-01` challenge returned by the CA for one identifier.
///
/// In the normal flow you do not construct this yourself. You obtain it from a
/// [ChallengeAuthorization], call [buildProof] to get the TXT record to
/// publish, optionally call [selfTest], and then call [validate].
class DnsChallenge extends Challenge {
  @internal
  DnsChallenge({super.url, super.status, super.token, super.authorizationUrl});

  @override
  ChallengeType get challengeType => ChallengeType.dns;

  /// Builds the DNS proof record the caller must publish for this `dns-01`
  /// challenge using the execution context attached to the challenge.
  ///
  /// The returned proof tells you exactly which TXT record name and value must
  /// be published before asking the CA to validate the challenge.
  DnsChallengeProof buildProof() {
    final domainIdentifier = requireIdentifier() as DomainIdentifier;
    return DnsChallengeProof.forAuthorization(
      domainIdentifier: domainIdentifier,
      keyAuthorization: buildKeyAuthorization(
        acmeConnectionAccountKeyDigest(requireConnection()),
      ),
      challenge: this,
    );
  }

  /// Checks whether the derived `dns-01` TXT record is publicly visible.
  ///
  /// This is a best-effort operational probe and is not part of the ACME
  /// protocol itself. The current implementation reuses the challenge's bound
  /// [AcmeConnection] only for logger output and shared client configuration;
  /// it does not contact the CA. DNS visibility is checked via Google Public
  /// DNS.
  Future<bool> selfTest({int maxAttempts = 15}) => acmeConnectionSelfDnsTest(
    requireConnection(),
    buildProof(),
    maxAttempts: maxAttempts,
  );
}
