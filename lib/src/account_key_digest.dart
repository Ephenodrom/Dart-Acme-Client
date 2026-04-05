import 'package:jose/jose.dart';

import 'acme_client_exception.dart';
import 'acme_util.dart';

class AccountKeyDigest {
  const AccountKeyDigest(this.value);

  factory AccountKeyDigest.fromPublicKeyPem(String publicKeyPem) {
    try {
      return AccountKeyDigest(
        AcmeUtils.getDigest(JsonWebKey.fromPem(publicKeyPem)),
      );
    } on ArgumentError catch (e) {
      throw AcmeAccountKeyDigestException(
        'Failed to create ACME account key digest',
        detail: e.message?.toString(),
        cause: e,
      );
    } on UnsupportedError catch (e) {
      throw AcmeAccountKeyDigestException(
        'Failed to create ACME account key digest',
        detail: e.message,
        cause: e,
      );
    } on StateError catch (e) {
      throw AcmeAccountKeyDigestException(
        'Failed to create ACME account key digest',
        detail: e.message,
        cause: e,
      );
    }
  }

  final String value;

  @override
  String toString() => value;
}

String acmeAccountKeyDigestFromPublicKeyPem(String publicKeyPem) =>
    AccountKeyDigest.fromPublicKeyPem(publicKeyPem).value;
// Internal exception mapping intentionally normalizes low-level key parsing
// errors.
// ignore_for_file: avoid_catching_errors
