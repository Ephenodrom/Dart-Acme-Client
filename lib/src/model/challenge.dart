import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/model/challenge_type.dart';
import 'package:acme_client/src/payloads/validation_payload.dart';

abstract class Challenge {
  Challenge({
    this.url,
    this.status,
    this.token,
    this.issuerDomainNames,
    this.authorizationUrl,
  });

  final String? url;
  final String? status;
  final String? token;
  final List<String>? issuerDomainNames;
  String? authorizationUrl;

  ChallengeType get challengeType;

  String get type => challengeType.wireValue;
  static bool has<T extends Challenge>(Iterable<Challenge>? challenges) =>
      challenges?.any((challenge) => challenge is T) ?? false;

  static T get<T extends Challenge>(Iterable<Challenge> challenges) =>
      challenges.whereType<T>().first;

  Challenge? refreshedFrom(AuthorizationLike authorization) {
    final challenges = authorization.challenges;
    if (challenges == null) {
      return null;
    }
    for (final candidate in challenges) {
      if (url != null && candidate.url == url) {
        return candidate;
      }
    }
    for (final candidate in challenges) {
      if (candidate.challengeType == challengeType) {
        return candidate;
      }
    }
    return null;
  }

  ValidationPayload createValidationPayload({
    required String Function() accountKeyDigestProvider,
  });

  String requireToken() {
    final challengeToken = token;
    if (challengeToken == null || challengeToken.isEmpty) {
      throw AcmeValidationException(
        'ACME challenge is missing a token',
        uri: Uri.tryParse(url ?? authorizationUrl ?? ''),
      );
    }
    return challengeToken;
  }

  String buildKeyAuthorization(String accountKeyDigest) =>
      '${requireToken()}.$accountKeyDigest';
}

abstract class AuthorizationLike {
  List<Challenge>? get challenges;
}
