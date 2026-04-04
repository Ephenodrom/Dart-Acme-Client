import 'dart:convert';

import 'package:acme_client/src/acme_account_credentials.dart';
import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/acme_connection.dart';
import 'package:acme_client/src/acme_logger.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/dns_dcv_data.dart';
import 'package:acme_client/src/model/dns_persist_challenge_data.dart';
import 'package:acme_client/src/model/order.dart';
import 'package:acme_client/src/model/order_url.dart';
import 'package:acme_client/src/model/http_dcv_data.dart';
import 'package:acme_client/src/payloads/payloads.dart';
import 'package:acme_client/src/wire/account_resource.dart';
import 'package:dio/dio.dart';
class Account {
  String? accountURL;
  List<String>? contact;
  String? initialIp;
  DateTime? createdAt;
  String? status;
  bool? termsOfServiceAgreed;
  String? orders;
  AcmeConnection? _connection;

  Account({
    this.accountURL,
    this.contact,
    this.createdAt,
    this.initialIp,
    this.status,
    this.termsOfServiceAgreed,
    this.orders,
  });

  Account _attachConnection(AcmeConnection connection) {
    _connection = connection;
    acmeConnectionBindAccount(connection, this);
    return this;
  }

  /// @Throwing(AcmeJwsException, reason: 'order creation request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated for order creation')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected or failed to create the order')
  Future<Order> createOrder(Order order) async =>
      acmeOrderAttachConnection(
        await acmeOrderCreate(_requireConnection(), this, order),
        _requireConnection(),
        this,
      );

  /// @Throwing(AcmeJwsException, reason: 'order list request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated for order listing')
  /// @Throwing(AcmeOrderException, reason: 'the ACME server rejected the order list request or returned an unexpected payload')
  Future<List<OrderUrl>> listOrderUrls() =>
      acmeAccountFetchOrderUrls(_requireConnection(), this);

  AcmeAccountCredentials toAccountCredentials() =>
      acmeConnectionToAccountCredentials(_requireConnection());

  Future<bool> validate(Challenge challenge, {int maxAttempts = 15}) =>
      acmeConnectionValidate(
        _requireConnection(),
        challenge,
        maxAttempts: maxAttempts,
      );

  Future<bool> selfDNSTest(DnsChallengeData data, {int maxAttempts = 15}) =>
      acmeConnectionSelfDnsTest(
        _requireConnection(),
        data,
        maxAttempts: maxAttempts,
      );

  Future<bool> selfDNSPersistTest(
    DnsPersistChallengeData data, {
    int maxAttempts = 15,
  }) => acmeConnectionSelfDnsPersistTest(
    _requireConnection(),
    data,
    maxAttempts: maxAttempts,
  );

  Future<bool> selfHttpTest(HttpChallengeData data, {int maxAttempts = 15}) =>
      acmeConnectionSelfHttpTest(
        _requireConnection(),
        data,
        maxAttempts: maxAttempts,
      );

  AcmeConnection _requireConnection() => _connection ??
      (throw StateError('Account is not attached to an ACME connection'));

  /// @Throwing(AcmeAccountException, reason: 'account lookup failed and the account could not be created')
  /// @Throwing(AcmeJwsException, reason: 'account lookup request could not be signed')
  /// @Throwing(AcmeNonceException, reason: 'a replay nonce could not be obtained or updated while looking up the account')
  static Future<Account> fetch(
    AcmeAccountCredentials credentials, {
    AcmeConnection connection = const AcmeConnection.letsEncrypt(),
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
      final response = await acmeConnectionResolvedDio(boundConnection).post(
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
      throw AcmeClientException.wrapDioException(
        e,
        'Failed to fetch ACME account',
        AcmeAccountException.fromDioException,
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
  static Future<Account> create(
    AcmeAccountCredentials credentials, {
    AcmeConnection connection = const AcmeConnection.letsEncrypt(),
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
      final response = await acmeConnectionResolvedDio(boundConnection).post(
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
      throw AcmeClientException.wrapDioException(
        e,
        'Failed to create ACME account',
        AcmeAccountException.fromDioException,
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
    final response = await acmeConnectionResolvedDio(connection).post(
      url,
      data: body,
      options: Options(headers: headers),
    );
    acmeConnectionJwsManager(connection).updateNonce(response);
    connection.logger?.call(AcmeLogLevel.debug, 'Fetched order list response');
    final data = response.data;
    if (data is Map<String, dynamic> && data['orders'] is List) {
      return (data['orders'] as List).cast<String>().map(OrderUrl.parse).toList();
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
    throw AcmeClientException.wrapDioException(
      e,
      'Failed to fetch ACME order list',
      AcmeOrderException.fromDioException,
      onWrapped: (wrapped) => connection.logger?.call(
        AcmeLogLevel.error,
        wrapped.message,
        error: e,
        stackTrace: s,
      ),
    );
  }
}
