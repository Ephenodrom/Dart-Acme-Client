import 'dart:convert';

import 'package:dio/dio.dart';

import '../acme_client_exception.dart';
import '../acme_connection.dart';
import '../acme_exception_factory.dart';
import '../acme_logger.dart';
import '../wire/authorization_resource.dart';
import '../wire/identifier_resource.dart';
import 'account.dart';
import 'challenge.dart';
import 'challenge_type.dart';
import 'identifiers.dart';
import 'order.dart';

class Authorization implements AuthorizationLike {
  String? status;
  DateTime? expires;
  Identifier? identifier;
  ChallengeType? challengeType;
  @override
  List<Challenge>? challenges;

  Authorization({
    this.challenges,
    this.expires,
    this.identifier,
    this.status,
    this.challengeType,
  });

  bool hasChallenge({ChallengeType? challengeType}) {
    final selectedChallengeType = challengeType ?? this.challengeType;
    if (selectedChallengeType == null) {
      return false;
    }
    return challenges?.any(
          (challenge) => challenge.challengeType == selectedChallengeType,
        ) ??
        false;
  }

  /// @Throwing(AcmeAuthorizationException)
  /// @Throwing(AcmeConfigurationException)
  Challenge getChallenge({ChallengeType? challengeType}) {
    final selectedChallengeType =
        challengeType ??
        this.challengeType ??
        (throw const AcmeConfigurationException(
          'challengeType must be configured on the order or passed explicitly',
        ));
    final availableChallenges = challenges;
    if (availableChallenges == null || availableChallenges.isEmpty) {
      throw AcmeAuthorizationException(
        'No ACME challenges are available for this authorization',
        detail: selectedChallengeType.wireValue,
        rawBody: {
          'status': status,
          'identifier': identifier == null
              ? null
              : acmeIdentifierToRequestMap(identifier!),
        },
      );
    }

    final challenge = availableChallenges
        .where(
          (availableChallenge) =>
              availableChallenge.challengeType == selectedChallengeType,
        )
        .cast<Challenge?>()
        .firstWhere((candidate) => candidate != null, orElse: () => null);

    if (challenge == null) {
      throw AcmeAuthorizationException(
        'The ACME server does not offer the requested challenge type for this authorization',
        detail:
            '${identifier?.value ?? '<unknown>'} (${selectedChallengeType.wireValue})',
        rawBody: {
          'status': status,
          'identifier': identifier == null
              ? null
              : acmeIdentifierToRequestMap(identifier!),
          'challenges': availableChallenges
              .map((availableChallenge) => availableChallenge.type)
              .toList(),
        },
      );
    }

    return challenge;
  }

  /// @Throwing(AcmeClientException)
  static Future<List<Authorization>> _fetchAll(
    AcmeConnection connection,
    Account account,
    Order order,
  ) async {
    final authorizations = <Authorization>[];
    for (final authUrl in order.authorizations!) {
      final jws = await acmeConnectionJwsManager(connection).createJws(
        authUrl,
        newNonceUrl: acmeConnectionDirectories(connection)!.newNonce,
        accountUrl: account.accountURL,
        useKid: true,
      );
      final body = json.encode(jws.toJson());
      const headers = {'Content-Type': 'application/jose+json'};
      try {
        final response = await acmeConnectionResolvedDio(connection)
            .post<Object?>(
              authUrl,
              data: body,
              options: Options(headers: headers),
            );
        acmeConnectionJwsManager(connection).updateNonce(response);
        authorizations.add(
          acmeAuthorizationFromResponse(response, authorizationUrl: authUrl),
        );
      } on DioException catch (e, s) {
        acmeConnectionJwsManager(connection).captureErrorNonce(e);
        throw acmeWrapDioException(
          e,
          'Failed to fetch ACME authorization',
          acmeAuthorizationExceptionFromDioException,
          onWrapped: (wrapped) => connection.logger?.call(
            AcmeLogLevel.error,
            wrapped.message,
            error: e,
            stackTrace: s,
          ),
        );
      }
    }
    return authorizations;
  }

  /// @Throwing(AcmeAccountKeyDigestException, reason: 'the account key thumbprint could not be generated for authorization processing')
  /// @Throwing(AcmeAuthorizationException, reason: 'the ACME server rejected or failed to return authorization data')
  /// @Throwing(AcmeJwsException, reason: 'authorization lookup requests could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated while fetching authorizations')
}

/// Fetches all authorizations for an order and enriches them with local context.
///
/// Why this exists: `Order.getAuthorizations` is the public fluent API, so the
/// protocol-level authorization fetcher should not be documented as a class
/// method on `Authorization`.
/// @Throwing(AcmeClientException)
Future<List<Authorization>> acmeAuthorizationFetchAll(
  AcmeConnection connection,
  Account account,
  Order order,
) => Authorization._fetchAll(connection, account, order);
// Public API docs intentionally keep some long protocol explanations unwrapped.
// ignore_for_file: lines_longer_than_80_chars
