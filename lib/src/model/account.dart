import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../acme_client.dart' show CertificateCredentials;
import '../acme_account_credentials.dart';
import '../acme_client_exception.dart';
import '../acme_connection.dart';
import '../acme_exception_factory.dart';
import '../acme_logger.dart';
import '../certificate_credentials.dart' show CertificateCredentials;
import '../payloads/payloads.dart';
import '../wire/account_resource.dart';
import 'account_status.dart';
import 'challenge.dart';
import 'challenge_order.dart';
import 'challenge_type.dart';
import 'dns_challenge.dart';
import 'dns_persist_challenge.dart';
import 'http_challenge.dart';
import 'identifiers.dart';
import 'order.dart';
import 'order_url.dart';

/// An ACME account bound to a specific [AcmeConnection].
///
/// In the overall flow, the account is the starting point for everything else:
/// you create or fetch it using [AcmeAccountCredentials], then use it to
/// discover challenge support, create orders, and later list prior orders.
///
/// The account key identifies you to the ACME server. It is separate from the
/// certificate key used in [CertificateCredentials].
class Account {
  final String? accountURL;
  final List<String> contact;
  final DateTime? createdAt;
  final AccountStatus status;
  final bool termsOfServiceAgreed;
  final OrderUrl? ordersUrl;
  AcmeConnection? _connection;

  @internal
  Account({
    this.accountURL,
    this.contact = const [],
    this.createdAt,
    this.status = AccountStatus.unknown,
    this.termsOfServiceAgreed = false,
    this.ordersUrl,
  });

  Account _attachConnection(AcmeConnection connection) {
    _connection = connection;
    acmeConnectionBindAccount(connection, this);
    return this;
  }

  /// @Throwing(AcmeJwsException, reason: 'order creation request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated for order creation')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected or failed to create the order')
  Future<ChallengeOrder<TChallenge>> _createOrder<TChallenge extends Challenge>(
    Order order,
  ) async {
    final createdOrder = acmeOrderAttachConnection(
      await acmeOrderCreate(_requireConnection(), this, order),
      _requireConnection(),
      this,
    );
    final typedOrder = ChallengeOrder<TChallenge>.internal(
      createdOrder,
      _requireConnection(),
      this,
    );
    final authorizations = await createdOrder.getAuthorizations();
    final selectedChallengeType = acmeChallengeTypeFor<TChallenge>();
    final identifiersToCheck =
        createdOrder.identifiers ?? order.identifiers ?? const [];
    final unsupportedIdentifiers = identifiersToCheck
        .where(
          (identifier) => !createdOrder
              .authorizationsForIdentifier(identifier, authorizations)
              .any(
                (authorization) => authorization.hasChallenge(
                  challengeType: selectedChallengeType,
                ),
              ),
        )
        .toList();
    if (unsupportedIdentifiers.isNotEmpty) {
      throw AcmeAuthorizationException(
        'The ACME server does not support the requested challenge type for this order',
        detail:
            '${selectedChallengeType.wireValue} unsupported for ${unsupportedIdentifiers.map((identifier) => identifier.value).join(', ')}',
        rawBody: authorizations
            .map(
              (authorization) => {
                'identifier': authorization.identifier?.value,
                'supportedChallengeTypes': authorization.challenges
                    ?.map((challenge) => challenge.type)
                    .toList(),
              },
            )
            .toList(),
      );
    }
    return typedOrder;
  }

  /// Creates a new order and locks the workflow to `http-01`.
  ///
  /// Use this when you plan to satisfy the order by serving a token at
  /// `/.well-known/acme-challenge/...` over HTTP. After creating the order, the
  /// typical next steps are:
  ///
  /// 1. call [ChallengeOrder.getAuthorization]
  /// 2. call `getChallenge()` on the returned authorization
  /// 3. call `buildProof()`, publish the proof, and optionally `selfTest()`
  /// 4. call `validate()`
  /// 5. once the order is ready, call [ChallengeOrder.finalize]
  ///
  /// If the CA does not offer `http-01` for one of the requested identifiers,
  /// this method throws and includes the challenge types that were offered.
  Future<ChallengeOrder<HttpChallenge>> createOrderForHttp({
    required List<DomainIdentifier> identifiers,
    DateTime? notBefore,
    DateTime? notAfter,
  }) => _createOrder<HttpChallenge>(
    Order(identifiers: identifiers, notBefore: notBefore, notAfter: notAfter),
  );

  /// Creates a new order and locks the workflow to `dns-01`.
  ///
  /// Use this when you plan to satisfy the order by publishing a TXT record at
  /// `_acme-challenge.<domain>`. The rest of the flow mirrors
  /// [createOrderForHttp], but the proof is published in DNS rather than over
  /// HTTP.
  ///
  /// If the CA does not offer `dns-01` for one of the requested identifiers,
  /// this method throws and includes the challenge types that were offered.
  Future<ChallengeOrder<DnsChallenge>> createOrderForDns({
    required List<DomainIdentifier> identifiers,
    DateTime? notBefore,
    DateTime? notAfter,
  }) => _createOrder<DnsChallenge>(
    Order(identifiers: identifiers, notBefore: notBefore, notAfter: notAfter),
  );

  /// Creates a new order and locks the workflow to `dns-persist-01`.
  ///
  /// Use this when the CA supports persistent delegated DNS validation. The
  /// resulting proof is a TXT record under `_validation-persist.<domain>`.
  ///
  /// If the CA does not offer `dns-persist-01` for one of the requested
  /// identifiers, this method throws and includes the challenge types that were
  /// offered.
  Future<ChallengeOrder<DnsPersistChallenge>> createOrderForDnsPersist({
    required List<DomainIdentifier> identifiers,
    DateTime? notBefore,
    DateTime? notAfter,
  }) => _createOrder<DnsPersistChallenge>(
    Order(identifiers: identifiers, notBefore: notBefore, notAfter: notAfter),
  );

  /// Returns the challenge types the CA currently offers for [identifier].
  ///
  /// This is the lightweight discovery path. It creates a temporary order for
  /// the identifier, fetches the returned authorizations, and reports the
  /// challenge types the CA made available. This is useful when you need to
  /// choose between HTTP, DNS, or dns-persist before starting the main flow.
  ///
  /// Most callers can skip this entirely and go straight to one of the
  /// `createOrderFor...` methods if they already know which challenge they want
  /// to use.
  Future<List<ChallengeType>> discoverAvailableChallenges({
    required DomainIdentifier identifier,
    DateTime? notBefore,
    DateTime? notAfter,
  }) async {
    final order = acmeOrderAttachConnection(
      await acmeOrderCreate(
        _requireConnection(),
        this,
        Order(
          identifiers: [identifier],
          notBefore: notBefore,
          notAfter: notAfter,
        ),
      ),
      _requireConnection(),
      this,
    );
    final challenges = await order.discoverAvailableChallenges(identifier);
    final types = <ChallengeType>[];
    for (final challenge in challenges) {
      if (!types.contains(challenge.challengeType)) {
        types.add(challenge.challengeType);
      }
    }
    return types;
  }

  /// @Throwing(AcmeJwsException, reason: 'order list request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated for order listing')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected the order list request or returned an unexpected payload')
  ///
  /// Returns the URLs of orders currently associated with this account.
  ///
  /// This is mainly an inspection or bookkeeping API. It is not normally part
  /// of the standard issuance flow.
  Future<List<OrderUrl>> listOrderUrls() =>
      acmeAccountFetchOrderUrls(_requireConnection(), this);

  /// Recreates the account credentials currently attached to this account.
  ///
  /// Use this when you already have an attached [Account] and want to persist
  /// or reserialize the same ACME account identity for later use, such as
  /// renewals or service restarts.
  AcmeAccountCredentials toAccountCredentials() =>
      acmeConnectionToAccountCredentials(_requireConnection());

  AcmeConnection _requireConnection() =>
      _connection ??
      (throw StateError('Account is not attached to an ACME connection'));

  /// @Throwing(AcmeAccountException, reason: 'account lookup failed and the account could not be created')
  /// @Throwing(AcmeJwsException, reason: 'account lookup request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated while looking up the account')
  ///
  /// Fetches an existing ACME account using the supplied credentials.
  ///
  /// This is the normal entrypoint after the first run of an application. If
  /// you have already generated and stored [AcmeAccountCredentials], call this
  /// to reattach to the same ACME account for new orders or renewals.
  static Future<Account> fetch(
    AcmeAccountCredentials credentials, {
    AcmeConnection connection = AcmeConnection.production,
  }) async {
    final boundConnection = acmeConnectionBindCredentials(
      connection,
      credentials,
    );
    await acmeConnectionInit(boundConnection);
    final jws = await acmeConnectionJwsManager(boundConnection).createJws(
      acmeConnectionDirectories(boundConnection)!.newAccount!,
      newNonceUrl: acmeConnectionDirectories(boundConnection)!.newNonce,
      payload: AccountRequestPayload(
        onlyReturnExisting: true,
        termsOfServiceAgreed: acmeConnectionAcceptTerms(boundConnection),
        contact: acmeConnectionContacts(boundConnection),
      ),
    );
    final body = json.encode(jws.toJson());
    const headers = {'Content-Type': 'application/jose+json'};

    try {
      final response = await acmeConnectionResolvedDio(boundConnection)
          .post<Object?>(
            acmeConnectionDirectories(boundConnection)!.newAccount!,
            data: body,
            options: Options(headers: headers),
          );
      acmeConnectionJwsManager(boundConnection).updateNonce(response);
      return acmeAccountAttachConnection(
        acmeAccountFromResponse(response),
        boundConnection,
      );
    } on DioException catch (e, s) {
      acmeConnectionJwsManager(boundConnection).captureErrorNonce(e);
      throw acmeWrapDioException(
        e,
        'Failed to fetch ACME account',
        acmeAccountExceptionFromDioException,
        onWrapped: (wrapped) => boundConnection.logger?.call(
          AcmeLogLevel.error,
          wrapped.message,
          error: e,
          stackTrace: s,
        ),
      );
    }
  }

  /// @Throwing(AcmeAccountException, reason: 'account creation failed')
  /// @Throwing(AcmeJwsException, reason: 'account creation request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated while creating the account')
  ///
  /// Creates a brand-new ACME account.
  ///
  /// Call this once when bootstrapping new [AcmeAccountCredentials]. After the
  /// account exists, persist those credentials and use [fetch] on future runs
  /// rather than creating a new account each time.
  static Future<Account> create(
    AcmeAccountCredentials credentials, {
    AcmeConnection connection = AcmeConnection.production,
  }) async {
    final boundConnection = acmeConnectionBindCredentials(
      connection,
      credentials,
    );
    await acmeConnectionInit(boundConnection);
    final jws = await acmeConnectionJwsManager(boundConnection).createJws(
      acmeConnectionDirectories(boundConnection)!.newAccount!,
      newNonceUrl: acmeConnectionDirectories(boundConnection)!.newNonce,
      payload: AccountRequestPayload(
        onlyReturnExisting: false,
        termsOfServiceAgreed: acmeConnectionAcceptTerms(boundConnection),
        contact: acmeConnectionContacts(boundConnection),
      ),
    );
    final body = json.encode(jws.toJson());
    const headers = {'Content-Type': 'application/jose+json'};

    try {
      final response = await acmeConnectionResolvedDio(boundConnection)
          .post<Object?>(
            acmeConnectionDirectories(boundConnection)!.newAccount!,
            data: body,
            options: Options(headers: headers),
          );
      acmeConnectionJwsManager(boundConnection).updateNonce(response);
      return acmeAccountAttachConnection(
        acmeAccountFromResponse(response),
        boundConnection,
      );
    } on DioException catch (e, s) {
      acmeConnectionJwsManager(boundConnection).captureErrorNonce(e);
      throw acmeWrapDioException(
        e,
        'Failed to create ACME account',
        acmeAccountExceptionFromDioException,
        onWrapped: (wrapped) => boundConnection.logger?.call(
          AcmeLogLevel.error,
          wrapped.message,
          error: e,
          stackTrace: s,
        ),
      );
    }
  }

  /// @Throwing(AcmeJwsException, reason: 'order list request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated for order listing')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected the order list request or returned an unexpected payload')
}

/// Attaches the bound connection session to an account instance.
///
/// Why this exists: fluent instance methods on `Account` need session affinity,
/// but that wiring should not appear as a public method on the model class.
Account acmeAccountAttachConnection(
  Account account,
  AcmeConnection connection,
) => account._attachConnection(connection);

/// Fetches the order list for an attached account.
///
/// Why this exists: `Account.listOrderUrls` is public, but the raw protocol
/// helper should stay out of the generated API for the `Account` class itself.
Future<List<OrderUrl>> acmeAccountFetchOrderUrls(
  AcmeConnection connection,
  Account account,
) async {
  final url = '${account.accountURL!}/orders';
  final jws = await acmeConnectionJwsManager(connection).createJws(
    url,
    newNonceUrl: acmeConnectionDirectories(connection)!.newNonce,
    accountUrl: account.accountURL,
    useKid: true,
  );
  final body = json.encode(jws.toJson());
  const headers = {'Content-Type': 'application/jose+json'};
  try {
    final response = await acmeConnectionResolvedDio(connection).post<Object?>(
      url,
      data: body,
      options: Options(headers: headers),
    );
    acmeConnectionJwsManager(connection).updateNonce(response);
    connection.logger?.call(AcmeLogLevel.debug, 'Fetched order list response');
    final data = response.data;
    if (data is Map<String, dynamic> && data['orders'] is List) {
      return (data['orders'] as List)
          .cast<String>()
          .map(OrderUrl.parse)
          .toList();
    }
    if (data is List) {
      return data.cast<String>().map(OrderUrl.parse).toList();
    }
    throw AcmeOrderException(
      'Unexpected ACME order list response format',
      uri: Uri.tryParse(url),
      rawBody: data,
    );
  } on DioException catch (e, s) {
    acmeConnectionJwsManager(connection).captureErrorNonce(e);
    throw acmeWrapDioException(
      e,
      'Failed to fetch ACME order list',
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
// Public API docs intentionally keep some long protocol explanations unwrapped.
// ignore_for_file: lines_longer_than_80_chars, avoid_returning_this
