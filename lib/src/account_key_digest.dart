import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/acme_util.dart';
import 'package:jose/jose.dart';

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
