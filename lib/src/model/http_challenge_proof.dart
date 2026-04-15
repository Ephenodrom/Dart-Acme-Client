import 'package:meta/meta.dart';

import 'http_challenge.dart';
import 'key_authorization.dart';

/// The HTTP resource a caller must serve to satisfy an `http-01` challenge.
///
/// This is not the CA challenge object. It is the derived proof artifact built
/// from an [HttpChallenge] plus the local identifier and account key material.
class HttpChallengeProof {
  /// The path to the well-known challenge file, relative to the domain's wwwroot.
  /// During a HTTP Challenge the CA will request this path from the domain's
  /// wwwroot to verify the challenge.
  /// You must write the [wellKnownChallengeFileContent] to this path on your server.
  final String pathToWellKnownChallenge;
  final String wellKnownChallengeFileContent;
  final HttpChallenge challenge;

  HttpChallengeProof._({
    required this.pathToWellKnownChallenge,
    required this.wellKnownChallengeFileContent,
    required this.challenge,
  });

  @internal
  factory HttpChallengeProof.forAuthorization({
    required KeyAuthorization keyAuthorization,
    required HttpChallenge challenge,
  }) => HttpChallengeProof._(
      pathToWellKnownChallenge:
          '/.well-known/acme-challenge/${keyAuthorization.token}',
      wellKnownChallengeFileContent: keyAuthorization.value,
      challenge: challenge,
    );
}
// Proof docs intentionally keep the protocol path examples unwrapped.
// ignore_for_file: lines_longer_than_80_chars
