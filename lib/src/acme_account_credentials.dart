import 'dart:convert';

import 'package:basic_utils/basic_utils.dart';

class AcmeAccountCredentials {
  final String privateKeyPem;
  final String publicKeyPem;
  final bool acceptTerms;
  final List<String> contacts;

  const AcmeAccountCredentials({
    required this.privateKeyPem,
    required this.publicKeyPem,
    required this.acceptTerms,
    required this.contacts,
  });

  factory AcmeAccountCredentials.generate({
    bool acceptTerms = false,
    required List<String> contacts,
    int rsaKeySize = 2048,
  }) {
    final accountKeyPair = CryptoUtils.generateRSAKeyPair(keySize: rsaKeySize);
    return AcmeAccountCredentials(
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPem(
        accountKeyPair.privateKey as RSAPrivateKey,
      ),
      publicKeyPem: CryptoUtils.encodeRSAPublicKeyToPem(
        accountKeyPair.publicKey as RSAPublicKey,
      ),
      acceptTerms: acceptTerms,
      contacts: List.unmodifiable(contacts),
    );
  }

  factory AcmeAccountCredentials.fromMap(Map<String, dynamic> json) {
    return AcmeAccountCredentials(
      privateKeyPem: json['privateKeyPem'] as String,
      publicKeyPem: json['publicKeyPem'] as String,
      acceptTerms: json['acceptTerms'] as bool,
      contacts: (json['contacts'] as List<dynamic>).cast<String>(),
    );
  }

  factory AcmeAccountCredentials.fromJson(String jsonString) =>
      AcmeAccountCredentials.fromMap(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

  Map<String, dynamic> toMap() => {
    'privateKeyPem': privateKeyPem,
    'publicKeyPem': publicKeyPem,
    'acceptTerms': acceptTerms,
    'contacts': contacts,
  };

  String toJson({bool pretty = true}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toMap())
      : jsonEncode(toMap());
}
