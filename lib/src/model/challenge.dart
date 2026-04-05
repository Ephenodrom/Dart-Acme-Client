import '../acme_client_exception.dart';
import '../acme_connection.dart';
import 'account.dart';
import 'challenge_type.dart';
import 'identifiers.dart';
import 'key_authorization.dart';

abstract class Challenge {
  Challenge({this.url, this.status, this.token, this.authorizationUrl});

  final String? url;
  final String? status;
  final String? token;

  String? authorizationUrl;
  AcmeConnection? _connection;
  Account? _account;
  Identifier? _identifier;

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

  /// @Throwing(AcmeValidationException)
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

  /// @Throwing(AcmeValidationException)
  KeyAuthorization buildKeyAuthorization(String accountKeyDigest) =>
      KeyAuthorization(
        token: requireToken(),
        accountKeyDigest: accountKeyDigest,
      );

  /// @Throwing(StateError)
  Future<bool> validate({int maxAttempts = 15}) => acmeConnectionValidate(
    requireConnection(),
    this,
    maxAttempts: maxAttempts,
  );

  Challenge _attachExecutionContext({
    required AcmeConnection connection,
    required Account account,
    required Identifier identifier,
  }) {
    _connection = connection;
    _account = account;
    _identifier = identifier;
    return this;
  }

  /// @Throwing(StateError)
  AcmeConnection requireConnection() =>
      _connection ??
      (throw StateError('Challenge is not attached to an ACME connection'));

  /// @Throwing(StateError)
  Account requireAccount() =>
      _account ??
      (throw StateError('Challenge is not attached to an ACME account'));

  /// @Throwing(StateError)
  Identifier requireIdentifier() =>
      _identifier ??
      (throw StateError('Challenge is not attached to an identifier'));
}

abstract class AuthorizationLike {
  List<Challenge>? get challenges;
}

Challenge acmeChallengeAttachExecutionContext(
  Challenge challenge, {
  required AcmeConnection connection,
  required Account account,
  required Identifier identifier,
}) => challenge._attachExecutionContext(
  connection: connection,
  account: account,
  identifier: identifier,
);
// The fluent attachment helper intentionally returns the same instance.
// ignore_for_file: avoid_returning_this
