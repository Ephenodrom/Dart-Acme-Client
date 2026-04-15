import 'package:meta/meta.dart';

import '../acme_connection.dart';
import 'challenge.dart';
import 'challenge_order.dart' show ChallengeAuthorization;
import 'challenge_type.dart';
import 'http_challenge_proof.dart';

/// An `http-01` challenge returned by the CA for one identifier.
///
/// In the normal flow you obtain this from a [ChallengeAuthorization], call
/// [buildProof] to learn what file content to serve, optionally call
/// [selfTest], and then call [validate].
class HttpChallenge extends Challenge {
  @internal
  HttpChallenge({super.url, super.status, super.token, super.authorizationUrl});

  @override
  ChallengeType get challengeType => ChallengeType.http;

  /// Builds the HTTP proof resource the caller must serve for this `http-01`
  /// challenge using the execution context attached to the challenge.
  ///
  /// The returned proof tells you which path must be served and which content
  /// must be returned from that path before validation begins.
  HttpChallengeProof buildProof() => HttpChallengeProof.forAuthorization(
    keyAuthorization: buildKeyAuthorization(
      acmeConnectionAccountKeyDigest(requireConnection()),
    ),
    challenge: this,
  );

  /// Checks whether the derived `http-01` resource is publicly reachable.
  ///
  /// This is a best-effort operational probe and is not part of the ACME
  /// protocol itself. The current implementation reuses the challenge's bound
  /// [AcmeConnection] only for logger output and shared HTTP client
  /// configuration; it does not contact the CA.
  Future<bool> selfTest({int maxAttempts = 15}) => acmeConnectionSelfHttpTest(
    requireConnection(),
    buildProof(),
    maxAttempts: maxAttempts,
  );
}
