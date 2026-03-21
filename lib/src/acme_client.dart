import 'dart:convert';

import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/acme_logger.dart';
import 'package:acme_client/src/acme_util.dart';
import 'package:acme_client/src/constants.dart';
import 'package:acme_client/src/model/account.dart';
import 'package:acme_client/src/model/acme_directories.dart';
import 'package:acme_client/src/model/authorization.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/challenge_error.dart';
import 'package:acme_client/src/model/dns_dcv_data.dart';
import 'package:acme_client/src/model/http_dcv_data.dart';
import 'package:acme_client/src/model/order.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:dio/dio.dart';
import 'package:jose/jose.dart';

///
/// The ACME Client
///
class AcmeClient {
  ///
  /// The base url of the ACME server
  ///
  String baseUrl;

  ///
  /// The list of contacts
  ///
  List<String> contacts;

  ///
  /// The ACME directories fetched from the server
  ///
  AcmeDirectories? directories;

  ///
  /// The private key as a PEM
  ///
  String privateKeyPem;

  ///
  /// The public key as a PEM
  ///
  String publicKeyPem;

  ///
  /// The account information fetched from the ACME server
  ///
  Account? account;

  ///
  /// The latest nonce received from the ACME server
  ///
  String? nonce;

  ///
  /// Boolean value to define whether to accept the terms of condition or not
  ///
  bool acceptTerms;

  ///
  /// Boolean value that defines if a new account should be created if none found for the given public key
  ///
  bool createIfNotExists;

  /// Optional diagnostic logger. When omitted, the library is silent.
  final AcmeLogFn? logger;

  ///
  /// * [baseUrl] = The base url of the acme server
  /// * [privateKeyPem] = The private key in PEM format. If none given, it will look within the [basePath] for a private key
  /// * [publicKeyPem]  = The public key in PEM format. If none given, it will look within the [basePath] for a public key
  /// * [acceptTerms] = Accept terms and condition while creating / fetching an account
  /// * [contacts] = A list of email addresses
  /// * [createIfNotExists] = Defines whether to create an account if none exists
  ///
  AcmeClient(
    this.baseUrl,
    this.privateKeyPem,
    this.publicKeyPem,
    this.acceptTerms,
    this.contacts, {
    this.createIfNotExists = true,
    this.logger,
  });

  ///
  /// Will initate the ACME client.
  ///
  /// The client will fetch the directories according to the given baseUrl and try to retreive the account information.
  /// Depending on [createIfNotExists] it will create a new account if none exists.
  ///
  Future<void> init() async {
    // Validate data
    validateData();

    // Load directories
    directories = await _getDirectories();

    // Get Account
    account = await getAccount(createIfnotExists: createIfNotExists);
  }

  ///
  /// Starts a new order
  ///
  /// RFC: https://datatracker.ietf.org/doc/html/rfc8555#section-7.4
  ///
  Future<Order> order(Order order) async {
    var jws = await _createJWS(directories!.newOrder!,
        useKid: true, payload: order.toJson());
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        directories!.newOrder!,
        data: body,
        options: Options(headers: headers),
      );
      _updateNonce(response);
      var orderUrl = '';
      if (!response.headers.isEmpty) {
        if (response.headers.map.containsKey('Location')) {
          orderUrl = response.headers.map['Location']!.first;
        }
      }
      var newOrder = Order.fromJson(response.data);
      newOrder.orderUrl = orderUrl;
      return newOrder;
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeOrderException>(
        e,
        'Failed to create ACME order',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeOrderException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Fetch order info
  ///
  /// RFC: https://datatracker.ietf.org/doc/html/rfc8555#section-7.4
  ///
  Future<Order> orderInfo(Order order) async {
    var jws = await _createJWS(order.orderUrl!, useKid: true);
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        order.orderUrl!,
        data: body,
        options: Options(headers: headers),
      );
      _updateNonce(response);
      var newOrder = Order.fromJson(response.data);
      return newOrder;
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeOrderException>(
        e,
        'Failed to fetch ACME order info',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeOrderException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Fetches a list of current running orders
  ///
  Future<List<String>> orderList() async {
    var url = '${account!.accountURL!}/orders';
    var jws = await _createJWS(url, useKid: true);
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        url,
        data: body,
        options: Options(headers: headers),
      );
      _updateNonce(response);
      _log(AcmeLogLevel.debug, 'Fetched order list response');
      final data = response.data;
      if (data is Map<String, dynamic> && data['orders'] is List) {
        return List<String>.from(data['orders'] as List);
      }
      if (data is List) {
        return List<String>.from(data);
      }
      throw AcmeOrderException(
        'Unexpected ACME order list response format',
        uri: Uri.tryParse(url),
        rawBody: data,
      );
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeOrderException>(
        e,
        'Failed to fetch ACME order list',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeOrderException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Triggers the validation for the given challenge
  ///
  /// RFC: https://datatracker.ietf.org/doc/html/rfc8555#section-7.5.1
  ///
  Future<bool> validate(Challenge challenge, {int maxAttempts = 15}) async {
    var jws = await _createJWS(challenge.url!, useKid: true, payload: {
      'keyAuthorization':
          '${challenge.token!}.${AcmeUtils.getDigest(JsonWebKey.fromPem(publicKeyPem))}'
    });
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        challenge.url!,
        data: body,
        options: Options(headers: headers),
      );
      _updateNonce(response);
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeValidationException>(
        e,
        'Failed to trigger ACME challenge validation',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeValidationException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }

    while (maxAttempts > 0) {
      var jws = await _createJWS(challenge.authorizationUrl!, useKid: true);
      var body = json.encode(jws.toJson());

      try {
        var response = await Dio().post(
          challenge.authorizationUrl!,
          data: body,
          options: Options(headers: headers),
        );
        _updateNonce(response);
        var auth = Authorization.fromJson(response.data);
        if (auth.status == 'valid') {
          return true;
        }
        if (auth.status == 'invalid') {
          final failure = _extractChallengeFailure(auth, challenge.type);
          throw AcmeValidationException(
            failure?.detail ?? 'ACME challenge validation failed',
            uri: Uri.tryParse(challenge.authorizationUrl!),
            statusCode: failure?.status,
            type: failure?.type,
            detail: failure?.detail,
            rawBody: response.data,
          );
        }
      } on DioException catch (e, s) {
        _captureErrorNonce(e);
        throw _requestException<AcmeValidationException>(
          e,
          'Failed while polling ACME challenge authorization',
          (message, {uri, statusCode, type, detail, rawBody, cause}) =>
              AcmeValidationException(
            message,
            uri: uri,
            statusCode: statusCode,
            type: type,
            detail: detail,
            rawBody: rawBody,
            cause: cause,
          ),
          stackTrace: s,
        );
      }
      maxAttempts--;
      if (maxAttempts > 0) {
        await Future.delayed(const Duration(seconds: 4));
      }
    }

    throw AcmeValidationException(
      'Timed out waiting for ACME challenge validation',
      uri: Uri.tryParse(challenge.authorizationUrl ?? challenge.url ?? ''),
    );
  }

  ///
  /// Fetches a list of [Authorization] for the given [order]
  ///
  /// RFC: <https://datatracker.ietf.org/doc/html/rfc8555#section-7.5>
  ///
  Future<List<Authorization>> getAuthorization(Order order) async {
    var auth = <Authorization>[];
    for (var authUrl in order.authorizations!) {
      var jws = await _createJWS(authUrl, useKid: true);
      var body = json.encode(jws.toJson());
      var headers = {'Content-Type': 'application/jose+json'};
      try {
        var response = await Dio().post(
          authUrl,
          data: body,
          options: Options(headers: headers),
        );
        _updateNonce(response);
        var a = Authorization.fromJson(response.data);
        a.digest = AcmeUtils.getDigest(JsonWebKey.fromPem(publicKeyPem));
        for (var chall in a.challenges!) {
          chall.authorizationUrl = authUrl;
        }
        auth.add(a);
      } on DioException catch (e, s) {
        _captureErrorNonce(e);
        throw _requestException<AcmeAuthorizationException>(
          e,
          'Failed to fetch ACME authorization',
          (message, {uri, statusCode, type, detail, rawBody, cause}) =>
              AcmeAuthorizationException(
            message,
            uri: uri,
            statusCode: statusCode,
            type: type,
            detail: detail,
            rawBody: rawBody,
            cause: cause,
          ),
          stackTrace: s,
        );
      }
    }
    return auth;
  }

  ///
  /// Will check the status of the order to be 'ready' by sending a POST-AS-GET request
  /// to the order url.
  ///
  /// Returns true if the status is 'ready' otherwise false.
  ///
  Future<bool> isReady(Order order) async {
    var persistent = await orderInfo(order);
    return persistent.status == 'ready';
  }

  ///
  /// Will finalize the order by sending a POST request to the order's finalize url including the
  /// given [csr] in the payload. The given [csr] will be transformed in the necessary base64url encoding.
  ///
  /// RFC : <https://datatracker.ietf.org/doc/html/rfc8555#page-47>
  /// When attempting to finalize the order the CA may not immediately return
  /// the certificate. In this case we will wait 4 seconds and try again
  /// to fetch the certificate (url). This usually works on the first try but
  /// we allow you to set the retry limit via [retries] which defaults to 5.
  Future<Order> finalizeOrder(Order order, String csr,
      {int retries = 5}) async {
    var transformedCsr = AcmeUtils.formatCsrBase64Url(csr);
    var firstpass = true;
    Results results;
    do {
      if (firstpass) {
        results = await _finalizeOrder(order, transformedCsr);
      } else {
        results = await _retry(order, transformedCsr);
      }
      firstpass = false;
      retries--;

      /// the CA was stilling processing the order
    } while (results.response.data['status'] == 'processing' && retries > 0);

    if (results.response.data['status'] != 'valid') {
      throw AcmeOrderException(
        'ACME order finalization did not complete successfully',
        uri: Uri.tryParse(order.orderUrl ?? order.finalize ?? ''),
        rawBody: results.response.data,
        detail: results.response.data['status']?.toString(),
      );
    }

    return results.order;
  }

  Future<Results> _finalizeOrder(Order order, String transformedCsr) async {
    return _fetchOrder(order.finalize!, transformedCsr);
  }

  /// If the order was in a state of 'processing' when we called finalize
  /// we need to retry fetching the order.
  Future<Results> _retry(Order order, String transformedCsr) async {
    /// If we are retrying then delay
    await Future.delayed(Duration(seconds: 4), () {});

    try {
      final response = await Dio().get(order.orderUrl!);
      final persistent = Order.fromJson(response.data);
      return Results(response, persistent);
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeOrderException>(
        e,
        'Failed while polling finalized ACME order',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeOrderException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  Future<Results> _fetchOrder(String url, String transformedCsr) async {
    var jws = await _createJWS(url, useKid: true, payload: {
      'csr': transformedCsr,
    });
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};

    try {
      final response = await Dio().post(
        url,
        data: body,
        options: Options(headers: headers),
      );
      final persistent = Order.fromJson(response.data);
      _updateNonce(response);

      return Results(response, persistent);
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeOrderException>(
        e,
        'Failed to submit finalized ACME order',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeOrderException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Fetches the certificate with the complete chain from the ACME server.
  ///
  Future<List<String>> getCertificate(Order order) async {
    var jws = await _createJWS(order.certificate!, useKid: true);
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        order.certificate!,
        data: body,
        options: Options(headers: headers),
      );
      var certs = <String>[];
      var data = response.data as String;
      var b = StringBuffer();
      for (var line in LineSplitter.split(data)) {
        if (line.isEmpty) {
          continue;
        }
        b.write(line);
        if (line == X509Utils.END_CERT) {
          certs.add(b.toString());
          b.clear();
        }
      }
      _updateNonce(response);
      return certs;
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeCertificateException>(
        e,
        'Failed to fetch ACME certificate chain',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeCertificateException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// A test whether the DNS record is placed or not. Uses the Google DNS JSON API to check the corresponding zone file.
  ///
  Future<bool> selfDNSTest(DnsDcvData data, {int maxAttempts = 15}) async {
    for (var i = 0; i < maxAttempts; i++) {
      var records = await DnsUtils.lookupRecord(
          data.rRecord.name, RRecordType.TXT,
          provider: DnsApiProvider.GOOGLE);
      if (records != null &&
          records.isNotEmpty &&
          records.first.data == data.rRecord.data) {
        _log(AcmeLogLevel.debug, 'Found record via Google DNS');
        return true;
      }
      _log(AcmeLogLevel.debug, 'DNS record not visible via Google DNS yet');
      await Future.delayed(Duration(seconds: 4));
    }
    return false;
  }

  ///
  /// A test whether the HTTP token is placed or not. Uses a simple HTTP GET request to check for the corresponding file on the server.
  ///
  Future<bool> selfHttpTest(HttpDcvData data, {int maxAttempts = 15}) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        var response = await Dio().get(data.fileName);
        if (response.data is String) {
          if (response.data(String) == data.fileContent) {
            return true;
          }
        }
      } on DioException catch (e, s) {
        _log(
          AcmeLogLevel.debug,
          'HTTP self-test request failed',
          error: e,
          stackTrace: s,
        );
      }
      await Future.delayed(Duration(seconds: 4));
    }
    return false;
  }

  ///
  /// Fetches the account information for [publicKeyPem].
  ///
  /// * [createIfnotExists] defines wether to create a new account if none exists
  ///
  Future<Account> getAccount({bool createIfnotExists = true}) async {
    var payload = {
      'onlyReturnExisting': true,
      'termsOfServiceAgreed': acceptTerms,
      'contact': contacts
    };

    var jws = await _createJWS(directories!.newAccount!, payload: payload);
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        directories!.newAccount!,
        data: body,
        options: Options(headers: headers),
      );
      _updateNonce(response);
      return _accountFromResponse(response);
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      if (createIfnotExists && e.response?.statusCode == 400) {
        return createAccount();
      }
      throw _requestException<AcmeAccountException>(
        e,
        'Failed to fetch ACME account',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeAccountException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Creates a new account for [publicKeyPem] by sending a POST request to the
  /// new account url.
  ///
  Future<Account> createAccount() async {
    var payload = {
      'onlyReturnExisting': false,
      'termsOfServiceAgreed': acceptTerms,
      'contact': contacts
    };

    var jws = await _createJWS(directories!.newAccount!, payload: payload);
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        directories!.newAccount!,
        data: body,
        options: Options(headers: headers),
      );
      _updateNonce(response);
      return _accountFromResponse(response);
    } on DioException catch (e, s) {
      _captureErrorNonce(e);
      throw _requestException<AcmeAccountException>(
        e,
        'Failed to create ACME account',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeAccountException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Creates a JSON WEB SIGNATURE
  ///
  Future<JsonWebSignature> _createJWS(String url,
      {bool useKid = false, Map<String, dynamic>? payload}) async {
    nonce ??= await _getNonce();
    var builder = JsonWebSignatureBuilder();

    var privateJwk = JsonWebKey.fromPem(privateKeyPem);
    var publicJwk = JsonWebKey.fromPem(publicKeyPem);

    if (payload == null) {
      builder.stringContent = '';
    } else {
      builder.stringContent = json.encode(payload);
    }
    builder.addRecipient(privateJwk, algorithm: 'RS256');
    if (useKid) {
      builder.setProtectedHeader('kid', account!.accountURL!);
    } else {
      builder.setProtectedHeader('jwk', publicJwk.toJson());
    }
    builder.setProtectedHeader('nonce', nonce);
    builder.setProtectedHeader('url', url);

    var jws = builder.build();

    return jws;
  }

  ///
  /// Fetches the directories from the ACME server
  ///
  Future<AcmeDirectories> _getDirectories() async {
    try {
      var response = await Dio().get('$baseUrl/directory');
      return AcmeDirectories.fromJson(response.data);
    } on DioException catch (e, s) {
      throw _requestException<AcmeDirectoryException>(
        e,
        'Failed to fetch ACME directory',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeDirectoryException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Fetches a new nonce from the ACME server
  ///
  Future<String> _getNonce() async {
    try {
      var response = await Dio().head(directories!.newNonce!);
      var replayNonce = response.headers.value(HEADER_REPLAY_NONCE);
      if (replayNonce == null || replayNonce.isEmpty) {
        throw AcmeNonceException(
          'ACME server response did not include a replay nonce',
          uri: Uri.tryParse(directories!.newNonce!),
          rawBody: response.data,
        );
      }
      return replayNonce;
    } on DioException catch (e, s) {
      throw _requestException<AcmeNonceException>(
        e,
        'Failed to fetch ACME replay nonce',
        (message, {uri, statusCode, type, detail, rawBody, cause}) =>
            AcmeNonceException(
          message,
          uri: uri,
          statusCode: statusCode,
          type: type,
          detail: detail,
          rawBody: rawBody,
          cause: cause,
        ),
        stackTrace: s,
      );
    }
  }

  ///
  /// Validates the client data. Throws an [ArgumentError] if values are missing or incorrect.
  ///
  void validateData() {
    for (var element in contacts) {
      if (!element.startsWith('mailto')) {
        throw ArgumentError('Given contacts have to start with "mailto:"');
      }
    }

    if (StringUtils.isNullOrEmpty(baseUrl)) {
      throw ArgumentError('baseUrl is missing');
    }

    if (StringUtils.isNullOrEmpty(publicKeyPem)) {
      throw ArgumentError('Public key PEM is missing');
    }
  }

  Account _accountFromResponse(Response response) {
    var accountUrl = '';
    if (!response.headers.isEmpty &&
        response.headers.map.containsKey('Location')) {
      accountUrl = response.headers.map['Location']!.first;
    }
    final account = Account.fromJson(response.data);
    account.accountURL = accountUrl;
    return account;
  }

  void _updateNonce(Response response) {
    final replayNonce = response.headers.value(HEADER_REPLAY_NONCE);
    if (replayNonce != null && replayNonce.isNotEmpty) {
      nonce = replayNonce;
    }
  }

  void _captureErrorNonce(DioException e) {
    final replayNonce = e.response?.headers.value(HEADER_REPLAY_NONCE);
    if (replayNonce != null && replayNonce.isNotEmpty) {
      nonce = replayNonce;
    }
  }

  ChallengeError? _extractChallengeFailure(
      Authorization authorization, String? type) {
    if (authorization.challenges == null || type == null) {
      return null;
    }
    for (final challenge in authorization.challenges!) {
      if (challenge.type == type && challenge.error != null) {
        return challenge.error;
      }
    }
    return null;
  }

  T _requestException<T extends AcmeClientException>(
    DioException exception,
    String fallbackMessage,
    T Function(
      String message, {
      Uri? uri,
      int? statusCode,
      String? type,
      String? detail,
      Object? rawBody,
      Object? cause,
    }) builder, {
    StackTrace? stackTrace,
  }) {
    final response = exception.response;
    final rawBody = response?.data;
    final detail = _extractErrorDetail(rawBody) ?? exception.message;
    final type = _extractErrorType(rawBody);
    final uri = Uri.tryParse(response?.realUri.toString() ??
        exception.requestOptions.uri.toString());
    final message = detail == null || detail.isEmpty
        ? fallbackMessage
        : '$fallbackMessage: $detail';

    _log(AcmeLogLevel.error, message, error: exception, stackTrace: stackTrace);

    return builder(
      message,
      uri: uri,
      statusCode: response?.statusCode,
      type: type,
      detail: detail,
      rawBody: rawBody,
      cause: exception,
    );
  }

  String? _extractErrorDetail(Object? rawBody) {
    if (rawBody is Map<String, dynamic>) {
      final challengeDetail =
          _nestedString(rawBody, ['challenges', '0', 'error', 'detail']);
      if (challengeDetail != null && challengeDetail.isNotEmpty) {
        return challengeDetail;
      }

      final detail = rawBody['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }

      final error = rawBody['error'];
      if (error is Map<String, dynamic>) {
        final nestedDetail = error['detail'];
        if (nestedDetail is String && nestedDetail.isNotEmpty) {
          return nestedDetail;
        }
      }
    }

    if (rawBody is String && rawBody.isNotEmpty) {
      return rawBody;
    }

    return null;
  }

  String? _extractErrorType(Object? rawBody) {
    if (rawBody is Map<String, dynamic>) {
      final challengeType =
          _nestedString(rawBody, ['challenges', '0', 'error', 'type']);
      if (challengeType != null && challengeType.isNotEmpty) {
        return challengeType;
      }

      final type = rawBody['type'];
      if (type is String && type.isNotEmpty) {
        return type;
      }

      final error = rawBody['error'];
      if (error is Map<String, dynamic>) {
        final nestedType = error['type'];
        if (nestedType is String && nestedType.isNotEmpty) {
          return nestedType;
        }
      }
    }

    return null;
  }

  String? _nestedString(Map<String, dynamic> rawBody, List<String> path) {
    Object? current = rawBody;
    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }
      if (current is List<Object?>) {
        final index = int.tryParse(segment);
        if (index == null || index >= current.length) {
          return null;
        }
        current = current[index];
        continue;
      }
      return null;
    }
    return current is String ? current : null;
  }

  void _log(
    AcmeLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    logger?.call(level, message, error: error, stackTrace: stackTrace);
  }
}

class Results {
  Results(this.response, this.order);
  Response response;
  Order order;
}
