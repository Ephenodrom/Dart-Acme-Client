import 'dart:convert';

import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/acme_connection.dart';
import 'package:acme_client/src/acme_logger.dart';
import 'package:acme_client/src/model/account.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/order.dart';
import 'package:acme_client/src/model/identifiers.dart';
import 'package:acme_client/src/wire/authorization_resource.dart';
import 'package:dio/dio.dart';
class Authorization implements AuthorizationLike {
  String? status;
  DateTime? expires;
  Identifier? identifier;
  @override
  List<Challenge>? challenges;

  Authorization({
    this.challenges,
    this.expires,
    this.identifier,
    this.status,
  });

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
        final response = await acmeConnectionResolvedDio(connection).post(
          authUrl,
          data: body,
          options: Options(headers: headers),
        );
        acmeConnectionJwsManager(connection).updateNonce(response);
        authorizations.add(
          acmeAuthorizationFromResponse(
            response,
            authorizationUrl: authUrl,
          ),
        );
      } on DioException catch (e, s) {
        acmeConnectionJwsManager(connection).captureErrorNonce(e);
        throw AcmeClientException.wrapDioException(
          e,
          'Failed to fetch ACME authorization',
          AcmeAuthorizationException.fromDioException,
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
Future<List<Authorization>> acmeAuthorizationFetchAll(
  AcmeConnection connection,
  Account account,
  Order order,
) => Authorization._fetchAll(connection, account, order);
