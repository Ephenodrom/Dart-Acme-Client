import '../acme_client_exception.dart';

/// A parsed ACME key-authorization value for `http-01` and `dns-01`.
///
/// The wire form is `<token>.<account-key-digest>`.
class KeyAuthorization {
  KeyAuthorization({required this.token, required this.accountKeyDigest}) {
    if (token.isEmpty) {
      throw const AcmeValidationException(
        'ACME key-authorization token is missing',
      );
    }
    if (accountKeyDigest.isEmpty) {
      throw const AcmeValidationException(
        'ACME key-authorization account key digest is missing',
      );
    }
  }

  factory KeyAuthorization.parse(String value) {
    final separator = value.indexOf('.');
    if (separator <= 0 || separator == value.length - 1) {
      throw AcmeValidationException(
        'ACME key-authorization is malformed',
        detail: value,
      );
    }

    return KeyAuthorization(
      token: value.substring(0, separator),
      accountKeyDigest: value.substring(separator + 1),
    );
  }

  final String token;
  final String accountKeyDigest;

  String get value => '$token.$accountKeyDigest';

  @override
  String toString() => value;
}
