import 'dart:convert';

import 'package:basic_utils/basic_utils.dart';
import 'package:dio/dio.dart';

import '../acme_client_exception.dart';
import '../acme_connection.dart';
import '../acme_exception_factory.dart';
import '../acme_logger.dart';
import '../acme_util.dart';
import '../payloads/finalize_order_payload.dart';
import '../wire/identifier_resource.dart';
import '../wire/order_resource.dart';
import 'account.dart';
import 'authorization.dart';
import 'challenge.dart';
import 'challenge_type.dart';
import 'identifiers.dart';

class Order {
  String? status;
  DateTime? expires;
  DateTime? notAfter;
  DateTime? notBefore;
  List<String>? authorizations;
  String? finalizeUrl;
  String? certificate;
  List<Identifier>? identifiers;
  String? orderUrl;
  ChallengeType? challengeType;
  List<Authorization>? _cachedAuthorizations;
  AcmeConnection? _connection;
  Account? _account;

  Order({
    this.status,
    this.authorizations,
    this.certificate,
    this.expires,
    this.finalizeUrl,
    this.identifiers,
    this.notAfter,
    this.notBefore,
    this.orderUrl,
    this.challengeType,
  });

  Order _attachConnection(AcmeConnection connection, Account account) {
    _connection = connection;
    _account = account;
    return this;
  }

  Order _inheritChallengeTypeFrom(Order other) {
    challengeType = other.challengeType;
    return this;
  }

  Map<String, dynamic> _toCreationPayload() => {
    if (identifiers != null)
      'identifiers': acmeIdentifierListToRequestValue(identifiers),
    if (notBefore != null) 'notBefore': notBefore!.toUtc().toIso8601String(),
    if (notAfter != null) 'notAfter': notAfter!.toUtc().toIso8601String(),
  };

  /// @Throwing(AcmeJwsException, reason: 'order info request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated for order lookup')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected or failed to return the order')
  Future<Order> refresh() async => acmeOrderAttachConnection(
    await acmeOrderFetch(_requireConnection(), _requireAccount(), this),
    _requireConnection(),
    _requireAccount(),
  );

  Future<bool> isReady() async => (await refresh()).status == 'ready';

  /// @Throwing(AcmeAccountKeyDigestException, reason: 'the account key thumbprint could not be generated for authorization processing')
  /// @Throwing(AcmeAuthorizationException, reason: 'the ACME server rejected or failed to return authorization data')
  /// @Throwing(AcmeJwsException, reason: 'authorization lookup requests could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated while fetching authorizations')
  Future<List<Authorization>> getAuthorizations() =>
      _cachedAuthorizations != null
      ? Future.value(_cachedAuthorizations)
      : acmeAuthorizationFetchAll(
          _requireConnection(),
          _requireAccount(),
          this,
        ).then((authorizations) {
          _cachedAuthorizations = authorizations
              .map(
                (authorization) => authorization..challengeType = challengeType,
              )
              .toList();
          return _cachedAuthorizations!;
        });

  Future<Authorization> getAuthorizationForIdentifier(
    Identifier domainIdentifier,
  ) async {
    final selectedChallengeType =
        challengeType ??
        (throw const AcmeConfigurationException(
          'challengeType must be configured when creating the order',
        ));
    final authorizations = await getAuthorizations();

    for (final authorization in authorizationsForIdentifier(
      domainIdentifier,
      authorizations,
    )) {
      if (authorization.hasChallenge(challengeType: selectedChallengeType)) {
        return authorization;
      }
    }

    throw AcmeAuthorizationException(
      'No ACME authorization was found for the requested identifier and challenge type',
      detail: '${domainIdentifier.value} (${selectedChallengeType.wireValue})',
      rawBody: authorizations
          .map(
            (auth) => {
              'status': auth.status,
              'identifier': auth.identifier == null
                  ? null
                  : acmeIdentifierToRequestMap(auth.identifier!),
              'challenges': auth.challenges
                  ?.map((challenge) => challenge.type)
                  .toList(),
            },
          )
          .toList(),
    );
  }

  /// @Throwing(AcmeJwsException, reason: 'order finalization requests could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated during order finalization')
  /// @Throwing(AcmeOrderException, reason: 'the order could not be finalized or did not reach a valid state')
  Future<Order> finalize(String csr, {int retries = 5}) async {
    final connection = _requireConnection();
    final account = _requireAccount();
    final transformedCsr = AcmeUtils.formatCsrBase64Url(csr);
    var firstPass = true;
    _OrderResults results;

    while (true) {
      if (firstPass) {
        results = await _submitFinalization(
          connection,
          account,
          finalizeUrl!,
          transformedCsr,
        );
      } else {
        results = await _pollFinalizedOrder(connection);
      }
      firstPass = false;
      retries--;
      final responseData =
          results.response.data as Map<String, Object?>? ??
          const <String, Object?>{};
      if (responseData['status'] != 'processing' || retries <= 0) {
        break;
      }
    }

    final responseData =
        results.response.data as Map<String, Object?>? ??
        const <String, Object?>{};
    if (responseData['status'] != 'valid') {
      throw AcmeOrderException(
        'ACME order finalization did not complete successfully',
        uri: Uri.tryParse(orderUrl ?? finalizeUrl ?? ''),
        rawBody: responseData,
        detail: responseData['status']?.toString(),
      );
    }

    return acmeOrderAttachConnection(results.order, connection, account);
  }

  /// @Throwing(AcmeCertificateException, reason: 'the certificate chain could not be fetched from the ACME server')
  /// @Throwing(AcmeJwsException, reason: 'certificate download request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated while fetching the certificate chain')
  Future<List<String>> getCertificates() async {
    final connection = _requireConnection();
    final account = _requireAccount();
    final jws = await acmeConnectionJwsManager(connection).createJws(
      certificate!,
      newNonceUrl: acmeConnectionDirectories(connection)?.newNonce,
      accountUrl: account.accountURL,
      useKid: true,
    );
    final body = json.encode(jws.toJson());
    const headers = {'Content-Type': 'application/jose+json'};
    try {
      final response = await acmeConnectionResolvedDio(connection).post<String>(
        certificate!,
        data: body,
        options: Options(headers: headers),
      );
      final certs = <String>[];
      final data = response.data!;
      final buffer = StringBuffer();
      for (final line in LineSplitter.split(data)) {
        if (line.isEmpty) {
          continue;
        }
        buffer.write(line);
        if (line == X509Utils.END_CERT) {
          certs.add(buffer.toString());
          buffer.clear();
        }
      }
      acmeConnectionJwsManager(connection).updateNonce(response);
      return certs;
    } on DioException catch (e, s) {
      acmeConnectionJwsManager(connection).captureErrorNonce(e);
      throw acmeWrapDioException(
        e,
        'Failed to fetch ACME certificate chain',
        acmeCertificateExceptionFromDioException,
        onWrapped: (wrapped) => connection.logger?.call(
          AcmeLogLevel.error,
          wrapped.message,
          error: e,
          stackTrace: s,
        ),
      );
    }
  }

  AcmeConnection _requireConnection() =>
      _connection ??
      (throw StateError('Order is not attached to an ACME connection'));

  Account _requireAccount() =>
      _account ??
      (throw StateError('Order is not attached to an ACME account'));

  List<Authorization> authorizationsForIdentifier(
    Identifier identifier,
    Iterable<Authorization> authorizations,
  ) => authorizations
      .where(
        (authorization) =>
            authorization.identifier?.type == identifier.type &&
            authorization.identifier?.value == identifier.value,
      )
      .toList();

  List<Challenge> availableChallengesForIdentifier(
    Identifier identifier,
    Iterable<Authorization> authorizations,
  ) => authorizationsForIdentifier(identifier, authorizations)
      .expand(
        (authorization) => authorization.challenges ?? const <Challenge>[],
      )
      .toList();

  Future<List<Challenge>> discoverAvailableChallenges(
    Identifier identifier,
  ) async =>
      availableChallengesForIdentifier(identifier, await getAuthorizations());

  T getChallengeForIdentifier<T extends Challenge>(
    Identifier identifier,
    Iterable<Authorization> authorizations,
  ) {
    final challenges = availableChallengesForIdentifier(
      identifier,
      authorizations,
    );
    return Challenge.get<T>(challenges);
  }

  /// @Throwing(AcmeJwsException, reason: 'order creation request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated for order creation')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected or failed to create the order')
  /// @Throwing(AcmeJwsException, reason: 'finalized order submission could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated while submitting a finalized order')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected the finalized order submission')
  static Future<_OrderResults> _submitFinalization(
    AcmeConnection connection,
    Account account,
    String url,
    String transformedCsr,
  ) async {
    final jws = await acmeConnectionJwsManager(connection).createJws(
      url,
      newNonceUrl: acmeConnectionDirectories(connection)?.newNonce,
      accountUrl: account.accountURL,
      useKid: true,
      payload: FinalizeOrderPayload(transformedCsr),
    );
    final body = json.encode(jws.toJson());
    const headers = {'Content-Type': 'application/jose+json'};

    try {
      final response = await acmeConnectionResolvedDio(connection)
          .post<Object?>(
            url,
            data: body,
            options: Options(headers: headers),
          );
      final persistent = acmeOrderFromResponseMap(
        response.data! as Map<String, dynamic>,
      );
      acmeConnectionJwsManager(connection).updateNonce(response);

      return _OrderResults(response, persistent);
    } on DioException catch (e, s) {
      acmeConnectionJwsManager(connection).captureErrorNonce(e);
      throw acmeWrapDioException(
        e,
        'Failed to submit finalized ACME order',
        acmeOrderExceptionFromDioException,
        onWrapped: (wrapped) => connection.logger?.call(
          AcmeLogLevel.error,
          wrapped.message,
          error: e,
          stackTrace: s,
        ),
      );
    }
  }

  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be updated while polling a finalized order')
  /// @Throwing(AcmeOrderException, reason: 'polling the finalized order failed')
  Future<_OrderResults> _pollFinalizedOrder(AcmeConnection connection) async {
    await Future.delayed(const Duration(seconds: 4), () {});

    try {
      final response = await acmeConnectionResolvedDio(
        connection,
      ).get<Map<String, Object?>>(orderUrl!);
      final persistent = acmeOrderFromResponseMap(
        response.data! as Map<String, dynamic>,
      );
      return _OrderResults(response, persistent);
    } on DioException catch (e, s) {
      acmeConnectionJwsManager(connection).captureErrorNonce(e);
      throw acmeWrapDioException(
        e,
        'Failed while polling finalized ACME order',
        acmeOrderExceptionFromDioException,
        onWrapped: (wrapped) => connection.logger?.call(
          AcmeLogLevel.error,
          wrapped.message,
          error: e,
          stackTrace: s,
        ),
      );
    }
  }
}

/// Attaches connection/account context to an order instance.
///
/// Why this exists: fluent order operations need their owning session context,
/// but that attachment step should not show up as part of the public `Order`
/// API surface.
Order acmeOrderAttachConnection(
  Order order,
  AcmeConnection connection,
  Account account,
) => order._attachConnection(connection, account);

/// Creates a new ACME order for an attached account.
///
/// Why this exists: `Account.createOrder` is the intended public entrypoint, so
/// the lower-level protocol helper stays off the `Order` class documentation.
Future<Order> acmeOrderCreate(
  AcmeConnection connection,
  Account account,
  Order order,
) async {
  final jws = await acmeConnectionJwsManager(connection).createJws(
    acmeConnectionDirectories(connection)!.newOrder!,
    newNonceUrl: acmeConnectionDirectories(connection)!.newNonce,
    accountUrl: account.accountURL,
    useKid: true,
    payload: acmeOrderToCreationPayload(order),
  );
  final body = json.encode(jws.toJson());
  const headers = {'Content-Type': 'application/jose+json'};
  try {
    final response = await acmeConnectionResolvedDio(connection).post<Object?>(
      acmeConnectionDirectories(connection)!.newOrder!,
      data: body,
      options: Options(headers: headers),
    );
    acmeConnectionJwsManager(connection).updateNonce(response);
    return acmeOrderFromResponse(response)._inheritChallengeTypeFrom(order);
  } on DioException catch (e, s) {
    acmeConnectionJwsManager(connection).captureErrorNonce(e);
    throw acmeWrapDioException(
      e,
      'Failed to create ACME order',
      acmeOrderExceptionFromDioException,
      onWrapped: (wrapped) => connection.logger?.call(
        AcmeLogLevel.error,
        wrapped.message,
        error: e,
        stackTrace: s,
      ),
    );
  }
}

/// Builds the ACME new-order request payload from the public order input.
///
/// Why this exists: creating an order still needs a wire-format payload, but
/// `Order` should not expose generic JSON serialization as public API.
Map<String, dynamic> acmeOrderToCreationPayload(Order order) =>
    order._toCreationPayload();

/// Fetches the current state of an existing ACME order.
///
/// Why this exists: `Order.refresh` is the intended public entrypoint, so the
/// raw fetch helper remains a package-level implementation detail.
Future<Order> acmeOrderFetch(
  AcmeConnection connection,
  Account account,
  Order order,
) async {
  final jws = await acmeConnectionJwsManager(connection).createJws(
    order.orderUrl!,
    newNonceUrl: acmeConnectionDirectories(connection)!.newNonce,
    accountUrl: account.accountURL,
    useKid: true,
  );
  final body = json.encode(jws.toJson());
  const headers = {'Content-Type': 'application/jose+json'};
  try {
    final response = await acmeConnectionResolvedDio(connection).post<Object?>(
      order.orderUrl!,
      data: body,
      options: Options(headers: headers),
    );
    acmeConnectionJwsManager(connection).updateNonce(response);
    return acmeOrderFromResponse(response)._inheritChallengeTypeFrom(order);
  } on DioException catch (e, s) {
    acmeConnectionJwsManager(connection).captureErrorNonce(e);
    throw acmeWrapDioException(
      e,
      'Failed to fetch ACME order info',
      acmeOrderExceptionFromDioException,
      onWrapped: (wrapped) => connection.logger?.call(
        AcmeLogLevel.error,
        wrapped.message,
        error: e,
        stackTrace: s,
      ),
    );
  }
}

class _OrderResults {
  _OrderResults(this.response, this.order);

  final Response<Object?> response;
  final Order order;
}

// Public API docs intentionally keep some long protocol explanations unwrapped.
// ignore_for_file: lines_longer_than_80_chars, avoid_returning_this
