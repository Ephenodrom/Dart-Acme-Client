import 'dart:convert';

import 'package:acme_client/src/Constants.dart';
import 'package:acme_client/src/AcmeUtils.dart';
import 'package:acme_client/src/model/Account.dart';
import 'package:acme_client/src/model/AcmeDirectories.dart';
import 'package:acme_client/src/model/Authorization.dart';
import 'package:acme_client/src/model/Challenge.dart';
import 'package:acme_client/src/model/DnsDcvData.dart';
import 'package:acme_client/src/model/HttpDcvData.dart';
import 'package:acme_client/src/model/Order.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:dio/dio.dart';
import 'package:jose/jose.dart';

/// Checks if you are awesome. Spoiler: you are.
class AcmeClient {
  String baseUrl;

  List<String> contacts;

  AcmeDirectories? directories;

  String privateKeyPem;

  String publicKeyPem;

  Account? account;

  String? nonce;

  bool acceptTerms;

  ///
  /// * [baseUrl] = The base url of the acme server
  /// * [privateKeyPem] = The private key in PEM format. If none given, it will look within the [basePath] for a private key
  /// * [publicKeyPem]  = The public key in PEM format. If none given, it will look within the [basePath] for a public key
  /// * [acceptTerms] = Accept terms and condition while creating / fetching an account
  /// * [contacts] = A list of email addresses
  ///
  AcmeClient(
    this.baseUrl,
    this.privateKeyPem,
    this.publicKeyPem,
    this.acceptTerms,
    this.contacts,
  );

  ///
  ///
  ///
  Future<void> init() async {
    // Load directories
    directories = await _getDirectories();

    // Get Account
    account = await getAccount();
  }

  ///
  /// Starts a new order
  ///
  /// RFC: https://datatracker.ietf.org/doc/html/rfc8555#section-7.4
  ///
  Future<Order?> order(Order order) async {
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
      nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
      var orderUrl = '';
      if (!response.headers.isEmpty) {
        if (response.headers.map.containsKey('Location')) {
          orderUrl = response.headers.map['Location']!.first;
        }
      }
      var newOrder = Order.fromJson(response.data);
      newOrder.orderUrl = orderUrl;
      return newOrder;
    } on DioError catch (e) {
      print(e.response!.data!.toString());
      nonce = e.response!.headers.map[HEADER_REPLAY_NONCE]!.first;

      return null;
    }
  }

  ///
  /// Fetch order info
  ///
  /// RFC: https://datatracker.ietf.org/doc/html/rfc8555#section-7.4
  ///
  Future<Order?> orderInfo(Order order) async {
    var jws = await _createJWS(order.orderUrl!, useKid: true);
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        order.orderUrl!,
        data: body,
        options: Options(headers: headers),
      );
      nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
      var newOrder = Order.fromJson(response.data);
      return newOrder;
    } on DioError catch (e) {
      print(e.response!.data!.toString());
      nonce = e.response!.headers.map[HEADER_REPLAY_NONCE]!.first;

      return null;
    }
  }

  Future<List<String>?> orderList() async {
    var jws = await _createJWS(account!.accountURL! + '/orders', useKid: true);
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        account!.accountURL! + '/orders',
        data: body,
        options: Options(headers: headers),
      );
      print(response.data);
      return <String>[];
    } on DioError catch (e) {
      print(e.response!.data!.toString());
      return null;
    }
  }

  ///
  /// Triggers the validation for the given challenge
  ///
  /// RFC: https://datatracker.ietf.org/doc/html/rfc8555#section-7.5.1
  ///
  Future<bool> validate(Challenge challenge, {int maxAttempts = 15}) async {
    var jws = await _createJWS(challenge.url!, useKid: true, payload: {
      'keyAuthorization': challenge.token! +
          '.' +
          AcmeUtils.getDigest(JsonWebKey.fromPem(publicKeyPem))
    });
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        challenge.url!,
        data: body,
        options: Options(headers: headers),
      );
      nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
    } on DioError catch (e) {
      print(e.response!.data!.toString());
    }

    do {
      var jws = await _createJWS(challenge.authorizationUrl!, useKid: true);
      var body = json.encode(jws.toJson());

      try {
        var response = await Dio().post(
          challenge.authorizationUrl!,
          data: body,
          options: Options(headers: headers),
        );
        nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
        var auth = Authorization.fromJson(response.data);
        if (auth.status == 'valid') {
          return true;
        }
      } on DioError catch (e) {
        print(e.response!.data!.toString());
      }
      maxAttempts--;
      await Future.delayed(Duration(seconds: 4));
    } while (maxAttempts > 0);
    return false;
  }

  ///
  /// Fetches a list of [Authorization] for the given [order]
  ///
  /// RFC: <https://datatracker.ietf.org/doc/html/rfc8555#section-7.5>
  ///
  Future<List<Authorization>?> getAuthorization(Order order) async {
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
        nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
        var a = Authorization.fromJson(response.data);
        a.digest = AcmeUtils.getDigest(JsonWebKey.fromPem(publicKeyPem));
        for (var chall in a.challenges!) {
          chall.authorizationUrl = authUrl;
        }
        auth.add(a);
      } on DioError catch (e) {
        print(e.response!.data!.toString());
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
    return persistent!.status! == 'ready';
  }

  ///
  /// Will finalize the order by sending a POST request to the order's finalize url including the
  /// given [csr] in the payload. The given [csr] will be transformed in the necessary base64url encoding.
  ///
  /// RFC : <https://datatracker.ietf.org/doc/html/rfc8555#page-47>
  ///
  Future<Order?> finalizeOrder(Order order, String csr) async {
    var transformedCsr = AcmeUtils.formatCsrBase64Url(csr);
    var jws = await _createJWS(order.finalize!, useKid: true, payload: {
      'csr': transformedCsr,
    });
    var body = json.encode(jws.toJson());
    var headers = {'Content-Type': 'application/jose+json'};
    try {
      var response = await Dio().post(
        order.finalize!,
        data: body,
        options: Options(headers: headers),
      );
      var persistent = Order.fromJson(response.data);
      nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
      return persistent;
    } on DioError catch (e) {
      print(e.response!.data!.toString());
    }
  }

  Future<List<String>?> getCertificate(Order order) async {
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
      nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
      return certs;
    } on DioError catch (e) {
      print(e.response!.data!.toString());
    }
  }

  Future<bool> selfDNSTest(DnsDcvData data, {int maxAttempts = 15}) async {
    for (var i = 0; i < maxAttempts; i++) {
      var records = await DnsUtils.lookupRecord(
          data.rRecord.name, RRecordType.TXT,
          provider: DnsApiProvider.GOOGLE);
      if (records!.first.data == data.rRecord.data) {
        print('Found record at Google DNS');
        return true;
      } else {
        print('Record not found yet at Google DNS');
      }
      await Future.delayed(Duration(seconds: 4));
    }
    return false;
  }

  Future<bool> selfHttpTest(HttpDcvData data, {int maxAttempts = 15}) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        var response = await Dio().get(data.fileName);
        if (response.data is String) {
          if (response.data(String) == data.fileContent) {
            return true;
          }
        }
      } on DioError {
        // Do nothing
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
  Future<Account?> getAccount({bool createIfnotExists = true}) async {
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
      nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
      var accountUrl = '';
      if (!response.headers.isEmpty) {
        if (response.headers.map.containsKey('Location')) {
          accountUrl = response.headers.map['Location']!.first;
        }
      }
      var account = Account.fromJson(response.data);
      account.accountURL = accountUrl;
      return account;
    } on DioError catch (e) {
      if (createIfnotExists) {
        // No account found, create one
        if (e.response!.statusCode == 400) {
          nonce = e.response!.headers.map[HEADER_REPLAY_NONCE]!.first;
          return await createAccount();
        }
      }
      // TODO Handle error
      return null;
    }
  }

  ///
  /// Creates a new account for [publicKeyPem] by sending a POST request to the
  /// new account url.
  ///
  Future<Account?> createAccount() async {
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
      nonce = response.headers.map[HEADER_REPLAY_NONCE]!.first;
      var accountUrl = '';
      if (!response.headers.isEmpty) {
        if (response.headers.map.containsKey('Location')) {
          accountUrl = response.headers.map['Location']!.first;
        }
      }
      var account = Account.fromJson(response.data);
      account.accountURL = accountUrl;
      return account;
    } on DioError catch (e) {
      print(e.message);
      // TODO Handle error
      return null;
    }
  }

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

  Future<AcmeDirectories> _getDirectories() async {
    var response = await Dio().get(baseUrl + '/directory');
    return AcmeDirectories.fromJson(response.data);
  }

  Future<String?> _getNonce() async {
    var response = await Dio().head(directories!.newNonce!);
    if (response.headers.map.containsKey(HEADER_REPLAY_NONCE)) {
      return response.headers.map[HEADER_REPLAY_NONCE]!.first;
    } else {
      return null;
    }
  }
}
