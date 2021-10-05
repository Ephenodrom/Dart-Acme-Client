import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:jose/jose.dart';

class AcmeUtils {
  static String getDigest(JsonWebKey key) {
    var keyAsJson = key.toJson();
    var sortedKeys = keyAsJson.keys.toList()..sort();
    var sortedJson = {};
    for (var k in sortedKeys) {
      sortedJson.putIfAbsent(k, () => keyAsJson[k]);
    }
    var j = json.encode(sortedJson);
    var plain = CryptoUtils.getHashPlain(Uint8List.fromList(j.codeUnits));
    var digest = base64Url.encode(plain).replaceAll('=', '');
    return digest;
  }

  static String formatCsrBase64Url(String csr) {
    csr = csr.replaceAll(X509Utils.BEGIN_CSR, '');
    csr = csr.replaceAll(X509Utils.END_CSR, '');
    csr = csr.replaceAll(X509Utils.BEGIN_NEW_CSR, '');
    csr = csr.replaceAll(X509Utils.END_NEW_CSR, '');
    var lines = LineSplitter.split(csr);
    var b64 = lines.join();
    var bytes = base64.decode(b64);
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
