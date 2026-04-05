import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:jose/jose.dart';

class AcmeUtils {
  /// @Throwing(ArgumentError, reason: 'the supplied JWK cannot be converted into a stable digest input')
  static String getDigest(JsonWebKey key) {
    final keyAsJson = key.toJson();
    final sortedKeys = keyAsJson.keys.toList()..sort();
    final sortedJson = <String, dynamic>{};
    for (final k in sortedKeys) {
      sortedJson.putIfAbsent(k, () => keyAsJson[k]);
    }
    final j = json.encode(sortedJson);
    final plain = CryptoUtils.getHashPlain(Uint8List.fromList(j.codeUnits));
    final digest = base64Url.encode(plain).replaceAll('=', '');
    return digest;
  }

  static String formatCsrBase64Url(String csr) {
    csr = csr.replaceAll(X509Utils.BEGIN_CSR, '');
    csr = csr.replaceAll(X509Utils.END_CSR, '');
    csr = csr.replaceAll(X509Utils.BEGIN_NEW_CSR, '');
    csr = csr.replaceAll(X509Utils.END_NEW_CSR, '');
    final lines = LineSplitter.split(csr);
    final b64 = lines.join();
    final bytes = base64.decode(b64);
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
// Internal helpers stay as static members to keep ACME payload transformations centralized.
// ignore_for_file: avoid_classes_with_only_static_members, lines_longer_than_80_chars
